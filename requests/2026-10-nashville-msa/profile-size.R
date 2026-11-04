# Size category for every organization on the requester's list.
#
# The requester chose (2026-11-04) three bands: Small under $1 million,
# Medium $1 million to under $10 million, Large $10 million and over. The
# amount banded depends on what the organization is:
#   philanthropic organization (her type column): grants paid to recipients
#     in Davidson County, from profile-davidson-grants.R, because she wants
#     foundations sized by their Nashville giving, not their own spending;
#   every other organization: total expenses, from profile-list.R.
# Each figure is tax year 2023, or tax year 2022 where 2023 is not in the
# releases; the sheet already says which. A row with neither figure gets
# no band and a reason.
#
# Inputs:
#   data/list_filled.xlsx   the filled sheet (profile-list.R, profile-davidson-grants.R)
# Outputs:
#   data/list_filled.xlsx   the sheet with "Size" and "Size basis" added (idempotent)
#   output/profile-size.txt console log (via run-all.R)

suppressPackageStartupMessages(library(dplyr))

request_dir <- here::here("requests", "2026-10-nashville-msa")
data_dir <- file.path(request_dir, "data")
source(file.path(request_dir, "size-rules.R"))

size_columns <- c("Size", "Size basis")
philanthropic_type <- "Philanthropic organization"

sheet <- readxl::read_excel(file.path(data_dir, "list_filled.xlsx"), sheet = "List with expenses") |>
  select(-any_of(size_columns))

sized <- sheet |>
  mutate(
    is_philanthropic = trimws(`Organization Type`) == philanthropic_type,
    amount_for_size = if_else(is_philanthropic,
                              `Grants paid, to recipients in Davidson County`,
                              `Operating Expenses`),
    year_for_size = if_else(is_philanthropic, `Grants paid: tax year`, `Tax year`),
    Size = size_band(amount_for_size),
    `Size basis` = case_when(
      is_philanthropic & !is.na(Size) ~
        paste0("Grants paid to recipients in Davidson County, tax year ", year_for_size),
      !is.na(Size) ~ paste0("Total expenses, tax year ", year_for_size),
      grepl("^Removed from the list", `IRS status for tax year 2023`) ~ "Removed from the list at the requester's request",
      is_philanthropic ~ "No itemized grants for tax year 2023 or 2022 in the IRS releases",
      TRUE ~ "No tax year 2023 or 2022 return in the IRS releases (see the IRS status column)"
    )
  )

sheet_out <- sized |>
  relocate(all_of(size_columns), .after = `Organization Type`) |>
  select(-is_philanthropic, -amount_for_size, -year_for_size)

writexl::write_xlsx(list(`List with expenses` = sheet_out), file.path(data_dir, "list_filled.xlsx"))

cat("== Size bands ==\n")
print(sized |> count(is_philanthropic, Size) |> as.data.frame())
cat("\n== Size basis ==\n")
print(sized |> count(`Size basis`) |> as.data.frame())
cat("\n== Philanthropic organizations ==\n")
print(sized |> filter(is_philanthropic) |>
        transmute(Name, davidson_grants = round(amount_for_size), year_for_size, Size) |>
        as.data.frame())
