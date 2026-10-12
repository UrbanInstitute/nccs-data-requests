# Build 1: Nashville metro nonprofit universe (BMF) plus a national Form
# 990 org-by-year panel (e-file v2.1, TY2012-2023) so the metro can be
# benchmarked against peer metros and the nation.
#
# Sources
#  - Universe: BMF geocoded unified master (rolling) via nccsdata, joined to
#    the county-fips + cbsa crosswalks. CBSA 34980 = Nashville-Davidson--
#    Murfreesboro--Franklin, TN (14 counties, 2023 OMB delineation). The
#    manifest vintage and sha256 of the master are recorded in _pins.csv.
#  - Form 990 panel: e-file v2.1 Part I (F9-P01-T00-SUMMARY) and Part IX
#    (F9-P09-T00-EXPENSES), TY2012-2023 national files synced for the
#    2026-06 Milwaukee request (sha256 in that folder's _efile_inputs.csv).
#    Full Form 990 only (990-EZ / 990-PF carry no employee or pay lines).
#
# Filing selection (REVIEW.md finding 1): one filing per EIN2 x TAX_YEAR is
# chosen ONCE, on Part I, ordered by RETURN_TIME_STAMP desc then OBJECTID
# desc (deterministic tie-break). Part IX is joined on OBJECTID, which the
# v2.1 release carries as the shared filing identifier across part tables,
# so both parts always come from the same return. Uniqueness and identity
# are asserted. TAX_YEAR and RETURN_TYPE are taken per row, never from the
# file name. Series starts TY2012 (house rule).
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

sha256_file <- function(path) {
  connection <- file(path, open = "rb")
  on.exit(close(connection))
  as.character(openssl::sha256(connection))
}

# --- 1. Tennessee universe with county and CBSA joins ------------------------

# Record which build of the rolling master is being read (vintage + sha256
# from its manifest) so the pin names an identifiable artifact.
bmf_manifest <- jsonlite::fromJSON(
  "https://nccsdata.s3.amazonaws.com/geocoding/unified-bmf/latest/_manifest.json")
bmf_identity <- sprintf("vintage %s, git %s, sha256 %s",
                        bmf_manifest$vintage, bmf_manifest$git_sha,
                        bmf_manifest$files$bmf_unified_geocoded.parquet$sha256)

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
  note = paste("TN universe, all vintages;", bmf_identity)
)

# Crosswalks: anonymous HTTPS mirrors of the contracted S3 paths. The local
# copy is re-downloaded if absent and its sha256 is pinned either way.
read_crosswalk_https <- function(which, file) {

  uri <- sprintf("https://nccsdata.s3.amazonaws.com/crosswalks/%s/%s", which, file)
  local <- file.path(out_dir, file)

  if (!file.exists(local)) {
    utils::download.file(uri, local, mode = "wb", quiet = TRUE)
  }

  out <- arrow::read_parquet(local)
  record_pin(req, paste0("crosswalk-", which), vintage = "tiger-2023",
             source = uri, n_rows = nrow(out),
             note = paste("sha256", sha256_file(local)), data = out)

}

xwalk_county <- read_crosswalk_https("county-fips", "county_fips_crosswalk.parquet")
xwalk_cbsa   <- read_crosswalk_https("cbsa", "cbsa_crosswalk.parquet")

universe_tn <- bmf_tn |>
  left_join(xwalk_county, by = c("geo_state_abbr", "geo_county" = "geo_county_raw")) |>
  left_join(xwalk_cbsa, by = c("geo_county_fips" = "county_fips")) |>
  mutate(ein9 = gsub("-", "", ein))

stopifnot(n_distinct(universe_tn$ein) == nrow(universe_tn))
stopifnot(n_distinct(universe_tn$geo_county_fips[universe_tn$cbsa_code %in% "34980"]) == 14)

arrow::write_parquet(universe_tn, file.path(out_dir, "universe_tn.parquet"))

# --- 2. National Form 990 org-year panel from e-file v2.1 --------------------

release_years <- 2012:2023
summary_files  <- file.path(milwaukee_data, "efile-v2_1-p01",
                            sprintf("F9-P01-T00-SUMMARY-%d.CSV", release_years))
expenses_files <- file.path(milwaukee_data, "efile-v2_1-p09",
                            sprintf("F9-P09-T00-EXPENSES-%d.CSV", release_years))
stopifnot(all(file.exists(summary_files)), all(file.exists(expenses_files)))

# The raw files are identified by the Milwaukee request's manifest; verify
# it covers exactly these 24 files so the pin can cite it.
efile_inputs <- utils::read.csv(file.path(milwaukee_data, "..", "_efile_inputs.csv"))
stopifnot(setequal(efile_inputs$file, basename(c(summary_files, expenses_files))))

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

types_clause <- function(value_cols) {
  paste(sprintf("'%s':'DOUBLE'", value_cols), collapse = ",")
}

# Raw in-scope rows of one part, keeping the filing identifier.
raw_part_sql <- function(file_paths, value_cols) sprintf("
  SELECT OBJECTID, EIN2, ORG_EIN, ORG_NAME_L1, TAX_YEAR, RETURN_TIME_STAMP, %s
  FROM read_csv(%s, union_by_name = true,
                nullstr = ['NA',''], allow_quoted_nulls = true,
                types = {'OBJECTID':'VARCHAR','EIN2':'VARCHAR','ORG_EIN':'VARCHAR',
                         'ORG_NAME_L1':'VARCHAR','TAX_YEAR':'INTEGER',
                         'RETURN_TIME_STAMP':'VARCHAR',%s})
  WHERE RETURN_TYPE = '990' AND TAX_YEAR BETWEEN 2012 AND 2023",
  paste(value_cols, collapse = ", "), duckdb_file_list(file_paths), types_clause(value_cols))

dbExecute(con, paste("CREATE TABLE part1_raw AS", raw_part_sql(summary_files, summary_cols)))
dbExecute(con, paste("CREATE TABLE part9_raw AS", raw_part_sql(expenses_files, expenses_cols)))

# Select the filing once, deterministically, on Part I.
dbExecute(con, "
  CREATE TABLE part1 AS
  SELECT * EXCLUDE rn FROM (
    SELECT *, row_number() OVER (PARTITION BY EIN2, TAX_YEAR
                                 ORDER BY RETURN_TIME_STAMP DESC, OBJECTID DESC) AS rn
    FROM part1_raw) WHERE rn = 1")

# Part IX rows for exactly those filings, joined on the filing identifier.
dbExecute(con, "
  CREATE TABLE part9 AS
  SELECT * EXCLUDE rn FROM (
    SELECT p9.*, row_number() OVER (PARTITION BY p9.OBJECTID ORDER BY p9.RETURN_TIME_STAMP DESC) AS rn
    FROM part9_raw p9 JOIN part1 p1 USING (OBJECTID)) WHERE rn = 1")

identity_check <- dbGetQuery(con, "
  SELECT (SELECT count(*) FROM part1) AS filings,
         (SELECT count(DISTINCT (EIN2, TAX_YEAR)) FROM part1) AS unique_keys,
         (SELECT count(DISTINCT OBJECTID) FROM part1) AS unique_filings,
         (SELECT count(*) FROM part9) AS part9_rows,
         (SELECT count(*) FROM part1 p1 LEFT JOIN part9 p9 USING (OBJECTID) WHERE p9.OBJECTID IS NULL) AS missing_part9,
         (SELECT count(*) FROM part1 p1 JOIN part9 p9 USING (OBJECTID)
            WHERE p1.EIN2 <> p9.EIN2 OR p1.TAX_YEAR <> p9.TAX_YEAR) AS identity_mismatch")
print(identity_check)
stopifnot(identity_check$filings == identity_check$unique_keys,
          identity_check$filings == identity_check$unique_filings,
          identity_check$identity_mismatch == 0)
cat(sprintf("Filings without a Part IX row: %d (kept with NA expense split)\n",
            identity_check$missing_part9))

panel_path <- file.path(out_dir, "panel_990_national.parquet")
dbExecute(con, sprintf("
  COPY (
    SELECT p1.OBJECTID AS filing_id, p1.EIN2 AS ein2, p1.ORG_EIN AS ein9,
           p1.ORG_NAME_L1 AS org_name, p1.TAX_YEAR AS tax_year,
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
    LEFT JOIN part9 p9 USING (OBJECTID)
  ) TO '%s' (FORMAT PARQUET)", panel_path))

n_panel <- dbGetQuery(con, sprintf("SELECT count(*) n FROM '%s'", panel_path))$n
record_pin(req, "efile-v2_1-p01-p09-panel",
           vintage = "efile_v2_1 TY2012-2023, 24 files (sha256 in ../2026-06-milwaukee-msa/_efile_inputs.csv)",
           source  = "s3://nccs-efile/public/efile_v2_1/F9-P01-T00-SUMMARY-{yr}.CSV + F9-P09-T00-EXPENSES-{yr}.CSV",
           n_rows  = n_panel,
           note    = "national full-990 org-year panel; one filing per EIN2 x TAX_YEAR chosen on Part I (timestamp desc, OBJECTID desc); Part IX joined on OBJECTID")

print(dbGetQuery(con, sprintf("SELECT tax_year, count(*) n FROM '%s' GROUP BY 1 ORDER BY 1", panel_path)))
dbDisconnect(con, shutdown = TRUE)

# --- 3. CPI-U for real dollars ----------------------------------------------
cpi <- nccsdata::cpi_u
utils::write.csv(cpi, file.path(out_dir, "cpi.csv"), row.names = FALSE)
