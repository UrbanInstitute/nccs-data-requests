# Boedecker Foundation: how much of its grant-making reaches Middle Tennessee
#
# The requester confirmed on 2026-11-03 that the Boedecker Foundation on her
# list is The Boedecker Foundation of Boulder, Colorado (EIN 20-8495254), a
# private foundation whose website says it gives much of its money to Middle
# Tennessee organizations. Its expense figure on the filled sheet is
# foundation-wide, so this script shows the Middle Tennessee share of its
# grants paid, by tax year, from its own Form 990-PF grants list.
#
# Source: 990-PF grants paid table (PF-P15-T01-SUPPLEMENTARY-INFO-GRANT-PAID)
# in the efilepf_v2_3 release, release-year files 2020-2024, one filing per
# tax year (latest RETURN_TIME_STAMP then OBJECTID, the rule used in build.R).
# "Middle Tennessee" means a recipient whose address is in a county of the
# Nashville-Davidson-Murfreesboro-Franklin metro area, matched by recipient
# city and state (the 990-PF carries no county). Grants to individuals are
# excluded. The raw files are downloaded, filtered to this one funder, hashed
# and deleted.
#
# Outputs:
#   output/boedecker_grants_by_region.csv   tax year x region: grants, dollars, share
#   output/boedecker_grants_rows.csv        one row per grant, with the region label
#   output/profile-boedecker.txt            console log (via run-all.R)

suppressPackageStartupMessages(library(dplyr))

request_dir <- here::here("requests", "2026-10-nashville-msa")
source(here::here("R", "request_read.R"))
data_dir <- file.path(request_dir, "data")
output_dir <- file.path(request_dir, "output")
scratch_dir <- file.path(data_dir, "funders-raw")
dir.create(scratch_dir, recursive = TRUE, showWarnings = FALSE)
options(timeout = 1800)

boedecker_ein9 <- "208495254"
release_years <- 2020:2024
efile_base <- "https://nccs-efile.s3.us-east-1.amazonaws.com/public"


# --- 1. Download, filter to the one funder, delete ---------------------------

sha256_file <- function(path) {
  connection <- file(path, open = "rb")
  on.exit(close(connection))
  as.character(openssl::sha256(connection))
}

raw_rows <- purrr::map_dfr(release_years, function(release_year) {
  url <- sprintf("%s/efilepf_v2_3/PF-P15-T01-SUPPLEMENTARY-INFO-GRANT-PAID-%d.parquet",
                 efile_base, release_year)
  local_path <- file.path(scratch_dir, basename(url))
  if (!file.exists(local_path)) {
    utils::download.file(url, local_path, mode = "wb", quiet = TRUE)
  }
  raw_hash <- sha256_file(local_path)
  kept <- arrow::read_parquet(local_path) |>
    mutate(across(everything(), as.character)) |>
    filter(ORG_EIN == boedecker_ein9, RETURN_TYPE == "990PF")
  record_pin(request_dir, "efilepf-v2_3-grants-paid-boedecker",
             vintage = basename(url), source = url, n_rows = nrow(kept),
             note = paste("sha256 of raw file", raw_hash, "; rows kept for EIN 20-8495254"))
  unlink(local_path)
  kept
})

one_filing_per_year <- raw_rows |>
  mutate(tax_year = as.integer(TAX_YEAR)) |>
  group_by(tax_year) |>
  filter(RETURN_TIME_STAMP == max(RETURN_TIME_STAMP)) |>
  filter(OBJECTID == max(OBJECTID)) |>
  ungroup()

cat("grant rows kept:", nrow(one_filing_per_year), "across tax years",
    paste(sort(unique(one_filing_per_year$tax_year)), collapse = ", "), "\n")


# --- 2. Label each recipient's region by city and state ----------------------

# Cities in the Nashville metro counties (Cannon, Cheatham, Davidson, Dickson,
# Macon, Maury, Robertson, Rutherford, Smith, Sumner, Trousdale, Williamson,
# Wilson). Any Tennessee city not on this list is reported separately so it
# can be checked by hand.
middle_tennessee_cities <- c(
  "NASHVILLE", "ANTIOCH", "MADISON", "HERMITAGE", "OLD HICKORY", "GOODLETTSVILLE",
  "WHITES CREEK", "JOELTON", "BRENTWOOD", "FRANKLIN", "SPRING HILL", "NOLENSVILLE",
  "FAIRVIEW", "THOMPSONS STATION", "MURFREESBORO", "SMYRNA", "LA VERGNE", "LAVERGNE",
  "HENDERSONVILLE", "GALLATIN", "PORTLAND", "WHITE HOUSE", "LEBANON", "MT JULIET",
  "MOUNT JULIET", "COLUMBIA", "DICKSON", "SPRINGFIELD", "ASHLAND CITY",
  "KINGSTON SPRINGS", "WOODBURY", "LAFAYETTE", "CARTHAGE", "HARTSVILLE"
)

grants <- one_filing_per_year |>
  transmute(
    tax_year,
    recipient_name = coalesce(na_if(PF_15_G_PAID_RECIP_NAME_ORG_L1, ""), PF_15_G_PAID_RECIP_NAME_PERS),
    recipient_is_individual = !is.na(PF_15_G_PAID_RECIP_NAME_PERS) & nzchar(PF_15_G_PAID_RECIP_NAME_PERS),
    recipient_city = toupper(trimws(PF_15_G_PAID_RECIP_ADDR_CITY)),
    recipient_state = toupper(trimws(PF_15_G_PAID_RECIP_ADDR_STATE)),
    amount = as.numeric(PF_15_G_PAID_AMT),
    purpose = PF_15_G_PAID_PURPOSE,
    region = case_when(
      recipient_state == "TN" & recipient_city %in% middle_tennessee_cities ~ "Middle Tennessee (Nashville metro)",
      recipient_state == "TN" ~ "Tennessee, outside the Nashville metro",
      TRUE ~ "Outside Tennessee"
    )
  ) |>
  filter(!recipient_is_individual)

cat("Tennessee cities not on the metro list (check by hand):\n")
print(grants |> filter(region == "Tennessee, outside the Nashville metro") |>
        count(recipient_city) |> as.data.frame())


# --- 3. Summarise and write --------------------------------------------------

by_region <- grants |>
  group_by(tax_year, region) |>
  summarise(grants = n(), dollars = sum(amount, na.rm = TRUE), .groups = "drop") |>
  group_by(tax_year) |>
  mutate(share_of_dollars = round(dollars / sum(dollars), 3)) |>
  ungroup() |>
  arrange(tax_year, region)

cat("\n== Boedecker Foundation grants paid by tax year and recipient region ==\n")
print(as.data.frame(by_region))

write.csv(by_region, file.path(output_dir, "boedecker_grants_by_region.csv"), row.names = FALSE)
write.csv(grants |> arrange(tax_year, region, desc(amount)),
          file.path(output_dir, "boedecker_grants_rows.csv"), row.names = FALSE)
