# I want to make it read the other scrips
source(here::here("requests", "2026-10-southeast-michigan/build-universe.R"))
source(here::here("requests", "2026-10-southeast-michigan/data/output/universe.csv"))

# This request's folder (used to write _pins.csv).
source(here::here("R", "request_read.R"))
req <- here::here("requests", "2026-10-southeast-michigan")

out_dir <- file.path(req, "data", "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
file.path(out_dir,"universe.csv")

# For EINS in universe. Read CORE Processed 

core_combined <- read_core(req,tier = "soi", tax_year= 2023, form = "990combined",
columns = c("ein", "total_expenses","total_revenue","total_net_assets_eoy", 
            "total_liabilities_eoy","source_form","tax_month",
            "tax_period", "tax_year"))

employee_core <- read_core(req,tier = "soi", tax_year= 2023, form = "990",
                     columns = c("ein", "n_employees_w3"))

core <- dplyr::left_join(core_combined, employee_core, by= "ein")
EIN_core <- dplyr::inner_join(bmf_cfsem_universe, core, by= "ein")
#verify tax year
table(EIN_core$tax_year)

#keep latest tax period per EIN
#order tax_period 
EIN_core_sorted <- EIN_core[order(EIN_core$tax_period, decreasing = TRUE),]

#duplicated flags if there is a duplicate with TRUE
core_latest <- EIN_core_sorted [!duplicated(EIN_core_sorted$ein),]

# Print how many duplicates were removed
message("Duplicates resolved:", nrow(EIN_core) - nrow(core_latest))
# Duplicates resolved:1781

#Print: EINs with a 990 row, an EZ row, or no row; 2023 filers not in the current registry; 
#full-990 rows with zero employees but positive wages.

print(core_latest |>
        dplyr::count())
#2023 filers not in the current registry; full-990 rows with zero employees but positive wages.