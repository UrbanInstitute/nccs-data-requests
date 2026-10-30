library(dplyr)
source(here::here("R", "request_read.R"))

# This request's folder (used to write _pins.csv).
req <- here::here("requests", "2026-10-southeast-michigan")
out_dir <- file.path(req, "data", "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

bmf_cfsem_universe <- read.csv(file.path(out_dir, "universe.csv"))
bmf_seven_all_vintages <- read.csv(file.path(out_dir, "universe-all-vintages.csv"))

# For EINS in universe. Read CORE Processed 

core_combined <- read_core(req, tier = "soi", tax_year = 2023, form = "990combined",
  columns = c("ein", "total_revenue", "total_expenses",
              "total_assets_eoy", "total_liabilities_eoy", "source_form",
              "tax_period", "tax_year"))

core_combined <- core_combined |>
  dplyr::mutate(net_income = total_revenue - total_expenses)

employee_core <- read_core(req, tier = "soi", tax_year = 2023, form = "990",
  columns = c("ein", "tax_period", "n_employees_w3", "other_salaries_wages"))

core <- dplyr::left_join(core_combined, employee_core, by = c("ein", "tax_period"))
core_universe <- dplyr::inner_join(bmf_cfsem_universe, core, by = "ein")

# Verify the tax year on every row.
core_universe_2023 <- core_universe |>
  dplyr::filter(tax_year == 2023)
message("Rows dropped because tax_year is not 2023: ", nrow(core_universe) - nrow(core_universe_2023))

# Keep the latest tax period per EIN.
core_latest <- core_universe_2023 |>
  dplyr::arrange(ein, dplyr::desc(tax_period)) |>
  dplyr::distinct(ein, .keep_all = TRUE)

message("Duplicate EIN rows resolved (kept latest tax period): ", nrow(core_universe_2023) - nrow(core_latest))

#Print: EINs with a 990 row, an EZ row, or no row; 2023 filers not in the current registry; 
#full-990 rows with zero employees but positive wages.

eins_990 <- core_latest |>
  dplyr::filter(source_form == "990")

message("EINs with a 990 row: ", nrow(eins_990))

eins_990ez <- core_latest |>
  dplyr::filter(source_form == "990ez")

message("EINs with a 990-EZ row: ", nrow(eins_990ez))

eins_none <- bmf_cfsem_universe |>
  dplyr::filter(!ein %in% core_latest$ein)

message("Universe EINs with no 990 or 990-EZ row (mostly 990-N filers): ", nrow(eins_none))

# Tax year 2023 filers that were seven-county public charities in an earlier
# BMF vintage but are not in the current registry.
eins_not_in_registry <- core |>
  dplyr::filter(ein %in% bmf_seven_all_vintages$ein, !ein %in% bmf_cfsem_universe$ein) |>
  dplyr::distinct(ein)

message("Tax year 2023 filers no longer in the current registry: ", nrow(eins_not_in_registry))

#full-990 rows with zero employees but positive wages

positive_wage <- eins_990 |>
  dplyr::filter(n_employees_w3 == 0, other_salaries_wages > 0)

message("Full-990 rows with zero employees but positive wages: ", nrow(positive_wage))

# One row per EIN for step 3.
financials <- core_latest |>
  dplyr::select(ein, county_name, source_form, tax_period, total_revenue, total_expenses,
                net_income, total_assets_eoy, total_liabilities_eoy, n_employees_w3)
write.csv(financials, file.path(out_dir, "financials.csv"), row.names = FALSE)
message("Rows written to financials.csv: ", nrow(financials))