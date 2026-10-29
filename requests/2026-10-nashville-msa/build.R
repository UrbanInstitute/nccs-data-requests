

# =============================================================================
# Section: build-panel (formerly build-panel.R)
# =============================================================================

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
raw_files <- c(summary_files, expenses_files)
raw_hashes <- vapply(raw_files, sha256_file, character(1))
expected <- efile_inputs$sha256[match(basename(raw_files), efile_inputs$file)]
hash_mismatch <- basename(raw_files)[raw_hashes != expected]
if (length(hash_mismatch) > 0) stop("raw e-file CSV does not match recorded sha256: ", paste(hash_mismatch, collapse = ", "))
cat("raw e-file CSV sha256 verified against _efile_inputs.csv for", length(raw_files), "files\n")

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


# =============================================================================
# Section: build-external (formerly build-external.R)
# =============================================================================

# Build 2: non-NCCS inputs and the Phase 0 government grants table.
# Downloads anything missing into data/external/, pins each file with its
# sha256, and derives data/county_pop.csv (REVIEW.md finding 10: these
# steps were previously done by hand).
#
# Outputs:
#   data/external/co-est2019-alldata.csv, co-est2023-alldata.csv   Census county estimates
#   data/external/qcew_{fips}_{year}.csv                           BLS QCEW annual county files
#   data/government_grants.parquet                                 e-file Phase 0, verified against its manifest
#   data/county_pop.csv                                            14 metro counties, 2010/2015/2019/2020/2023
#   output/county_population_2010_2023.csv, output/qcew_private_pay_benchmarks.csv

library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
source(here::here("R", "request_read.R"))
ext <- file.path(req, "data", "external")
out <- file.path(req, "output")
dir.create(ext, recursive = TRUE, showWarnings = FALSE)
dir.create(out, recursive = TRUE, showWarnings = FALSE)
options(timeout = 600)

sha256_file <- function(path) {
  connection <- file(path, open = "rb")
  on.exit(close(connection))
  as.character(openssl::sha256(connection))
}

fetch <- function(url, local, dataset, vintage) {
  if (!file.exists(local)) {
    utils::download.file(url, local, mode = "wb", quiet = TRUE,
                         headers = c("User-Agent" = "Mozilla/5.0"))
  }
  record_pin(req, dataset, vintage = vintage, source = url,
             n_rows = NA_integer_, note = paste("sha256", sha256_file(local)))
  local
}

# --- Census county population estimates ---------------------------------------
census_2019 <- fetch(
  "https://www2.census.gov/programs-surveys/popest/datasets/2010-2019/counties/totals/co-est2019-alldata.csv",
  file.path(ext, "co-est2019.csv"), "census-popest-counties", "vintage 2019")
census_2023 <- fetch(
  "https://www2.census.gov/programs-surveys/popest/datasets/2020-2023/counties/totals/co-est2023-alldata.csv",
  file.path(ext, "co-est2023.csv"), "census-popest-counties", "vintage 2023")

metro_counties <- c("015", "021", "037", "043", "081", "111", "119", "147",
                    "149", "159", "165", "169", "187", "189")

read_popest <- function(path, cols) {
  utils::read.csv(path, fileEncoding = "latin1", colClasses = "character") |>
    filter(STATE == "47", COUNTY %in% metro_counties) |>
    transmute(county_fips = paste0("47", COUNTY), county = CTYNAME,
              across(all_of(cols), as.integer))
}

county_pop <- read_popest(census_2019, c("POPESTIMATE2010", "POPESTIMATE2015", "POPESTIMATE2019")) |>
  inner_join(read_popest(census_2023, c("POPESTIMATE2020", "POPESTIMATE2023")), by = c("county_fips", "county")) |>
  rename(pop2010 = POPESTIMATE2010, pop2015 = POPESTIMATE2015, pop2019 = POPESTIMATE2019,
         pop2020 = POPESTIMATE2020, pop2023 = POPESTIMATE2023)
stopifnot(nrow(county_pop) == 14)
utils::write.csv(county_pop, file.path(req, "data", "county_pop.csv"), row.names = FALSE)
utils::write.csv(county_pop, file.path(out, "county_population_2010_2023.csv"), row.names = FALSE)

# --- BLS QCEW annual county files ---------------------------------------------
qcew_rows <- purrr::map_dfr(c("47037", "47187", "47149"), function(fips) {
  purrr::map_dfr(c(2019, 2023), function(year) {
    local <- fetch(sprintf("https://data.bls.gov/cew/data/api/%d/a/area/%s.csv", year, fips),
                   file.path(ext, sprintf("qcew_%s_%d.csv", fips, year)), "bls-qcew-annual-county", as.character(year))
    utils::read.csv(local, colClasses = "character") |>
      filter(own_code == "5",
             (agglvl_code == "71" & industry_code == "10") |
               (industry_code %in% c("62", "624") & agglvl_code %in% c("74", "75"))) |>
      transmute(county_fips = fips, year = year, naics = industry_code,
                annual_avg_employment = as.integer(annual_avg_emplvl),
                avg_annual_pay = as.integer(avg_annual_pay))
  })
})
utils::write.csv(qcew_rows, file.path(out, "qcew_private_pay_benchmarks.csv"), row.names = FALSE)

# --- e-file Phase 0 government grants, verified against its manifest ----------
phase0 <- "https://nccsdata.s3.amazonaws.com/processed/efile/phase0/latest/"
manifest <- jsonlite::fromJSON(paste0(phase0, "_manifest.json"))
gg_local <- file.path(req, "data", "government_grants.parquet")
if (!file.exists(gg_local)) {
  utils::download.file(paste0(phase0, "government_grants.parquet"), gg_local, mode = "wb", quiet = TRUE)
}
gg_entry <- manifest$files[manifest$files$name == "government_grants.parquet", ]
gg_sha <- sha256_file(gg_local)
stopifnot(gg_sha == gg_entry$sha256)
record_pin(req, "efile-phase0-government_grants",
           vintage = paste("phase0", manifest$vintage, "git", substr(manifest$producer_git_sha, 1, 7)),
           source = paste0(phase0, "government_grants.parquet"),
           n_rows = gg_entry$row_count,
           note = paste("sha256 verified against _manifest.json:", gg_sha))
cat("external inputs built\n")


# =============================================================================
# Section: build-peers (formerly build-peers.R)
# =============================================================================

# Peer-metro universes: read the BMF master for the states hosting the
# comparison metros and keep EIN -> CBSA / county / subsector.
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
source(here::here("R", "request_read.R"))
out_dir <- file.path(req, "data")

peer_cbsas <- c(
  "34980" = "Nashville", "32820" = "Memphis", "28940" = "Knoxville",
  "12420" = "Austin", "16740" = "Charlotte", "39580" = "Raleigh",
  "26900" = "Indianapolis", "31140" = "Louisville", "18140" = "Columbus",
  "28140" = "Kansas City", "27260" = "Jacksonville", "36420" = "Oklahoma City",
  "12060" = "Atlanta", "19740" = "Denver", "41180" = "St. Louis",
  "17140" = "Cincinnati", "40060" = "Richmond", "13820" = "Birmingham",
  "41700" = "San Antonio", "38060" = "Phoenix"
)

xwalk_cbsa   <- arrow::read_parquet(file.path(out_dir, "cbsa_crosswalk.parquet"))
xwalk_county <- arrow::read_parquet(file.path(out_dir, "county_fips_crosswalk.parquet"))

peer_counties <- xwalk_cbsa |> filter(cbsa_code %in% names(peer_cbsas))
peer_states <- unique(xwalk_county$geo_state_abbr[xwalk_county$geo_county_fips %in% peer_counties$county_fips])
cat("states:", peer_states, "\n")

bmf_manifest <- jsonlite::fromJSON("https://nccsdata.s3.amazonaws.com/geocoding/unified-bmf/latest/_manifest.json")
bmf_identity <- sprintf("vintage %s, git %s, sha256 %s", bmf_manifest$vintage, bmf_manifest$git_sha,
                        bmf_manifest$files$bmf_unified_geocoded.parquet$sha256)
bmf <- read_bmf_master(
  req, state = peer_states, cache = FALSE,
  columns = c("ein", "geo_state_abbr", "geo_county", "subsection_code",
              "foundation_code", "nteev2_subsector", "nteev2_code", "ntee_code_clean",
              "first_year_in_bmf", "last_year_in_bmf", "ruling_date"),
  note = paste("peer-metro states for CBSA benchmarking;", bmf_identity)
)

peers <- bmf |>
  left_join(xwalk_county, by = c("geo_state_abbr", "geo_county" = "geo_county_raw")) |>
  left_join(xwalk_cbsa, by = c("geo_county_fips" = "county_fips")) |>
  filter(cbsa_code %in% names(peer_cbsas)) |>
  mutate(metro = peer_cbsas[cbsa_code], ein9 = gsub("-", "", ein))

arrow::write_parquet(peers, file.path(out_dir, "universe_peers.parquet"))
print(peers |> filter(last_year_in_bmf >= 2026) |> count(metro, sort = TRUE) |> as.data.frame())


# =============================================================================
# Section: build-funders (formerly build-funders.R)
# =============================================================================

# Build 4: who funds whom, from the funders' own returns (round 2 item F).
#
# Two tables, both e-file, filtered to funders whose registry address is in
# Davidson County:
#   - Schedule I Part II (grants to US organizations and governments) from
#     e-file v2.1, filed by public charities that make grants. Itemizes
#     recipients receiving more than $5,000 in aggregate in the year, cash
#     and noncash kept separate. Carries the recipient EIN on most rows.
#   - Form 990-PF grants paid (Part XV in older forms, Part XIV on the 2023
#     form; the table keeps the PF-P15 name) from the separate efilepf_v2_3
#     release. Recipient name and address only, no EIN. Includes grants to
#     individuals, which are flagged here and excluded from the
#     organization-level outputs.
#
# Scope: tax years 2019-2023 by ROW (TAX_YEAR and RETURN_TYPE checked per
# row; release-year files 2019-2024 are read so late filings are caught).
# One filing per funder and tax year, chosen by RETURN_TIME_STAMP desc then
# OBJECTID desc, the same rule as build-panel.R.
#
# The raw files are large (up to 440 MB each). Each is downloaded, hashed,
# filtered, and deleted, so nothing multi-gigabyte stays on the laptop; the
# sha256 of every raw file is pinned in _pins.csv.
#
# What this table can and cannot show (see PLAN.md item F): it is outgoing
# giving by Davidson-based funders wherever the recipient is. Funders based
# elsewhere are absent. A shared funder is not duplication and an absent
# match is not a gap.
#
# Outputs:
#   data/funders_davidson_2019_2023.parquet   one row per grant record
#   output/funders_davidson_by_funder_year.csv funder-year aggregates
#   output/build-funders.txt                   this script's console log

library(dplyr)

request_dir <- here::here("requests", "2026-10-nashville-msa")
source(here::here("R", "request_read.R"))
data_dir <- file.path(request_dir, "data")
output_dir <- file.path(request_dir, "output")
scratch_dir <- file.path(data_dir, "funders-raw")
dir.create(scratch_dir, recursive = TRUE, showWarnings = FALSE)
options(timeout = 1800)

release_years <- 2019:2024
tax_years_in_scope <- 2019:2023
efile_base <- "https://nccs-efile.s3.us-east-1.amazonaws.com/public"


# --- helpers ------------------------------------------------------------------

#' sha256 of a file on disk
#'
#' @param path Path to the file.
#' @return A lowercase hex string.
sha256_file <- function(path) {
  connection <- file(path, open = "rb")
  on.exit(close(connection))
  as.character(openssl::sha256(connection))
}

#' Download one raw e-file table, pin its hash, apply a filter, delete it
#'
#' @param url Public HTTPS URL of the raw file.
#' @param dataset Pin label for `_pins.csv`.
#' @param reader A function taking a local path and returning the filtered
#'   rows as a data frame.
#' @return The data frame returned by `reader`.
#' @details The raw file is removed after reading so only the filtered
#'   rows persist locally. The pin records the raw file's sha256 and the
#'   number of rows kept.
fetch_filter_discard <- function(url, dataset, reader) {
  local_path <- file.path(scratch_dir, basename(url))
  if (!file.exists(local_path)) {
    utils::download.file(url, local_path, mode = "wb", quiet = TRUE)
  }
  raw_hash <- sha256_file(local_path)
  kept <- reader(local_path)
  record_pin(request_dir, dataset, vintage = basename(url), source = url,
             n_rows = nrow(kept), note = paste("sha256 of raw file", raw_hash, "; rows kept after Davidson funder filter"))
  unlink(local_path)
  kept
}

#' Keep one filing per funder and tax year
#'
#' @param grant_rows Grant records carrying ORG_EIN, TAX_YEAR,
#'   RETURN_TIME_STAMP and OBJECTID.
#' @return The rows belonging to the latest filing per funder-year.
#' @details Latest by RETURN_TIME_STAMP, ties broken by the larger
#'   OBJECTID, matching build-panel.R.
select_one_filing_per_funder_year <- function(grant_rows) {
  chosen_filings <- grant_rows |>
    distinct(ORG_EIN, TAX_YEAR, RETURN_TIME_STAMP, OBJECTID) |>
    arrange(ORG_EIN, TAX_YEAR, desc(RETURN_TIME_STAMP), desc(OBJECTID)) |>
    group_by(ORG_EIN, TAX_YEAR) |>
    slice(1) |>
    ungroup() |>
    select(ORG_EIN, TAX_YEAR, OBJECTID)
  grant_rows |>
    semi_join(chosen_filings, by = c("ORG_EIN", "TAX_YEAR", "OBJECTID"))
}

#' Normalize an organization name for crude matching
#'
#' @param name Character vector.
#' @return Upper-case letters and digits only, with common suffixes removed.
normalize_name <- function(name) {
  name |>
    toupper() |>
    stringr::str_replace_all("[^A-Z0-9 ]", " ") |>
    stringr::str_replace_all("\\b(THE|INC|INCORPORATED|CORP|CORPORATION|FOUNDATION|FDN|OF|AND|FOR)\\b", " ") |>
    stringr::str_squish()
}


# --- Davidson funder universe (registry) --------------------------------------

universe_tn <- arrow::read_parquet(file.path(data_dir, "universe_tn.parquet"))

davidson_registry <- universe_tn |>
  filter(geo_county_fips == "47037") |>
  mutate(
    is_private_foundation = as.integer(subsection_code) == 3 &
      foundation_code %in% c("02", "03", "04", "2", "3", "4"),
    active_2026 = last_year_in_bmf >= 2026
  ) |>
  select(funder_ein9 = ein9, funder_name_registry = org_name_display,
         funder_subsection = subsection_code, funder_is_private_foundation = is_private_foundation,
         funder_active_2026 = active_2026, funder_subsector = nteev2_subsector,
         funder_zip = org_addr_zip5)

davidson_ein9 <- davidson_registry$funder_ein9
cat("Davidson registry rows:", nrow(davidson_registry),
    "| private foundations:", sum(davidson_registry$funder_is_private_foundation, na.rm = TRUE),
    "| active 2026:", sum(davidson_registry$funder_active_2026), "\n")


# --- Schedule I Part II, e-file v2.1 ------------------------------------------

read_schedule_i_davidson <- function(local_path) {
  data.table::fread(local_path, colClasses = "character", showProgress = FALSE) |>
    as_tibble() |>
    filter(ORG_EIN %in% davidson_ein9, RETURN_TYPE == "990",
           as.integer(TAX_YEAR) %in% tax_years_in_scope)
}

schedule_i_raw <- purrr::map_dfr(release_years, function(release_year) {
  fetch_filter_discard(
    url = sprintf("%s/efile_v2_1/SI-P02-T01-GRANTS-US-ORGS-GOVTS-%d.CSV", efile_base, release_year),
    dataset = "efile-v2_1-schedule-i-part-ii",
    reader = read_schedule_i_davidson
  )
})

schedule_i <- schedule_i_raw |>
  mutate(TAX_YEAR = as.integer(TAX_YEAR)) |>
  select_one_filing_per_funder_year() |>
  transmute(
    source_table = "Schedule I Part II (full 990)",
    funder_ein9 = ORG_EIN,
    funder_name = ORG_NAME_L1,
    tax_year = TAX_YEAR,
    filing_objectid = OBJECTID,
    recipient_name = SI_02_GRANT_US_ORG_NAME_L1,
    recipient_ein9 = ifelse(grepl("^[0-9]{9}$", SI_02_GRANT_US_ORG_EIN), SI_02_GRANT_US_ORG_EIN, NA_character_),
    recipient_city = SI_02_GRANT_US_ORG_ADDR_CITY,
    recipient_state = SI_02_GRANT_US_ORG_ADDR_STATE,
    recipient_zip5 = substr(SI_02_GRANT_US_ORG_ADDR_ZIP, 1, 5),
    recipient_status = SI_02_GRANT_US_ORG_IRC_SECTION,
    recipient_is_individual = FALSE,
    amount_cash = as.numeric(SI_02_GRANT_US_ORG_AMT_CASH),
    amount_noncash = as.numeric(SI_02_GRANT_US_ORG_AMT_NONCSH),
    purpose = SI_02_GRANT_US_ORG_PURPOSE
  )

cat("\nSchedule I: raw Davidson rows", nrow(schedule_i_raw), "| after one filing per funder-year", nrow(schedule_i),
    "| funders", n_distinct(schedule_i$funder_ein9), "\n")


# --- 990-PF grants paid, efilepf_v2_3 -----------------------------------------

read_pf_grants_davidson <- function(local_path) {
  arrow::read_parquet(local_path) |>
    mutate(across(everything(), as.character)) |>
    filter(ORG_EIN %in% davidson_ein9, RETURN_TYPE == "990PF",
           as.integer(TAX_YEAR) %in% tax_years_in_scope)
}

pf_grants_raw <- purrr::map_dfr(release_years, function(release_year) {
  fetch_filter_discard(
    url = sprintf("%s/efilepf_v2_3/PF-P15-T01-SUPPLEMENTARY-INFO-GRANT-PAID-%d.parquet", efile_base, release_year),
    dataset = "efilepf-v2_3-grants-paid",
    reader = read_pf_grants_davidson
  )
})

pf_grants <- pf_grants_raw |>
  mutate(TAX_YEAR = as.integer(TAX_YEAR)) |>
  select_one_filing_per_funder_year() |>
  transmute(
    source_table = "990-PF grants paid",
    funder_ein9 = ORG_EIN,
    funder_name = ORG_NAME_L1,
    tax_year = TAX_YEAR,
    filing_objectid = OBJECTID,
    recipient_name = coalesce(na_if(PF_15_G_PAID_RECIP_NAME_ORG_L1, ""), PF_15_G_PAID_RECIP_NAME_PERS),
    recipient_ein9 = NA_character_,
    recipient_city = PF_15_G_PAID_RECIP_ADDR_CITY,
    recipient_state = PF_15_G_PAID_RECIP_ADDR_STATE,
    recipient_zip5 = substr(PF_15_G_PAID_RECIP_ADDR_ZIP, 1, 5),
    recipient_status = PF_15_G_PAID_RECIP_STAT,
    recipient_is_individual = !is.na(PF_15_G_PAID_RECIP_NAME_PERS) & nzchar(PF_15_G_PAID_RECIP_NAME_PERS) |
      grepl("^(I|INDIVIDUAL|INDIVIDUALS|N/?A|NONE)$", toupper(trimws(coalesce(PF_15_G_PAID_RECIP_STAT, "")))) &
      (is.na(PF_15_G_PAID_RECIP_NAME_ORG_L1) | !nzchar(PF_15_G_PAID_RECIP_NAME_ORG_L1)),
    amount_cash = as.numeric(PF_15_G_PAID_AMT),
    amount_noncash = NA_real_,
    purpose = PF_15_G_PAID_PURPOSE
  )

cat("990-PF: raw Davidson rows", nrow(pf_grants_raw), "| after one filing per funder-year", nrow(pf_grants),
    "| funders", n_distinct(pf_grants$funder_ein9),
    "| rows flagged as individual recipients", sum(pf_grants$recipient_is_individual), "\n")


# --- combine, attach funder registry fields, locate recipients -----------------

davidson_registry_ein <- universe_tn |>
  filter(geo_county_fips == "47037") |>
  distinct(ein9) |>
  mutate(recipient_in_davidson_registry = TRUE)

davidson_registry_names <- universe_tn |>
  filter(geo_county_fips == "47037") |>
  transmute(recipient_name_key = normalize_name(org_name_display),
            recipient_city_key = toupper(trimws(org_addr_city)),
            recipient_ein9_by_name = ein9) |>
  distinct(recipient_name_key, recipient_city_key, .keep_all = TRUE)

funders <- bind_rows(schedule_i, pf_grants) |>
  left_join(davidson_registry, by = "funder_ein9") |>
  left_join(davidson_registry_ein, by = c("recipient_ein9" = "ein9")) |>
  mutate(recipient_name_key = normalize_name(recipient_name),
         recipient_city_key = toupper(trimws(recipient_city))) |>
  left_join(davidson_registry_names, by = c("recipient_name_key", "recipient_city_key")) |>
  mutate(
    recipient_in_davidson_registry = coalesce(recipient_in_davidson_registry, FALSE),
    recipient_matched_by = case_when(
      recipient_in_davidson_registry ~ "ein",
      !is.na(recipient_ein9_by_name) & !recipient_is_individual ~ "name+city (provisional)",
      TRUE ~ NA_character_
    ),
    recipient_ein9_matched = coalesce(
      ifelse(recipient_in_davidson_registry, recipient_ein9, NA_character_),
      ifelse(!recipient_is_individual, recipient_ein9_by_name, NA_character_)
    ),
    recipient_in_tennessee = toupper(trimws(recipient_state)) == "TN"
  ) |>
  select(-recipient_name_key, -recipient_city_key, -recipient_ein9_by_name, -recipient_in_davidson_registry)

stopifnot(all(funders$tax_year %in% tax_years_in_scope))
one_filing_check <- funders |>
  distinct(source_table, funder_ein9, tax_year, filing_objectid) |>
  count(source_table, funder_ein9, tax_year) |>
  filter(n > 1)
stopifnot(nrow(one_filing_check) == 0)

arrow::write_parquet(funders, file.path(data_dir, "funders_davidson_2019_2023.parquet"))


# --- summaries ----------------------------------------------------------------

organization_grants <- funders |>
  filter(!recipient_is_individual)

cat("\n== Records by source and tax year (organization recipients only) ==\n")
organization_grants |>
  group_by(source_table, tax_year) |>
  summarise(funders = n_distinct(funder_ein9), records = n(),
            cash_m = round(sum(amount_cash, na.rm = TRUE) / 1e6, 1),
            noncash_m = round(sum(amount_noncash, na.rm = TRUE) / 1e6, 1),
            share_recipient_tn = round(100 * mean(recipient_in_tennessee, na.rm = TRUE)),
            share_recipient_davidson_matched = round(100 * mean(!is.na(recipient_ein9_matched))),
            .groups = "drop") |>
  as.data.frame() |>
  print()

cat("\n== Individual-assistance rows excluded, by tax year ==\n")
funders |>
  filter(recipient_is_individual) |>
  group_by(tax_year) |>
  summarise(funders = n_distinct(funder_ein9), records = n(), cash_m = round(sum(amount_cash, na.rm = TRUE) / 1e6, 2), .groups = "drop") |>
  as.data.frame() |>
  print()

cat("\n== Recipient match method, organization recipients, 2019-2023 ==\n")
organization_grants |>
  count(source_table, recipient_matched_by) |>
  as.data.frame() |>
  print()

by_funder_year <- organization_grants |>
  group_by(source_table, funder_ein9, funder_name, funder_is_private_foundation, funder_active_2026, tax_year) |>
  summarise(records = n(), recipients_named = n_distinct(recipient_name),
            cash = sum(amount_cash, na.rm = TRUE), noncash = sum(amount_noncash, na.rm = TRUE),
            share_cash_to_tn = round(sum(amount_cash[recipient_in_tennessee %in% TRUE], na.rm = TRUE) / sum(amount_cash, na.rm = TRUE), 3),
            share_cash_to_davidson_matched = round(sum(amount_cash[!is.na(recipient_ein9_matched)], na.rm = TRUE) / sum(amount_cash, na.rm = TRUE), 3),
            .groups = "drop") |>
  arrange(desc(tax_year), desc(cash))
utils::write.csv(by_funder_year, file.path(output_dir, "funders_davidson_by_funder_year.csv"), row.names = FALSE)

cat("\n== Twenty largest Davidson funders by 2023 cash to organizations ==\n")
by_funder_year |>
  filter(tax_year == 2023) |>
  transmute(funder_name, source_table, records, cash_m = round(cash / 1e6, 1),
            share_cash_to_tn, share_cash_to_davidson_matched) |>
  head(20) |>
  as.data.frame() |>
  print()

cat("\n== Davidson-matched recipients with the most distinct Davidson funders, 2019-2023 ==\n")
organization_grants |>
  filter(!is.na(recipient_ein9_matched)) |>
  group_by(recipient_ein9_matched) |>
  summarise(recipient_name = first(recipient_name), funders = n_distinct(funder_ein9), records = n(),
            cash_m = round(sum(amount_cash, na.rm = TRUE) / 1e6, 1), .groups = "drop") |>
  arrange(desc(funders)) |>
  head(15) |>
  as.data.frame() |>
  print()

cat("\nwrote", nrow(funders), "rows to data/funders_davidson_2019_2023.parquet\n")
