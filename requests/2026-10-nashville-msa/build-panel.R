# Exploration build: Nashville metro nonprofit universe (BMF) plus a
# national Form 990 org-by-year panel (e-file v2.1, TY2012-2023) so the
# metro can be benchmarked against peer metros and the nation.
#
# Sources
#  - Universe: BMF geocoded unified master (rolling) via nccsdata, joined to
#    the county-fips + cbsa crosswalks. CBSA 34980 = Nashville-Davidson--
#    Murfreesboro--Franklin, TN (14 counties, 2023 OMB delineation).
#  - Form 990 panel: e-file v2.1 Part I (F9-P01-T00-SUMMARY) and Part IX
#    (F9-P09-T00-EXPENSES), TY2012-2023 national files already synced for the
#    2026-06 Milwaukee request (see its _efile_inputs.csv for sha256).
#    Full Form 990 only (990-EZ / 990-PF carry no employee or pay lines).
#
# Dedup: amended/group returns keep latest RETURN_TIME_STAMP per EIN2 x
# TAX_YEAR; TAX_YEAR and RETURN_TYPE taken per row, never from file name.
# Series starts TY2012 (house rule). TY2021+ is complete (e-file mandate).
#
# Outputs (data/, gitignored):
#   universe_tn.parquet          every TN org in the BMF master + crosswalk joins
#   panel_990_national.parquet   one row per EIN2 x TAX_YEAR, full 990 filers, US
#   cpi.csv                      CPI-U annual averages (nccsdata bundled)

library(dplyr)
library(duckdb)

req <- here::here("requests", "2026-10-nashville-msa")
source(here::here("R", "request_read.R"))

milwaukee_data <- here::here("requests", "2026-06-milwaukee-msa", "data")
out_dir <- file.path(req, "data")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- 1. Tennessee universe with county and CBSA joins ------------------------

bmf_columns <- c(
  "ein", "EIN2", "org_name_display", "org_addr_city", "org_addr_zip5",
  "geo_state_abbr", "geo_county", "geo_city", "geo_lat", "geo_lon",
  "subsection_code", "foundation_code", "ruling_date", "ntee_code_clean",
  "ntee_code_major_group", "nteev2_code", "nteev2_subsector", "nteev2_org_type",
  "income_amount", "revenue_amount", "asset_amount",
  "first_year_in_bmf", "last_year_in_bmf", "bmf_vintages_observed"
)

bmf_tn <- read_bmf_master(
  req, state = "TN", columns = bmf_columns, cache = FALSE,
  note = "TN universe, all vintages, for Nashville CBSA 34980 filtering"
)

# Crosswalks: anonymous HTTPS mirrors of the contracted S3 paths (the SSO
# session is not needed for public reads).
read_crosswalk_https <- function(which, file) {

  uri <- sprintf("https://nccsdata.s3.amazonaws.com/crosswalks/%s/%s", which, file)
  local <- file.path(out_dir, file)

  if (!file.exists(local)) {
    utils::download.file(uri, local, mode = "wb", quiet = TRUE)
  }

  out <- arrow::read_parquet(local)
  record_pin(req, paste0("crosswalk-", which), vintage = "tiger-2023",
             source = uri, n_rows = nrow(out), data = out)

}

xwalk_county <- read_crosswalk_https("county-fips", "county_fips_crosswalk.parquet")
xwalk_cbsa   <- read_crosswalk_https("cbsa", "cbsa_crosswalk.parquet")

universe_tn <- bmf_tn |>
  left_join(xwalk_county, by = c("geo_state_abbr", "geo_county" = "geo_county_raw")) |>
  left_join(xwalk_cbsa, by = c("geo_county_fips" = "county_fips")) |>
  mutate(ein9 = gsub("-", "", ein))

arrow::write_parquet(universe_tn, file.path(out_dir, "universe_tn.parquet"))

# --- 2. National Form 990 org-year panel from e-file v2.1 --------------------

release_years <- 2012:2023
summary_files  <- file.path(milwaukee_data, "efile-v2_1-p01",
                            sprintf("F9-P01-T00-SUMMARY-%d.CSV", release_years))
expenses_files <- file.path(milwaukee_data, "efile-v2_1-p09",
                            sprintf("F9-P09-T00-EXPENSES-%d.CSV", release_years))
stopifnot(all(file.exists(summary_files)), all(file.exists(expenses_files)))

con <- dbConnect(duckdb())

duckdb_file_list <- function(file_paths) {
  paste0("[", paste(shQuote(file_paths, type = "sh"), collapse = ", "), "]")
}

summary_cols <- c(
  "F9_01_ACT_GVRN_EMPL_TOT", "F9_01_ACT_GVRN_VOL_TOT",
  "F9_01_REV_CONTR_TOT_CY", "F9_01_REV_PROG_TOT_CY", "F9_01_REV_TOT_CY",
  "F9_01_EXP_GRANT_SIMILAR_CY", "F9_01_EXP_SAL_ETC_CY", "F9_01_EXP_TOT_CY",
  "F9_01_NAFB_ASSET_TOT_EOY", "F9_01_NAFB_LIAB_TOT_EOY", "F9_01_NAFB_TOT_EOY",
  "F9_01_NAFB_TOT_BOY"
)
expenses_cols <- c(
  "F9_09_EXP_TOT_TOT", "F9_09_EXP_TOT_PROG", "F9_09_EXP_TOT_MGMT", "F9_09_EXP_TOT_FUNDR",
  "F9_09_EXP_COMP_DTK_TOT", "F9_09_EXP_COMP_DSQ_PERS_TOT", "F9_09_EXP_OTH_SAL_WAGE_TOT",
  "F9_09_EXP_PENSION_CONTR_TOT", "F9_09_EXP_OTH_EMPL_BEN_TOT", "F9_09_EXP_PAYROLL_TAX_TOT"
)

dedup_sql <- function(file_paths, value_cols) {

  types <- paste(sprintf("'%s':'DOUBLE'", value_cols), collapse = ",")

  sprintf("
  WITH flagged_dedup AS (
    SELECT * EXCLUDE rn FROM (
      SELECT EIN2, ORG_EIN, ORG_NAME_L1, TAX_YEAR, RETURN_TIME_STAMP, %s,
             CASE WHEN coalesce(RETURN_GROUP_X,false) OR coalesce(RETURN_AMENDED_X,false)
             THEN row_number() OVER (PARTITION BY EIN2, TAX_YEAR,
                    (coalesce(RETURN_GROUP_X,false) OR coalesce(RETURN_AMENDED_X,false))
                    ORDER BY RETURN_TIME_STAMP DESC) ELSE 1 END AS rn
      FROM read_csv(%s, union_by_name = true,
                    nullstr = ['NA',''], allow_quoted_nulls = true,
                    types = {'EIN2':'VARCHAR','ORG_EIN':'VARCHAR','ORG_NAME_L1':'VARCHAR',
                             'TAX_YEAR':'INTEGER','RETURN_TIME_STAMP':'VARCHAR',
                             'RETURN_AMENDED_X':'BOOLEAN','RETURN_GROUP_X':'BOOLEAN',%s})
      WHERE RETURN_TYPE = '990' AND TAX_YEAR BETWEEN 2012 AND 2023
    ) WHERE rn = 1)
  SELECT * EXCLUDE rn FROM (
    SELECT *, row_number() OVER (PARTITION BY EIN2, TAX_YEAR
                                 ORDER BY RETURN_TIME_STAMP DESC) AS rn
    FROM flagged_dedup) WHERE rn = 1",
    paste(value_cols, collapse = ", "), duckdb_file_list(file_paths), types)

}

dbExecute(con, paste("CREATE TABLE part1 AS", dedup_sql(summary_files, summary_cols)))
dbExecute(con, paste("CREATE TABLE part9 AS", dedup_sql(expenses_files, expenses_cols)))

panel_path <- file.path(out_dir, "panel_990_national.parquet")
dbExecute(con, sprintf("
  COPY (
    SELECT p1.EIN2 AS ein2, p1.ORG_EIN AS ein9, p1.ORG_NAME_L1 AS org_name,
           p1.TAX_YEAR AS tax_year,
           p1.F9_01_ACT_GVRN_EMPL_TOT   AS employees,
           p1.F9_01_ACT_GVRN_VOL_TOT    AS volunteers,
           p1.F9_01_REV_CONTR_TOT_CY    AS rev_contributions,
           p1.F9_01_REV_PROG_TOT_CY     AS rev_program,
           p1.F9_01_REV_TOT_CY          AS rev_total,
           p1.F9_01_EXP_GRANT_SIMILAR_CY AS exp_grants_paid,
           p1.F9_01_EXP_SAL_ETC_CY      AS exp_salaries_p1,
           p1.F9_01_EXP_TOT_CY          AS exp_total,
           p1.F9_01_NAFB_ASSET_TOT_EOY  AS assets_eoy,
           p1.F9_01_NAFB_LIAB_TOT_EOY   AS liabilities_eoy,
           p1.F9_01_NAFB_TOT_EOY        AS net_assets_eoy,
           p1.F9_01_NAFB_TOT_BOY        AS net_assets_boy,
           p9.F9_09_EXP_TOT_TOT         AS exp9_total,
           p9.F9_09_EXP_TOT_PROG        AS exp9_program,
           p9.F9_09_EXP_TOT_MGMT        AS exp9_mgmt,
           p9.F9_09_EXP_TOT_FUNDR       AS exp9_fundraising,
           p9.F9_09_EXP_COMP_DTK_TOT    AS comp_officers,
           p9.F9_09_EXP_COMP_DSQ_PERS_TOT AS comp_disqualified,
           p9.F9_09_EXP_OTH_SAL_WAGE_TOT AS comp_other_salaries,
           p9.F9_09_EXP_PENSION_CONTR_TOT AS comp_pension,
           p9.F9_09_EXP_OTH_EMPL_BEN_TOT AS comp_benefits,
           p9.F9_09_EXP_PAYROLL_TAX_TOT  AS comp_payroll_tax
    FROM part1 p1
    LEFT JOIN part9 p9 ON p9.EIN2 = p1.EIN2 AND p9.TAX_YEAR = p1.TAX_YEAR
  ) TO '%s' (FORMAT PARQUET)", panel_path))

n_panel <- dbGetQuery(con, sprintf("SELECT count(*) n FROM '%s'", panel_path))$n
record_pin(req, "efile-v2_1-p01-p09-panel",
           vintage = "efile_v2_1 TY2012-2023 (files + sha256 in ../2026-06-milwaukee-msa/_efile_inputs.csv)",
           source  = "s3://nccs-efile/public/efile_v2_1/F9-P01-T00-SUMMARY-{yr}.CSV + F9-P09-T00-EXPENSES-{yr}.CSV",
           n_rows  = n_panel,
           note    = "national full-990 org-year panel, deduped EIN2 x TAX_YEAR")

print(dbGetQuery(con, sprintf("SELECT tax_year, count(*) n FROM '%s' GROUP BY 1 ORDER BY 1", panel_path)))
dbDisconnect(con, shutdown = TRUE)

# --- 3. CPI-U for real dollars ----------------------------------------------
cpi <- nccsdata::cpi_u
utils::write.csv(cpi, file.path(out_dir, "cpi.csv"), row.names = FALSE)
