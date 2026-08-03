# Follow-up build: employee counts + spending by category (functional
# split), Milwaukee County + 4-county MSA, TY2011-2023.
#
# Requester follow-up to the 2026-06 Milwaukee MSA request (details in
# _private.md). Fields exist only on the full Form 990: 990-EZ and
# 990-PF are out of scope and stated so in the deliverable.
#
# Sources
#  - Universe: BMF geocoded master (rolling) via nccsdata, joined to the
#    county-fips + cbsa crosswalks; CBSA 33340 = Milwaukee-Waukesha MSA.
#    Geography = Milwaukee County (55079) vs full 4-county MSA.
#    Focus area = nteev2_subsector (same grouping as the June files).
#  - Employees: e-file v2.1 Part I, F9_01_ACT_GVRN_EMPL_TOT (IRS
#    headcount line, not FTE). Local CSVs reused from
#    ../nccs-govt-grants-analysis/data/efile-v2_1/ if present.
#  - Spending split: e-file v2.1 Part IX line 25 columns (total /
#    program / management-general / fundraising), synced from
#    s3://nccs-efile/public/efile_v2_1/ F9-P09-T00-EXPENSES-*.CSV.
#
# Dedup: group/amended returns keep latest RETURN_TIME_STAMP per EIN2 x
# TAX_YEAR; then one return per EIN2 x TAX_YEAR. TAX_YEAR and
# RETURN_TYPE taken per row, never from the file-name year (house rule).
#
# Coverage: TY2021-2023 complete (e-file mandate); TY2011-2020 flagged
# (v2.1 carries no TY2010 returns; series necessarily starts TY2011).
# coverage = "partial (pre-mandate e-filers only)" in every output row.
#
# Outputs (data/followup-2026-08/, gitignored; dollars in ACTUAL dollars):
#   employees_by_year_geo.csv
#   employees_by_year_focus_geo.csv
#   spending_split_by_year_geo.csv
#   spending_split_by_year_focus_geo.csv
# Appends pins to _pins.csv.

library(duckdb)
library(dplyr)

req      <- here::here("requests", "2026-06-milwaukee-msa")
source(here::here("R", "request_read.R"))

raw_grants <- path.expand("~/code/nccs/nccs-govt-grants-analysis/data/efile-v2_1")
p09_dir    <- file.path(req, "data", "efile-v2_1-p09")
out_dir    <- file.path(req, "data", "followup-2026-08")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- 0. Sync Part IX CSVs (and Part I if the grants-repo cache is gone) ---
if (!dir.exists(p09_dir) || length(list.files(p09_dir, "\\.CSV$")) < 14) {
  dir.create(p09_dir, recursive = TRUE, showWarnings = FALSE)
  stopifnot(system(paste(
    "aws s3 sync s3://nccs-efile/public/efile_v2_1/", p09_dir,
    "--profile thiya --exclude '*' --include 'F9-P09-T00-EXPENSES-*.CSV'")) == 0)
}
summary_glob <- file.path(raw_grants, "F9-P01-T00-SUMMARY-*.CSV")
if (length(Sys.glob(summary_glob)) == 0) {
  p01_dir <- file.path(req, "data", "efile-v2_1-p01")
  dir.create(p01_dir, recursive = TRUE, showWarnings = FALSE)
  stopifnot(system(paste(
    "aws s3 sync s3://nccs-efile/public/efile_v2_1/", p01_dir,
    "--profile thiya --exclude '*' --include 'F9-P01-T00-SUMMARY-*.CSV'")) == 0)
  summary_glob <- file.path(p01_dir, "F9-P01-T00-SUMMARY-*.CSV")
}

# --- 1. Milwaukee universe: EIN -> county + focus area (as in request.qmd) ---
bmf <- read_bmf_master(
  req,
  columns = c("ein", "geo_state_abbr", "geo_county", "nteev2_subsector"))
xwalk_county <- read_crosswalk(req, "county-fips")
xwalk_cbsa   <- read_crosswalk(req, "cbsa")

universe <- bmf |>
  filter(geo_state_abbr == "WI") |>
  left_join(xwalk_county, by = c("geo_state_abbr", "geo_county" = "geo_county_raw")) |>
  left_join(xwalk_cbsa,   by = c("geo_county_fips" = "county_fips")) |>
  filter(cbsa_code == "33340") |>
  transmute(ein9 = gsub("-", "", ein),
            county = geo_county,
            milwaukee_county = geo_county_fips == "55079",
            focus_area = nteev2_subsector) |>
  distinct(ein9, .keep_all = TRUE)

con <- dbConnect(duckdb())
duckdb::duckdb_register(con, "universe", universe)

# --- 2. One deduped full-990 return per EIN2 x TAX_YEAR, with both fields ---
# Part IX column names are verified against the file header at runtime.
p09_cols <- names(read.csv(list.files(p09_dir, "2023", full.names = TRUE), nrows = 0))
split_cols <- c(total = "F9_09_EXP_TOT_TOT", program = "F9_09_EXP_TOT_PROG",
                mgmt  = "F9_09_EXP_TOT_MGMT", fundraising = "F9_09_EXP_TOT_FUNDR")
missing <- setdiff(split_cols, p09_cols)
if (length(missing) > 0)
  stop("Part IX columns not found (check dictionary): ",
       paste(missing, collapse = ", "))

dedup_sql <- function(glob, value_cols, types) sprintf("
  WITH flagged_dedup AS (
    SELECT * EXCLUDE rn FROM (
      SELECT EIN2, ORG_EIN, TAX_YEAR, RETURN_TIME_STAMP, %s,
             CASE WHEN coalesce(RETURN_GROUP_X,false) OR coalesce(RETURN_AMENDED_X,false)
             THEN row_number() OVER (PARTITION BY EIN2, TAX_YEAR,
                    (coalesce(RETURN_GROUP_X,false) OR coalesce(RETURN_AMENDED_X,false))
                    ORDER BY RETURN_TIME_STAMP DESC) ELSE 1 END AS rn
      FROM read_csv('%s', union_by_name = true,
                    nullstr = ['NA',''], allow_quoted_nulls = true,
                    types = {'EIN2':'VARCHAR','ORG_EIN':'VARCHAR',
                             'TAX_YEAR':'INTEGER','RETURN_TIME_STAMP':'VARCHAR',
                             'RETURN_AMENDED_X':'BOOLEAN','RETURN_GROUP_X':'BOOLEAN',%s})
      WHERE RETURN_TYPE = '990' AND TAX_YEAR BETWEEN 2011 AND 2023
    ) WHERE rn = 1)
  SELECT * EXCLUDE rn FROM (
    SELECT *, row_number() OVER (PARTITION BY EIN2, TAX_YEAR
                                 ORDER BY RETURN_TIME_STAMP DESC) AS rn
    FROM flagged_dedup) WHERE rn = 1", value_cols, glob, types)

dbExecute(con, paste("CREATE VIEW emp AS", dedup_sql(
  summary_glob, "F9_01_ACT_GVRN_EMPL_TOT",
  "'F9_01_ACT_GVRN_EMPL_TOT':'DOUBLE'")))
dbExecute(con, paste("CREATE VIEW spend AS", dedup_sql(
  file.path(p09_dir, "F9-P09-T00-EXPENSES-*.CSV"),
  paste(split_cols, collapse = ", "),
  paste(sprintf("'%s':'DOUBLE'", split_cols), collapse = ","))))

dbExecute(con, "
  CREATE VIEW joined AS
  SELECT u.county, u.milwaukee_county, u.focus_area,
         e.TAX_YEAR, e.F9_01_ACT_GVRN_EMPL_TOT AS employees,
         s.F9_09_EXP_TOT_TOT AS exp_total, s.F9_09_EXP_TOT_PROG AS exp_program,
         s.F9_09_EXP_TOT_MGMT AS exp_mgmt, s.F9_09_EXP_TOT_FUNDR AS exp_fundraising
  FROM emp e
  JOIN universe u ON u.ein9 = e.ORG_EIN
  LEFT JOIN spend s ON s.EIN2 = e.EIN2 AND s.TAX_YEAR = e.TAX_YEAR")

# --- 3. Aggregations: each at MSA grain + Milwaukee County grain ---
agg <- function(by_focus) {
  grp <- if (by_focus) "TAX_YEAR, focus_area" else "TAX_YEAR"
  q <- function(geo_filter, geo_label) dbGetQuery(con, sprintf("
    SELECT '%s' AS geography, %s,
           count(*)                       AS orgs_filing_990,
           count(employees)               AS orgs_reporting_employees,
           sum(employees)                 AS employees_total,
           count(exp_total)               AS orgs_reporting_expense_split,
           sum(exp_total)                 AS expenses_total,
           sum(exp_program)               AS expenses_program,
           sum(exp_mgmt)                  AS expenses_mgmt_general,
           sum(exp_fundraising)           AS expenses_fundraising,
           CASE WHEN TAX_YEAR >= 2021 THEN 'complete (e-file mandate)'
                ELSE 'partial (pre-mandate e-filers only)' END AS coverage
    FROM joined %s GROUP BY geography, %s, coverage ORDER BY %s",
    geo_label, grp, geo_filter, grp, grp))
  bind_rows(q("", "Milwaukee MSA (4-county)"),
            q("WHERE milwaukee_county", "Milwaukee County"))
}

by_year       <- agg(FALSE)
by_year_focus <- agg(TRUE)

write.csv(by_year |> select(-starts_with("expenses"), -orgs_reporting_expense_split),
          file.path(out_dir, "employees_by_year_geo.csv"), row.names = FALSE)
write.csv(by_year_focus |> select(-starts_with("expenses"), -orgs_reporting_expense_split),
          file.path(out_dir, "employees_by_year_focus_geo.csv"), row.names = FALSE)
write.csv(by_year |> select(-employees_total, -orgs_reporting_employees),
          file.path(out_dir, "spending_split_by_year_geo.csv"), row.names = FALSE)
write.csv(by_year_focus |> select(-employees_total, -orgs_reporting_employees),
          file.path(out_dir, "spending_split_by_year_focus_geo.csv"), row.names = FALSE)

# --- 4. Pin vintages ---
record_pin(req, "efile-v2_1-p01-summary", "release files 2011-2023",
           "s3://nccs-efile/public/efile_v2_1/",
           dbGetQuery(con, "SELECT count(*) n FROM emp")$n,
           "employee counts, full 990 only")
record_pin(req, "efile-v2_1-p09-expenses", "release files 2011-2023",
           "s3://nccs-efile/public/efile_v2_1/",
           dbGetQuery(con, "SELECT count(*) n FROM spend")$n,
           "functional expense split, full 990 only")

print(by_year, n = 30)
dbDisconnect(con, shutdown = TRUE)
