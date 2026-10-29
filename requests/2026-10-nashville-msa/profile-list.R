# Pass 14: match the requester's list of 141 Nashville organizations (names
# and addresses, no EINs) to the IRS registry, then fill in each
# organization's tax year 2023 total expenses from whichever return it
# filed: full Form 990 Part I line 18, Form 990-EZ line 17, or Form 990-PF
# Part I line 26 (total expenses and disbursements, which for a foundation
# is mostly grants paid; lines 24 and 25 are given beside it). A column
# names the form and line for every figure. Where no return is available
# the sheet says why.
#
# Inputs (all gitignored under data/ or docs/):
#   docs/List of Nonprofits and Philanthropies for Thiya.xlsx  the list
#   data/list_match_candidates.csv   top-3 Jaro-Winkler candidates per row
#   data/list_match_decisions.csv    hand-checked decision per row
#   data/universe_tn.parquet         Tennessee registry extract (build-panel.R)
#   data/panel_990_national.parquet  full-990 e-file panel (build-panel.R)
#   CORE merged tier TY2023, 990 and 990-EZ (read live, pinned)
#
# Outputs:
#   data/list_filled.xlsx            the requester's sheet with expenses filled
#   data/list_matched.csv            one row per listed organization, all fields
#   output/explore-14-profile.txt    counts only (no names), captured by run-all

library(dplyr)

request_dir <- here::here("requests", "2026-10-nashville-msa")
source(here::here("R", "request_read.R"))
data_dir <- file.path(request_dir, "data")


# --- 1. The list and the hand-checked match decisions ----------------------

list_raw <- readxl::read_excel(
  file.path(request_dir, "docs", "List of Nonprofits and Philanthropies for Thiya.xlsx")
)

listed <- list_raw |>
  transmute(
    row_id = row_number(),
    name = Name,
    org_type = trimws(gsub(" ", " ", `Organization Type`)),
    address = Address
  )

candidates <- read.csv(file.path(data_dir, "list_match_candidates.csv"),
                       colClasses = "character")
decisions <- read.csv(file.path(data_dir, "list_match_decisions.csv"),
                      colClasses = "character", na.strings = "")

top_candidate <- candidates |>
  filter(rank == "1") |>
  select(row_id, top1_ein = ein)

matched <- listed |>
  mutate(row_id = as.character(row_id)) |>
  left_join(decisions, by = "row_id") |>
  left_join(top_candidate, by = "row_id") |>
  mutate(
    ein = case_when(
      decision == "top1" ~ top1_ein,
      decision == "ein" ~ ein,
      TRUE ~ NA_character_
    ),
    ein9 = gsub("-", "", ein)
  ) |>
  select(-top1_ein)

stopifnot(nrow(matched) == 141, all(matched$decision %in% c("top1", "ein", "none")))
stopifnot(all(!is.na(matched$ein[matched$decision != "none"])))


# --- 2. Registry fields for the matched EINs ---------------------------------

# The Tennessee extract covers most; a few (an Atlanta-registered charity,
# one found only in the e-file) need the national registry.
registry_tn <- arrow::read_parquet(file.path(data_dir, "universe_tn.parquet")) |>
  select(ein, org_name_display, org_addr_city, org_addr_zip5, subsection_code,
         foundation_code, ruling_date, income_amount, last_year_in_bmf)

missing_from_tn <- setdiff(na.omit(matched$ein), registry_tn$ein)

registry_extra <- read_bmf_master(
  request_dir,
  columns = names(registry_tn), cache = FALSE,
  note = "national lookup for listed organizations not in the TN extract"
) |>
  filter(ein %in% missing_from_tn)

registry <- bind_rows(registry_tn, registry_extra) |>
  distinct(ein, .keep_all = TRUE)

cat("matched EINs not in the TN extract:", length(missing_from_tn),
    "; found nationally:", nrow(registry_extra), "\n")


# --- 3. Tax year 2023 returns: e-file panel and CORE ------------------------
#
# "Tax year 2023" here is the IRS form year: the Form 990 whose accounting
# period begins in 2023 (calendar 2023, or a fiscal year ending in 2024).
# That is how the e-file panel labels returns, and how every round 1 figure
# was built. The CORE merged tier instead labels a return by the year its
# period ENDS, so a June 2023 fiscal year sits under CORE tax year 2023 but is
# the 2022 form. CORE 2023 and 2024 are read together and relabeled.

efile_all <- arrow::read_parquet(file.path(data_dir, "panel_990_national.parquet")) |>
  filter(ein9 %in% matched$ein9)

efile_2023 <- efile_all |>
  filter(tax_year == 2023) |>
  transmute(ein9, efile_name = org_name, efile_total_expenses = exp_total,
            efile_employees = employees)

latest_full_990 <- efile_all |>
  group_by(ein9) |>
  slice_max(tax_year, n = 1, with_ties = FALSE) |>
  ungroup() |>
  transmute(ein9, latest_full_990_year = tax_year, latest_full_990_expenses = exp_total)

core_raw <- bind_rows(lapply(2023:2024, function(core_year) {
  read_core(
    request_dir, tier = "merged", tax_year = core_year, form = "990combined",
    columns = c("ein", "tax_year", "source_form", "tax_period", "total_expenses"),
    note = "full 990 and 990-EZ for the listed organizations; relabeled to form year"
  )
}))

core_2023 <- core_raw |>
  mutate(
    ein9 = gsub("-", "", ein),
    period_end_year = as.integer(substr(tax_period, 1, 4)),
    period_end_month = as.integer(substr(tax_period, 5, 6)),
    form_year = if_else(period_end_month == 12L, period_end_year, period_end_year - 1L)
  ) |>
  filter(ein9 %in% matched$ein9, form_year == 2023L) |>
  arrange(ein9, desc(tax_period)) |>
  distinct(ein9, .keep_all = TRUE) |>
  transmute(ein9, core_form = source_form, core_tax_period = tax_period,
            core_total_expenses = total_expenses)

core_pf_2023 <- bind_rows(lapply(2023:2024, function(core_year) {
  read_core(
    request_dir, tier = "merged", tax_year = core_year, form = "990pf",
    columns = c("ein", "tax_year", "tax_period", "total_expenses_col_a",
                "total_operating_admin_expenses_col_a", "contributions_paid"),
    note = "990-PF total expenses, operating expenses and grants paid for listed foundations; relabeled to form year"
  )
})) |>
  mutate(
    ein9 = gsub("-", "", ein),
    period_end_year = as.integer(substr(tax_period, 1, 4)),
    period_end_month = as.integer(substr(tax_period, 5, 6)),
    form_year = if_else(period_end_month == 12L, period_end_year, period_end_year - 1L)
  ) |>
  filter(ein9 %in% matched$ein9, form_year == 2023L) |>
  arrange(ein9, desc(tax_period)) |>
  distinct(ein9, .keep_all = TRUE) |>
  transmute(ein9, pf_tax_period = tax_period, pf_total_expenses = total_expenses_col_a,
            pf_operating_admin_expenses = total_operating_admin_expenses_col_a,
            pf_grants_paid = contributions_paid)

stopifnot(!any(duplicated(efile_2023$ein9)))


# --- 4. Assemble: expenses where a full 990 exists, otherwise a reason -------

private_foundation_codes <- c("2", "3", "4")
church_codes <- c("10")

filled <- matched |>
  left_join(registry, by = "ein") |>
  left_join(efile_2023, by = "ein9") |>
  left_join(core_2023, by = "ein9") |>
  left_join(latest_full_990, by = "ein9") |>
  left_join(core_pf_2023, by = "ein9") |>
  mutate(
    full_990_expenses = coalesce(
      efile_total_expenses,
      if_else(core_form %in% "990", core_total_expenses, NA_real_)
    ),
    expenses_source = case_when(
      core_form %in% "990" & !is.na(efile_total_expenses) ~ "e-file and CORE (SOI) both hold the full 990",
      !is.na(efile_total_expenses) ~ "e-file full 990 (not in the CORE release)",
      core_form %in% "990" ~ "CORE (SOI) full 990 (not in the e-file release)",
      TRUE ~ NA_character_
    ),
    sources_disagree = core_form %in% "990" & !is.na(efile_total_expenses) &
      abs(core_total_expenses - efile_total_expenses) > 1,
    ez_total_expenses = if_else(core_form %in% "990ez", core_total_expenses, NA_real_),
    operating_expenses_ty2023 = coalesce(full_990_expenses, ez_total_expenses, pf_total_expenses),
    source_form_line = case_when(
      !is.na(full_990_expenses) ~ "Form 990, Part I line 18, total expenses",
      !is.na(ez_total_expenses) ~ "Form 990-EZ, line 17, total expenses",
      !is.na(pf_total_expenses) ~ "Form 990-PF, Part I line 26, total expenses and disbursements (includes grants paid)",
      TRUE ~ NA_character_
    ),
    period_for_figure = coalesce(core_tax_period, pf_tax_period),
    fiscal_year_end = if_else(
      !is.na(period_for_figure),
      format(as.Date(paste0(period_for_figure, "01"), "%Y%m%d"), "%B %Y"),
      NA_character_
    ),
    status_ty2023 = case_when(
      decision == "none" ~ "Not matched to the IRS registry",
      !is.na(full_990_expenses) ~ "Full Form 990 filed",
      !is.na(ez_total_expenses) ~ "Form 990-EZ filed",
      !is.na(pf_total_expenses) ~ "Form 990-PF filed (private foundation)",
      foundation_code %in% private_foundation_codes ~ "Private foundation; no tax year 2023 Form 990-PF in the IRS releases yet",
      foundation_code %in% church_codes ~ "Church or church-affiliated: not required to file",
      !is.na(last_year_in_bmf) & as.integer(last_year_in_bmf) < 2023L ~
        paste0("No longer on the IRS registry (last listed ", last_year_in_bmf, ")"),
      !is.na(ruling_date) & ruling_date >= as.Date("2024-01-01") ~ "Recognized in 2024 or later; no tax year 2023 return seen",
      !is.na(latest_full_990_year) ~
        paste0("No tax year 2023 full 990 in the IRS releases yet; last full 990 seen is tax year ",
               latest_full_990_year, " ($", trimws(format(latest_full_990_expenses, big.mark = ",")), ")"),
      TRUE ~ "No tax year 2023 full 990 or 990-EZ in the IRS releases (a 990-N postcard filer, a late filer, or not filing; the releases do not say which)"
    )
  )


# --- 5. Write the filled sheet and the detail file ---------------------------

sheet_out <- filled |>
  transmute(
    Name = name,
    `Organization Type` = list_raw$`Organization Type`,
    Address = address,
    `Operating Expenses` = operating_expenses_ty2023,
    `Source form and line` = source_form_line,
    `Tax year` = if_else(!is.na(operating_expenses_ty2023), "2023", NA_character_),
    `Fiscal year end` = if_else(!is.na(operating_expenses_ty2023), fiscal_year_end, NA_character_),
    `990-PF only: operating and administrative expenses (line 24)` = pf_operating_admin_expenses,
    `990-PF only: grants paid (line 25)` = pf_grants_paid,
    `IRS status for tax year 2023` = status_ty2023,
    `EIN` = ein,
    `Name on IRS registry` = org_name_display,
    `Match confidence` = confidence,
    `Match note` = note
  )

writexl::write_xlsx(
  list(`List with expenses` = sheet_out),
  file.path(data_dir, "list_filled.xlsx")
)

write.csv(filled, file.path(data_dir, "list_matched.csv"), row.names = FALSE, na = "")


# --- 6. Counts only for the captured output ----------------------------------

cat("\n== Match outcome (141 listed organizations) ==\n")
print(filled |> count(decision, confidence) |> as.data.frame())

cat("\n== Tax year 2023 status ==\n")
print(filled |> count(status_ty2023, sort = TRUE) |> as.data.frame())

cat("\n== Status by the requester's organization type ==\n")
print(filled |>
        mutate(has_full_990 = !is.na(operating_expenses_ty2023)) |>
        count(org_type, has_full_990) |>
        tidyr::pivot_wider(names_from = has_full_990, values_from = n, values_fill = 0) |>
        as.data.frame())

cat("\n== Source form and line for the filled rows ==\n")
print(filled |> filter(!is.na(operating_expenses_ty2023)) |> count(source_form_line) |> as.data.frame())
cat("\n== Full-990 rows: release coverage ==\n")
print(filled |> filter(!is.na(full_990_expenses)) |> count(expenses_source) |> as.data.frame())
cat("rows where CORE and e-file totals differ by more than $1:", sum(filled$sources_disagree), "\n")
cat("filled rows with a fiscal year end from CORE:", sum(!is.na(filled$fiscal_year_end) & !is.na(filled$operating_expenses_ty2023)), "\n")

cat("\n== Total expenses, tax year 2023, all filled rows ==\n")
print(summary(filled$operating_expenses_ty2023))


# --- 7. The listed organizations against Davidson charities ----------------
#
# Age (years since IRS recognition), size (tax year 2023 total expenses),
# reported employees and line 1e government grant share, for the listed
# organizations registered in Davidson County, beside all Davidson 501(c)(3)
# public charities (excluding hospitals and universities) on the same measures. Each row names its filing
# population. Counts only; no names.

davidson_charities <- registry_tn |>
  filter(ein %in% (arrow::read_parquet(file.path(data_dir, "universe_tn.parquet")) |>
                     filter(geo_county_fips == "47037", as.integer(subsection_code) == 3L,
                            !(foundation_code %in% c("2", "3", "4")), last_year_in_bmf >= 2026,
                            !(nteev2_subsector %in% c("HOS", "UNI")),
                            !(ein9 %in% c("620485733", "061395640"))) |>
                     pull(ein))) |>
  mutate(ein9 = gsub("-", "", ein))

listed_davidson <- filled |>
  filter(!is.na(ein9), ein9 %in% davidson_charities$ein9)

age_years <- function(ruling) as.numeric(as.Date("2026-07-01") - as.Date(ruling)) / 365.25

efile_2023_all <- arrow::read_parquet(file.path(data_dir, "panel_990_national.parquet")) |>
  filter(tax_year == 2023, ein9 %in% davidson_charities$ein9) |>
  select(ein9, exp_total, rev_total, employees)

grants_2023 <- arrow::read_parquet(file.path(data_dir, "government_grants.parquet")) |>
  filter(form_type == "990", tax_year == 2023) |>
  arrange(desc(filing_receipt_id)) |>
  distinct(ein, .keep_all = TRUE) |>
  transmute(ein9 = ein, govt_grants = coalesce(government_grants, 0))

profile_block <- function(ein9_set, label) {
  registry_rows <- davidson_charities |> filter(ein9 %in% ein9_set)
  full_990_rows <- efile_2023_all |> filter(ein9 %in% ein9_set) |> left_join(grants_2023, by = "ein9")
  tibble(
    population = label,
    organizations = nrow(registry_rows),
    median_age_years = round(median(age_years(registry_rows$ruling_date), na.rm = TRUE), 1),
    share_recognized_2020_or_later = round(100 * mean(as.Date(registry_rows$ruling_date) >= as.Date("2020-01-01"), na.rm = TRUE)),
    full_990_filers_2023 = nrow(full_990_rows),
    median_expenses_full_990 = round(median(full_990_rows$exp_total, na.rm = TRUE)),
    median_employees_full_990 = round(median(full_990_rows$employees, na.rm = TRUE)),
    share_reporting_1e = round(100 * mean(full_990_rows$govt_grants > 0, na.rm = TRUE)),
    aggregate_1e_share_of_revenue = round(100 * sum(full_990_rows$govt_grants, na.rm = TRUE) /
                                            sum(full_990_rows$rev_total, na.rm = TRUE), 1)
  )
}

listed_profile <- bind_rows(
  profile_block(listed_davidson$ein9, "Listed organizations registered in Davidson (public charities)"),
  profile_block(davidson_charities$ein9, "All Davidson 501(c)(3) public charities excl. hospitals and universities")
)

cat("\n== 7. Listed organizations against all Davidson public charities (registry for age; full 990 for size, employees and line 1e) ==\n")
print(as.data.frame(listed_profile))
write.csv(listed_profile, file.path(request_dir, "output", "list_profile_vs_davidson.csv"), row.names = FALSE)
