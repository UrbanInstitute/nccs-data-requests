# Follow-up build: employee counts + spending by category (functional
# split), Milwaukee County + 4-county MSA, TY2012-2023.
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
#  - Employees: e-file v2.1 Part I table (F9-P01-T00-SUMMARY),
#    F9_01_ACT_GVRN_EMPL_TOT (IRS headcount line, not FTE).
#  - Spending split: e-file v2.1 Part IX table (F9-P09-T00-EXPENSES),
#    line 25 columns (total / program / management-general / fundraising).
#    Both tables sync TY2012-2023 from s3://nccs-efile/public/efile_v2_1/
#    into this request's data/ (section 0); exact files + sha256 are
#    recorded in the tracked _efile_inputs.csv.
#
# Dedup: group/amended returns keep latest RETURN_TIME_STAMP per EIN2 x
# TAX_YEAR; then one return per EIN2 x TAX_YEAR. TAX_YEAR and
# RETURN_TYPE taken per row, never from the file-name year (house rule).
#
# Coverage: TY2021-2023 complete (e-file mandate); TY2012-2020 flagged.
# Series starts TY2012 per standing rule: TY2011 is the first year of
# the IRS publication series and does not capture the full tax year.
# coverage = "partial (pre-mandate e-filers only)" in every output row.
#
# Outputs (data/followup-2026-08/, gitignored; dollars in ACTUAL dollars):
#   employees_by_year_geo.csv
#   employees_by_year_focus_geo.csv
#   spending_split_by_year_geo.csv
#   spending_split_by_year_focus_geo.csv
# Appends pins to _pins.csv and rewrites _efile_inputs.csv.

library(duckdb)
library(dplyr)

req      <- here::here("requests", "2026-06-milwaukee-msa")
source(here::here("R", "request_read.R"))

out_dir  <- file.path(req, "data", "followup-2026-08")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- 0. E-file v2.1 release tables ------------------------------------------
# Inputs live ONLY inside this request folder (data/, gitignored) so the
# build never depends on machine-local state elsewhere. The release catalog
# names each table F9-P{part}-T00-{TABLE}-{year}.CSV; that pattern is defined
# once here, exactly the TY2012-2023 files are synced, and every later read
# takes an explicit file list rather than a glob, so extra years that happen
# to sit in the folder can never enter the series. Each file's sha256 is
# written to the tracked `_efile_inputs.csv`, which the pins reference.
efile_release_prefix <- "s3://nccs-efile/public/efile_v2_1/"
efile_release_years  <- 2012:2023
efile_inputs_path    <- file.path(req, "_efile_inputs.csv")

efile_table_file_name <- function(table_name, year) {

  sprintf("%s-%d.CSV", table_name, year)

}

# Sync the TY2012-2023 files of one release table into `local_dir` (aws s3
# sync only downloads what is missing or changed) and return the explicit
# per-year file paths. Stops if any required year is absent afterwards.
sync_efile_table <- function(table_name, local_dir) {

  dir.create(local_dir, recursive = TRUE, showWarnings = FALSE)

  file_names <- efile_table_file_name(table_name, efile_release_years)
  file_paths <- file.path(local_dir, file_names)

  # One --include per required year: nothing outside 2012-2023 is fetched.
  include_flags <- paste("--include", shQuote(file_names), collapse = " ")

  sync_status <- system(paste(
    "aws s3 sync", efile_release_prefix, local_dir,
    "--profile thiya --exclude '*'", include_flags))

  years_missing <- efile_release_years[!file.exists(file_paths)]

  if (sync_status != 0 || length(years_missing) > 0) {

    stop(sprintf(
      "e-file table %s: sync exit %d, missing years %s. Check the release catalog at %s",
      table_name, sync_status, paste(years_missing, collapse = ", "), efile_release_prefix))

  }

  file_paths

}

# Record the concrete input files (name, bytes, sha256) so `_pins.csv` plus
# this manifest reconstruct the exact artifact set. `openssl::sha256` streams
# the file, so the ~300 MB CSVs are hashed without loading them.
write_efile_inputs_manifest <- function(table_files) {

  manifest <- purrr::imap_dfr(table_files, function(file_paths, table_name) {

    tibble::tibble(
      table     = table_name,
      file      = basename(file_paths),
      source    = paste0(efile_release_prefix, basename(file_paths)),
      bytes     = file.size(file_paths),
      sha256    = purrr::map_chr(file_paths, function(file_path) {

        connection <- file(file_path, open = "rb")
        on.exit(close(connection))
        as.character(openssl::sha256(connection))

      }),
      hashed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
    )

  })

  utils::write.csv(manifest, efile_inputs_path, row.names = FALSE)

  manifest

}

summary_files  <- sync_efile_table("F9-P01-T00-SUMMARY",
                                   file.path(req, "data", "efile-v2_1-p01"))
expenses_files <- sync_efile_table("F9-P09-T00-EXPENSES",
                                   file.path(req, "data", "efile-v2_1-p09"))

efile_inputs <- write_efile_inputs_manifest(
  list("F9-P01-T00-SUMMARY" = summary_files, "F9-P09-T00-EXPENSES" = expenses_files))

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
expenses_columns <- names(utils::read.csv(
  expenses_files[efile_release_years == 2023], nrows = 0))
split_cols <- c(total = "F9_09_EXP_TOT_TOT", program = "F9_09_EXP_TOT_PROG",
                mgmt  = "F9_09_EXP_TOT_MGMT", fundraising = "F9_09_EXP_TOT_FUNDR")
split_columns_missing <- setdiff(split_cols, expenses_columns)

if (length(split_columns_missing) > 0) {

  stop("Part IX columns not found (check dictionary): ",
       paste(split_columns_missing, collapse = ", "))

}

# `file_paths` -> DuckDB list literal, so read_csv sees exactly the TY2012-2023
# files and nothing else in the folder.
duckdb_file_list <- function(file_paths) {

  paste0("[", paste(shQuote(file_paths, type = "sh"), collapse = ", "), "]")

}

dedup_sql <- function(file_paths, value_cols, types) sprintf("
  WITH flagged_dedup AS (
    SELECT * EXCLUDE rn FROM (
      SELECT EIN2, ORG_EIN, TAX_YEAR, RETURN_TIME_STAMP, %s,
             CASE WHEN coalesce(RETURN_GROUP_X,false) OR coalesce(RETURN_AMENDED_X,false)
             THEN row_number() OVER (PARTITION BY EIN2, TAX_YEAR,
                    (coalesce(RETURN_GROUP_X,false) OR coalesce(RETURN_AMENDED_X,false))
                    ORDER BY RETURN_TIME_STAMP DESC) ELSE 1 END AS rn
      FROM read_csv(%s, union_by_name = true,
                    nullstr = ['NA',''], allow_quoted_nulls = true,
                    types = {'EIN2':'VARCHAR','ORG_EIN':'VARCHAR',
                             'TAX_YEAR':'INTEGER','RETURN_TIME_STAMP':'VARCHAR',
                             'RETURN_AMENDED_X':'BOOLEAN','RETURN_GROUP_X':'BOOLEAN',%s})
      WHERE RETURN_TYPE = '990' AND TAX_YEAR BETWEEN 2012 AND 2023
    ) WHERE rn = 1)
  SELECT * EXCLUDE rn FROM (
    SELECT *, row_number() OVER (PARTITION BY EIN2, TAX_YEAR
                                 ORDER BY RETURN_TIME_STAMP DESC) AS rn
    FROM flagged_dedup) WHERE rn = 1", value_cols, duckdb_file_list(file_paths), types)

dbExecute(con, paste("CREATE VIEW emp AS", dedup_sql(
  summary_files, "F9_01_ACT_GVRN_EMPL_TOT",
  "'F9_01_ACT_GVRN_EMPL_TOT':'DOUBLE'")))
dbExecute(con, paste("CREATE VIEW spend AS", dedup_sql(
  expenses_files,
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

# --- 4. Pin vintages: one pin per table, naming the exact files used ---
pin_efile_table <- function(table_name, dataset, view_name, note) {

  table_manifest <- dplyr::filter(efile_inputs, table == table_name)

  record_pin(
    req, dataset,
    vintage = sprintf("efile_v2_1 TY%d-%d, %d files (sha256 in _efile_inputs.csv)",
                      min(efile_release_years), max(efile_release_years),
                      nrow(table_manifest)),
    source  = paste0(efile_release_prefix,
                     efile_table_file_name(table_name, min(efile_release_years)),
                     " .. ",
                     efile_table_file_name(table_name, max(efile_release_years))),
    n_rows  = dbGetQuery(con, sprintf("SELECT count(*) n FROM %s", view_name))$n,
    note    = note)

}

pin_efile_table("F9-P01-T00-SUMMARY",  "efile-v2_1-p01-summary",  "emp",
                "employee counts, full 990 only, deduped EIN2 x TAX_YEAR")
pin_efile_table("F9-P09-T00-EXPENSES", "efile-v2_1-p09-expenses", "spend",
                "functional expense split, full 990 only, deduped EIN2 x TAX_YEAR")

print(by_year, row.names = FALSE)
dbDisconnect(con, shutdown = TRUE)
