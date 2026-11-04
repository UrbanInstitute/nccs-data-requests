# Grants paid to Davidson County recipients, tax year 2023, for every
# organization on the requester's list that itemizes grants on its own
# return: the full 990's Schedule I (recipients over $5,000 in aggregate,
# with EIN) and the 990-PF grants-paid list (name and address only).
#
# The requester asked (2026-11-03) that the sheet show, for funders that give
# beyond Nashville, only their Nashville/Davidson grants. Operating expenses
# cannot be split by place, so they stay as filed; this script adds columns
# beside them: grants paid to all recipients, the part going to recipients
# located in Davidson County under the one rule in davidson-rule.R (EIN on
# the BMF, else Tennessee ZIP, else city), and the check of the itemized
# total against the return's own grants-paid line.
#
# A funder with no tax year 2023 return in the releases at all gets its
# tax year 2022 grants instead, and the sheet says which year each figure
# is (requester's instruction, 2026-11-04). A funder that filed for 2023
# but itemized nothing is not carried back: the rule is in grant-rules.R.
#
# Coverage: every listed private foundation with a 2023 or 2022 990-PF in the
# e-file release, wherever it is registered (the grants-paid rows are pulled from the public release by
# EIN), and every listed Davidson-based full-990 filer with Schedule I rows
# in the funder extract. Listed full-990 filers registered outside Davidson
# are not in the extract and are not covered; the log names them.
#
# Inputs:
#   data/list_matched.csv                     the matched list (profile-list.R)
#   data/funders_davidson_2019_2023.parquet   every grant row by a Davidson-based funder (build.R)
#   data/universe_tn.parquet                  Tennessee BMF extract (build.R)
#   data/panel_990_national.parquet           full-990 panel, for the Part IX grants line
#   efilepf_v2_3 grants-paid files, release years 2023-2024 (downloaded, filtered, deleted)
#   output/boedecker_grants_davidson.csv      cross-check against profile-boedecker.R
#   data/list_filled.xlsx                     the requester's filled sheet (profile-list.R)
#
# Outputs:
#   output/listed_funders_davidson_grants.csv   one row per listed funder: tax year, totals, Davidson part, check
#   data/list_filled.xlsx                            the sheet with the grant columns added
#   output/profile-davidson-grants.txt               console log (via run-all.R)

suppressPackageStartupMessages(library(dplyr))

request_dir <- here::here("requests", "2026-10-nashville-msa")
source(here::here("R", "request_read.R"))
source(file.path(request_dir, "davidson-rule.R"))
source(file.path(request_dir, "grant-rules.R"))
data_dir <- file.path(request_dir, "data")
output_dir <- file.path(request_dir, "output")
scratch_dir <- file.path(data_dir, "funders-raw")
dir.create(scratch_dir, recursive = TRUE, showWarnings = FALSE)
options(timeout = 1800)

efile_base <- "https://nccs-efile.s3.us-east-1.amazonaws.com/public"
pf_release_years <- 2023:2024


# --- 1. Listed organizations ------------------------------------------------

listed <- read.csv(file.path(data_dir, "list_matched.csv"), colClasses = "character") |>
  filter(nzchar(ein9)) |>
  select(row_id, name, ein, ein9, foundation_code, source_form_line, pf_grants_paid, pf_grants_paid_ty2022,
         operating_expenses_ty2023, figure_tax_year)

# Every listed private foundation by BMF foundation code, not only those
# with a 2023 990-PF in CORE: a fiscal-year filer's 2023 return can sit in
# the e-file release before CORE carries it (Joe C. Davis, year ending
# September 2024).
listed_pf <- listed |> filter(foundation_code %in% c("2", "3", "4") | grepl("990-PF", source_form_line))
cat("listed private foundations:", nrow(listed_pf), "\n")

davidson_lookup <- davidson_lookups(arrow::read_parquet(file.path(data_dir, "universe_tn.parquet")))


# --- 2. 990-PF grants paid for every listed foundation, from the public release

sha256_file <- function(path) {
  connection <- file(path, open = "rb")
  on.exit(close(connection))
  as.character(openssl::sha256(connection))
}

pf_raw <- purrr::map_dfr(pf_release_years, function(release_year) {
  url <- sprintf("%s/efilepf_v2_3/PF-P15-T01-SUPPLEMENTARY-INFO-GRANT-PAID-%d.parquet",
                 efile_base, release_year)
  local_path <- file.path(scratch_dir, basename(url))
  if (!file.exists(local_path)) {
    utils::download.file(url, local_path, mode = "wb", quiet = TRUE)
  }
  raw_hash <- sha256_file(local_path)
  kept <- arrow::read_parquet(local_path) |>
    mutate(across(everything(), as.character)) |>
    filter(ORG_EIN %in% listed_pf$ein9, RETURN_TYPE == "990PF", TAX_YEAR %in% c("2022", "2023"))
  record_pin(request_dir, "efilepf-v2_3-grants-paid-listed-foundations",
             vintage = basename(url), source = url, n_rows = nrow(kept),
             note = paste("sha256 of raw file", raw_hash, "; tax year 2022 and 2023 rows kept for the listed foundations"))
  unlink(local_path)
  kept
})

# One filing per foundation: the latest tax year it has (2023, else 2022),
# then the latest timestamp, then the larger OBJECTID (the rule in build.R).
pf_chosen <- pf_raw |>
  distinct(ORG_EIN, TAX_YEAR, RETURN_TIME_STAMP, OBJECTID) |>
  arrange(ORG_EIN, desc(TAX_YEAR), desc(RETURN_TIME_STAMP), desc(OBJECTID)) |>
  group_by(ORG_EIN) |>
  slice(1) |>
  ungroup()

pf_rows <- pf_raw |>
  semi_join(pf_chosen, by = c("ORG_EIN", "OBJECTID")) |>
  transmute(
    source_table = "990-PF grants paid",
    tax_year = as.integer(TAX_YEAR),
    funder_ein9 = ORG_EIN,
    recipient_ein9 = NA_character_,
    recipient_name = coalesce(na_if(PF_15_G_PAID_RECIP_NAME_ORG_L1, ""), PF_15_G_PAID_RECIP_NAME_PERS),
    recipient_city = PF_15_G_PAID_RECIP_ADDR_CITY,
    recipient_state = PF_15_G_PAID_RECIP_ADDR_STATE,
    recipient_zip5 = substr(PF_15_G_PAID_RECIP_ADDR_ZIP, 1, 5),
    recipient_is_individual = pf_recipient_is_individual(
      PF_15_G_PAID_RECIP_STAT, PF_15_G_PAID_RECIP_NAME_ORG_L1, PF_15_G_PAID_RECIP_NAME_PERS
    ),
    amount = as.numeric(PF_15_G_PAID_AMT)
  ) |>
  filter(!recipient_is_individual)

cat("foundations with grant rows in the release:", n_distinct(pf_rows$funder_ein9), "of", nrow(listed_pf), "\n")
cat("listed foundations with no 2022 or 2023 grants-paid rows in the release (rows):",
    paste(listed_pf$row_id[!listed_pf$ein9 %in% pf_rows$funder_ein9], collapse = ", "), "\n")


# --- 3. Schedule I rows for listed full-990 filers, from the funder extract ----

schedule_i_rows <- arrow::read_parquet(file.path(data_dir, "funders_davidson_2019_2023.parquet")) |>
  filter(tax_year %in% 2022:2023, source_table != "990-PF grants paid", funder_ein9 %in% listed$ein9) |>
  transmute(source_table, tax_year, funder_ein9, recipient_ein9, recipient_name, recipient_city,
            recipient_state, recipient_zip5, recipient_is_individual,
            amount = coalesce(amount_cash, 0) + coalesce(amount_noncash, 0))

# Each funder keeps one year: 2023 if it itemized grants for 2023, else
# 2022 only if no 2023 return of its own is in the releases (an expense
# figure for 2023 on the matched list, or 2023 grant rows here).
has_2023_return <- listed |>
  transmute(funder_ein9 = ein9, has_2023_return = nzchar(operating_expenses_ty2023))
all_rows <- bind_rows(pf_rows, schedule_i_rows)
year_to_use <- all_rows |>
  distinct(funder_ein9, tax_year) |>
  left_join(has_2023_return, by = "funder_ein9") |>
  group_by(funder_ein9) |>
  summarise(tax_year = grant_year_to_use(tax_year, first(has_2023_return)), .groups = "drop") |>
  filter(!is.na(tax_year))
grant_rows <- all_rows |> semi_join(year_to_use, by = c("funder_ein9", "tax_year"))
cat("funders with itemized rows for 2022 only but a 2023 return, so not carried back:",
    n_distinct(all_rows$funder_ein9) - nrow(year_to_use), "\n")

located <- recipient_in_davidson(
  grant_rows$recipient_ein9, grant_rows$recipient_state, grant_rows$recipient_city,
  grant_rows$recipient_zip5, davidson_lookup$county_by_ein, davidson_lookup$davidson_zips,
  davidson_lookup$known_zips
)
grant_rows <- grant_rows |>
  mutate(in_davidson = located$in_davidson, located_by = located$located_by)

cat("listed funders with itemized grants:", n_distinct(grant_rows$funder_ein9),
    "; grant rows:", nrow(grant_rows), "\n")
cat("funders by the tax year used:\n")
print(grant_rows |> distinct(funder_ein9, tax_year) |> count(tax_year) |> as.data.frame())
cat("\n== How recipients were located ==\n")
print(grant_rows |> count(located_by, in_davidson) |> as.data.frame())


# --- 4. Per funder: all recipients, Davidson recipients, and the return's own line

# Check: a 990-PF's itemized grants should equal its Part I line 25 (CORE
# contributions_paid, already on the matched list). A full 990's Schedule I
# lists domestic organizations only, so its itemized total is at most Part
# IX lines 1 to 3 (e-file panel exp_grants_paid), never above. A foundation
# whose list does not add to its line is reported, not stopped on: the
# return cannot say which rows are the extra ones. The check text goes on
# the sheet.
panel_grants_line <- arrow::read_parquet(file.path(data_dir, "panel_990_national.parquet")) |>
  filter(tax_year %in% 2022:2023, ein9 %in% listed$ein9) |>
  transmute(funder_ein9 = ein9, tax_year, part_ix_grants_paid = exp_grants_paid)

dollars <- function(x) paste0("$", format(round(x), big.mark = ",", trim = TRUE))

per_funder <- grant_rows |>
  group_by(funder_ein9, source_table, tax_year) |>
  summarise(
    grant_rows = n(),
    grants_all_recipients = sum(amount),
    grants_davidson_recipients = sum(amount[in_davidson]),
    grant_rows_davidson = sum(in_davidson),
    .groups = "drop"
  ) |>
  left_join(listed |> select(ein9, row_id, name, ein, pf_grants_paid, pf_grants_paid_ty2022),
            by = c("funder_ein9" = "ein9")) |>
  left_join(panel_grants_line, by = c("funder_ein9", "tax_year")) |>
  mutate(
    davidson_share = round(grants_davidson_recipients / grants_all_recipients, 3),
    pf_line_for_year = if_else(tax_year == 2023L, as.numeric(pf_grants_paid), as.numeric(pf_grants_paid_ty2022)),
    return_grants_line = if_else(source_table == "990-PF grants paid", pf_line_for_year, part_ix_grants_paid),
    check = case_when(
      source_table == "990-PF grants paid" & is.na(return_grants_line) ~
        paste0("Itemized grants could not be checked: no ", tax_year, " 990-PF in CORE carries the grants-paid line"),
      source_table == "990-PF grants paid" & abs(grants_all_recipients - return_grants_line) < 1 ~
        "Itemized grants equal the return's grants-paid line (990-PF Part I line 25)",
      source_table == "990-PF grants paid" ~
        paste0("Itemized grants differ from the return's grants-paid line (990-PF Part I line 25, ",
               dollars(return_grants_line), ") by ", dollars(grants_all_recipients - return_grants_line),
               "; the return does not say which rows are the difference"),
      grants_all_recipients <= return_grants_line + 1 ~
        paste0("Itemized Schedule I grants are within the return's grants lines (990 Part IX lines 1-3, ",
               dollars(return_grants_line), ")"),
      TRUE ~ paste0("Itemized Schedule I grants EXCEED the return's grants lines (990 Part IX lines 1-3, ",
                    dollars(return_grants_line), ")")
    )
  ) |>
  arrange(desc(grants_all_recipients))

cat("\n== Funders whose itemized grants do not reconcile to the return (or cannot be checked) ==\n")
print(per_funder |>
        filter(!grepl("^Itemized grants equal|within the return", check)) |>
        transmute(row_id, source_table, itemized = round(grants_all_recipients),
                  return_line = round(return_grants_line)) |>
        as.data.frame())

cat("\n== Listed funders: grants to all recipients and to Davidson County recipients, by the tax year used ==\n")
print(per_funder |>
        transmute(row_id, tax_year, source = substr(source_table, 1, 10), grant_rows,
                  all = round(grants_all_recipients), davidson = round(grants_davidson_recipients),
                  share = davidson_share, check = substr(check, 1, 40)) |>
        as.data.frame())

# Cross-check: the Colorado foundation's 2023 figure must equal the one from
# its own multi-year run.
boedecker_2023 <- read.csv(file.path(output_dir, "boedecker_grants_davidson.csv")) |>
  filter(tax_year == 2023)
boedecker_here <- per_funder |> filter(ein == "20-8495254")
stopifnot(nrow(boedecker_2023) == 1, nrow(boedecker_here) == 1,
          abs(boedecker_here$grants_davidson_recipients - boedecker_2023$dollars_davidson) < 1,
          abs(boedecker_here$grants_all_recipients - boedecker_2023$dollars_all) < 1)
cat("\nBoedecker 2023 Davidson figure agrees with profile-boedecker.R:",
    dollars(boedecker_here$grants_davidson_recipients), "\n")

write.csv(per_funder |> select(-pf_grants_paid, -pf_grants_paid_ty2022, -pf_line_for_year, -part_ix_grants_paid),
          file.path(output_dir, "listed_funders_davidson_grants.csv"), row.names = FALSE)


# --- 5. Add the columns to the requester's sheet (idempotent) ---------------

grant_columns <- c(
  "Grants paid, all recipients",
  "Grants paid, to recipients in Davidson County",
  "Grants paid: tax year",
  "Grants paid: check against the return"
)
# Names from an earlier version of this script, dropped if still present.
old_grant_columns <- c(
  "Grants paid, tax year 2023, all recipients",
  "Grants paid, tax year 2023, to recipients in Davidson County"
)

sheet <- readxl::read_excel(file.path(data_dir, "list_filled.xlsx"), sheet = "List with expenses") |>
  select(-any_of(c(grant_columns, old_grant_columns))) |>
  mutate(.row = row_number())

row_order <- read.csv(file.path(data_dir, "list_matched.csv"), colClasses = "character") |>
  transmute(.row = row_number(), row_id)
stopifnot(nrow(row_order) == nrow(sheet))

sheet_out <- sheet |>
  left_join(row_order, by = ".row") |>
  left_join(per_funder |> select(row_id, grants_all_recipients, grants_davidson_recipients, tax_year, check),
            by = "row_id") |>
  mutate(
    tax_year = as.character(tax_year),
    # A foundation whose expenses fall back to 2022 (no 2023 990-PF in CORE)
    # can still have its 2023 grants list in the e-file release: say so.
    `Figure note` = if_else(
      `Tax year` %in% "2022" & tax_year %in% "2023",
      paste0(`Figure note`, ". Its tax year 2023 Form 990-PF grants list is in the e-file release and feeds the grant columns"),
      `Figure note`
    )
  ) |>
  select(-.row, -row_id)
names(sheet_out)[names(sheet_out) == "grants_all_recipients"] <- grant_columns[1]
names(sheet_out)[names(sheet_out) == "grants_davidson_recipients"] <- grant_columns[2]
names(sheet_out)[names(sheet_out) == "tax_year"] <- grant_columns[3]
names(sheet_out)[names(sheet_out) == "check"] <- grant_columns[4]

writexl::write_xlsx(list(`List with expenses` = sheet_out), file.path(data_dir, "list_filled.xlsx"))
cat("\nsheet rows:", nrow(sheet_out), "; rows with grant columns filled:",
    sum(!is.na(sheet_out[[grant_columns[1]]])), "\n")
