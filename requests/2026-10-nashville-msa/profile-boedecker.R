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
#   output/boedecker_reconciliation.csv     itemized total per year against the return's grants-paid line
#   output/boedecker_grants.xlsx            the same two tables as an Excel file for the requester
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

# Same rule as build.R: sort by timestamp then OBJECTID, descending, and
# keep the first row of each tax year, so a missing key never drops a year.
chosen_filings <- raw_rows |>
  mutate(tax_year = as.integer(TAX_YEAR)) |>
  distinct(tax_year, RETURN_TIME_STAMP, OBJECTID) |>
  arrange(tax_year, desc(RETURN_TIME_STAMP), desc(OBJECTID)) |>
  group_by(tax_year) |>
  slice(1) |>
  ungroup() |>
  select(tax_year, OBJECTID)

one_filing_per_year <- raw_rows |>
  mutate(tax_year = as.integer(TAX_YEAR)) |>
  semi_join(chosen_filings, by = c("tax_year", "OBJECTID"))

cat("grant rows kept:", nrow(one_filing_per_year), "across tax years",
    paste(sort(unique(one_filing_per_year$tax_year)), collapse = ", "), "\n")


# --- 2. Label each recipient's region by city and state ----------------------

# Cities in the fourteen Nashville metro counties (Cannon, Cheatham,
# Davidson, Dickson, Hickman, Macon, Maury, Robertson, Rutherford, Smith,
# Sumner, Trousdale, Williamson, Wilson), the same CBSA 34980 definition as
# build.R. This is an address-based proxy: it says where the recipient's
# mailing address is, not where its services reach. The script stops if a
# Tennessee city is not on the list, so it is classified by hand rather than
# silently counted as outside the metro.
middle_tennessee_cities <- c(
  "NASHVILLE", "ANTIOCH", "MADISON", "HERMITAGE", "OLD HICKORY", "GOODLETTSVILLE",
  "WHITES CREEK", "JOELTON", "BRENTWOOD", "FRANKLIN", "SPRING HILL", "NOLENSVILLE",
  "FAIRVIEW", "THOMPSONS STATION", "MURFREESBORO", "SMYRNA", "LA VERGNE", "LAVERGNE",
  "HENDERSONVILLE", "GALLATIN", "PORTLAND", "WHITE HOUSE", "LEBANON", "MT JULIET",
  "MOUNT JULIET", "COLUMBIA", "DICKSON", "SPRINGFIELD", "ASHLAND CITY",
  "KINGSTON SPRINGS", "WOODBURY", "LAFAYETTE", "CARTHAGE", "HARTSVILLE",
  "CENTERVILLE", "PEGRAM", "CHARLOTTE", "BURNS", "WHITE BLUFF", "GREENBRIER",
  "MOUNT PLEASANT", "WATERTOWN", "GORDONSVILLE", "WESTMORELAND"
)

grants <- one_filing_per_year |>
  transmute(
    tax_year,
    recipient_name = coalesce(na_if(PF_15_G_PAID_RECIP_NAME_ORG_L1, ""), PF_15_G_PAID_RECIP_NAME_PERS),
    # Same rule as build.R: a personal name, or an individual status code with
    # no organization name.
    recipient_is_individual = !is.na(PF_15_G_PAID_RECIP_NAME_PERS) & nzchar(PF_15_G_PAID_RECIP_NAME_PERS) |
      grepl("^(I|INDIVIDUAL|INDIVIDUALS|N/?A|NONE)$", toupper(trimws(coalesce(PF_15_G_PAID_RECIP_STAT, "")))) &
      (is.na(PF_15_G_PAID_RECIP_NAME_ORG_L1) | !nzchar(PF_15_G_PAID_RECIP_NAME_ORG_L1)),
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

unlisted_tennessee <- grants |>
  filter(region == "Tennessee, outside the Nashville metro") |>
  count(recipient_city)
if (nrow(unlisted_tennessee) > 0) {
  print(as.data.frame(unlisted_tennessee))
  stop("Tennessee recipient cities above are not on the metro list; classify them by hand and add them to the list or confirm they are outside the metro")
}


# --- 3. Check the yearly totals against the return's own grants-paid line ----

# The CORE 990-PF file carries each return's Part I line 25, contributions
# and grants paid. CORE labels a return by the year its period ends; this
# foundation files on a calendar year, so the labels agree. 2024 is checked
# only if CORE holds it.
core_grants_paid <- bind_rows(lapply(2020:2024, function(core_year) {
  tryCatch(
    read_core(request_dir, tier = "merged", tax_year = core_year, form = "990pf",
              columns = c("ein", "tax_year", "tax_period", "contributions_paid"),
              note = "Boedecker grants-paid line to check the itemized grants against"),
    error = function(e) NULL
  )
})) |>
  mutate(ein9 = gsub("-", "", ein)) |>
  filter(ein9 == boedecker_ein9) |>
  transmute(tax_year = as.integer(tax_year), tax_period, core_grants_paid = as.numeric(contributions_paid))

reconciliation <- grants |>
  group_by(tax_year) |>
  summarise(itemized_total = sum(amount, na.rm = TRUE), .groups = "drop") |>
  left_join(core_grants_paid, by = "tax_year") |>
  mutate(difference = itemized_total - core_grants_paid)

cat("\n== Itemized grants against the return's grants-paid line (CORE) ==\n")
print(as.data.frame(reconciliation))
checked <- reconciliation |> filter(!is.na(core_grants_paid))
stopifnot(nrow(checked) > 0, all(abs(checked$difference) < 1))
cat("years checked against the return:", paste(checked$tax_year, collapse = ", "),
    "; not in CORE yet:", paste(setdiff(reconciliation$tax_year, checked$tax_year), collapse = ", "), "\n")


# --- 4. Summarise and write --------------------------------------------------

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
write.csv(reconciliation, file.path(output_dir, "boedecker_reconciliation.csv"), row.names = FALSE)
write.csv(grants |> arrange(tax_year, region, desc(amount)),
          file.path(output_dir, "boedecker_grants_rows.csv"), row.names = FALSE)

writexl::write_xlsx(
  list(`By year and region` = by_region,
       `Grant by grant` = grants |> arrange(tax_year, region, desc(amount))),
  file.path(output_dir, "boedecker_grants.xlsx")
)
