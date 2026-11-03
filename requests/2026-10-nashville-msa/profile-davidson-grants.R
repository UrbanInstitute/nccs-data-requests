# Grants paid to Davidson County recipients, tax year 2023, for every
# organization on the requester's list that itemizes grants on its own
# return: the full 990's Schedule I (recipients over $5,000 in aggregate,
# with EIN) and the 990-PF grants-paid list (name and address only).
#
# The requester asked (2026-11-03) that the sheet show, for funders that give
# beyond Nashville, only their Nashville/Davidson grants. Operating expenses
# cannot be split by place, so they stay as filed; this script adds two
# columns beside them: grants paid to all recipients, and the part going to
# recipients located in Davidson County under the one rule in
# davidson-rule.R (EIN on the BMF, else Tennessee ZIP, else city).
#
# Inputs:
#   data/list_matched.csv                     the matched list (profile-list.R)
#   data/funders_davidson_2019_2023.parquet   every grant row by a Davidson-based funder (build.R)
#   data/universe_tn.parquet                  Tennessee BMF extract (build.R)
#   data/panel_990_national.parquet           full-990 panel, for the Part IX grants line
#   output/boedecker_grants_davidson.csv      the Colorado foundation, done separately (profile-boedecker.R)
#   data/list_filled.xlsx                     the requester's filled sheet (profile-list.R)
#
# Outputs:
#   output/listed_funders_davidson_grants_2023.csv   one row per listed funder: totals, Davidson part, check
#   data/list_filled.xlsx                            the sheet with the two grant columns added
#   output/profile-davidson-grants.txt               console log (via run-all.R)

suppressPackageStartupMessages(library(dplyr))

request_dir <- here::here("requests", "2026-10-nashville-msa")
source(file.path(request_dir, "davidson-rule.R"))
data_dir <- file.path(request_dir, "data")
output_dir <- file.path(request_dir, "output")

boedecker_ein <- "20-8495254"


# --- 1. Listed organizations and their 2023 grant rows ----------------------

listed <- read.csv(file.path(data_dir, "list_matched.csv"), colClasses = "character") |>
  filter(nzchar(ein9)) |>
  select(row_id, name, ein, ein9, pf_grants_paid)

grant_rows <- arrow::read_parquet(file.path(data_dir, "funders_davidson_2019_2023.parquet")) |>
  filter(tax_year == 2023, !recipient_is_individual, funder_ein9 %in% listed$ein9)

davidson_lookup <- davidson_lookups(arrow::read_parquet(file.path(data_dir, "universe_tn.parquet")))

located <- recipient_in_davidson(
  grant_rows$recipient_ein9, grant_rows$recipient_state, grant_rows$recipient_city,
  grant_rows$recipient_zip5, davidson_lookup$county_by_ein, davidson_lookup$davidson_zips
)
grant_rows <- grant_rows |>
  mutate(
    amount = coalesce(amount_cash, 0) + coalesce(amount_noncash, 0),
    in_davidson = located$in_davidson,
    located_by = located$located_by
  )

cat("listed funders with itemized 2023 grants:", n_distinct(grant_rows$funder_ein9),
    "; grant rows:", nrow(grant_rows), "\n")
cat("\n== How recipients were located ==\n")
print(grant_rows |> count(located_by, in_davidson) |> as.data.frame())


# --- 2. Per funder: all recipients, Davidson recipients, and the return's own line

# Check: a 990-PF's itemized grants should equal its Part I line 25 (CORE
# contributions_paid, already on the matched list). A full 990's Schedule I
# lists domestic organizations only, so its itemized total is at most Part
# IX line 1 plus lines 2 and 3 (e-file panel exp_grants_paid), never above.
panel_grants_line <- arrow::read_parquet(file.path(data_dir, "panel_990_national.parquet")) |>
  filter(tax_year == 2023, ein9 %in% listed$ein9) |>
  transmute(funder_ein9 = ein9, part_ix_grants_paid = exp_grants_paid)

per_funder <- grant_rows |>
  group_by(funder_ein9, source_table) |>
  summarise(
    grant_rows = n(),
    grants_all_recipients = sum(amount),
    grants_davidson_recipients = sum(amount[in_davidson]),
    grant_rows_davidson = sum(in_davidson),
    .groups = "drop"
  ) |>
  left_join(listed |> select(ein9, row_id, name, ein, pf_grants_paid), by = c("funder_ein9" = "ein9")) |>
  left_join(panel_grants_line, by = "funder_ein9") |>
  mutate(
    davidson_share = round(grants_davidson_recipients / grants_all_recipients, 3),
    return_grants_line = if_else(source_table == "990-PF grants paid",
                                 as.numeric(pf_grants_paid), part_ix_grants_paid),
    check = case_when(
      source_table == "990-PF grants paid" & abs(grants_all_recipients - return_grants_line) < 1 ~ "equals 990-PF line 25",
      source_table == "990-PF grants paid" & is.na(return_grants_line) ~ "no 2023 990-PF in CORE to check against",
      source_table == "990-PF grants paid" ~ paste0("DIFFERS from 990-PF line 25 by $",
                                                    format(round(grants_all_recipients - return_grants_line), big.mark = ",")),
      grants_all_recipients <= return_grants_line + 1 ~ "within Part IX lines 1-3",
      TRUE ~ "EXCEEDS Part IX lines 1-3"
    )
  ) |>
  arrange(desc(grants_all_recipients))

# A 990-PF whose itemized list does not add to line 25 is reported, not
# stopped on: the two cases seen (HCA Healthcare Foundation, Frist
# Foundation) list more than line 25, and the return itself cannot say
# which rows are the extra ones. The Davidson figure still comes from the
# itemized rows; the check column carries the difference for the reader.
not_reconciled <- per_funder |> filter(grepl("DIFFERS|EXCEEDS", check) | is.na(return_grants_line))
cat("\n== Funders whose itemized grants do not reconcile to the return (or have no CORE line) ==\n")
print(not_reconciled |>
        transmute(row_id, source_table, itemized = round(grants_all_recipients),
                  return_line = round(return_grants_line), check) |>
        as.data.frame())

cat("\n== Listed funders, tax year 2023: grants to all recipients and to Davidson County recipients ==\n")
print(per_funder |>
        transmute(row_id, source = substr(source_table, 1, 10), grant_rows,
                  all = round(grants_all_recipients), davidson = round(grants_davidson_recipients),
                  share = davidson_share, check) |>
        as.data.frame())


# --- 3. The Colorado foundation, from its own run ---------------------------

boedecker_2023 <- read.csv(file.path(output_dir, "boedecker_grants_davidson.csv")) |>
  filter(tax_year == 2023)
boedecker_row <- listed |> filter(ein == boedecker_ein)
stopifnot(nrow(boedecker_2023) == 1, nrow(boedecker_row) == 1)

per_funder <- bind_rows(
  per_funder,
  tibble(
    funder_ein9 = boedecker_row$ein9, source_table = "990-PF grants paid",
    grant_rows = boedecker_2023$grants_all,
    grants_all_recipients = boedecker_2023$dollars_all,
    grants_davidson_recipients = boedecker_2023$dollars_davidson,
    grant_rows_davidson = boedecker_2023$grants_davidson,
    row_id = boedecker_row$row_id, name = boedecker_row$name, ein = boedecker_row$ein,
    davidson_share = boedecker_2023$davidson_share_of_dollars,
    check = "equals 990-PF line 25 (profile-boedecker.R)"
  )
)

write.csv(per_funder |> select(-pf_grants_paid, -part_ix_grants_paid),
          file.path(output_dir, "listed_funders_davidson_grants_2023.csv"), row.names = FALSE)


# --- 4. Add the two columns to the requester's sheet (idempotent) -----------

grant_columns <- c(
  "Grants paid, tax year 2023, all recipients",
  "Grants paid, tax year 2023, to recipients in Davidson County"
)

sheet <- readxl::read_excel(file.path(data_dir, "list_filled.xlsx"), sheet = "List with expenses") |>
  select(-any_of(grant_columns)) |>
  mutate(.row = row_number())

row_order <- read.csv(file.path(data_dir, "list_matched.csv"), colClasses = "character") |>
  transmute(.row = row_number(), row_id)
stopifnot(nrow(row_order) == nrow(sheet))

sheet_out <- sheet |>
  left_join(row_order, by = ".row") |>
  left_join(per_funder |> select(row_id, grants_all_recipients, grants_davidson_recipients), by = "row_id") |>
  select(-.row, -row_id)
names(sheet_out)[names(sheet_out) == "grants_all_recipients"] <- grant_columns[1]
names(sheet_out)[names(sheet_out) == "grants_davidson_recipients"] <- grant_columns[2]

writexl::write_xlsx(list(`List with expenses` = sheet_out), file.path(data_dir, "list_filled.xlsx"))
cat("\nsheet rows:", nrow(sheet_out), "; rows with grant columns filled:",
    sum(!is.na(sheet_out[[grant_columns[1]]])), "\n")
