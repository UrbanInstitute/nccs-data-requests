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
