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
