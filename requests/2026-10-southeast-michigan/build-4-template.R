library(dplyr)
library(tidyr)
library(openxlsx2)

# This request's folders (same as the other steps).
req <- here::here("requests", "2026-10-southeast-michigan")
out_dir <- file.path(req, "data", "output")
template_dir <- file.path(req, "template")

core_tax_year <- "2023"
bmf_vintage <- unique(read.csv(file.path(out_dir, "universe.csv"))$last_vintage_ym)
stopifnot("universe.csv should hold exactly one BMF vintage" = length(bmf_vintage) == 1)
message("BMF vintage: ", bmf_vintage)

#### Copy the template (the original is never written over) ####
template_name <- "CFSEM Census Fact Sheet Figures.xlsx"
template_path <- file.path(template_dir, template_name)
stopifnot("Template not found in template/" = file.exists(template_path))

new_path <- file.path(out_dir, "CFSEM Census Fact Sheet Figures - filled.xlsx")
file.copy(template_path, new_path, overwrite = TRUE)
message("Copied template to: ", new_path)

#### Read the measures from step 3 ####
long <- read.csv(file.path(out_dir, "measures-long.csv"), check.names = FALSE)

# Order used in the template: the region first, then the counties A to Z.
region <- "Seven-county region"
counties <- sort(setdiff(unique(long$geography), region))
message("Counties found: ", length(counties))
geo_order <- c(region, counties)

wb <- openxlsx2::wb_load(new_path)

#### Number sheet (counties only, counts go in column B) ####
number <- long |>
  dplyr::filter(sheet == "Number")
number <- number[match(counties, number$geography), ]

wb <- openxlsx2::wb_add_data(wb, "Number", x = number$n,
                             start_row = 2, start_col = 2, col_names = FALSE)

#### Subsector sheet (bands down the rows, geographies across the columns) ####
sub_data <- long |>
  dplyr::filter(sheet == "Subsector")

sub_bands <- unique(sub_data$band)
stopifnot("Subsector should have 10 bands" = length(sub_bands) == 10)

# One row per band, one column per geography. Shares become fractions (12% = 0.12).
sub_wide <- sub_data |>
  dplyr::mutate(share = share / 100) |>
  dplyr::select(band, geography, share) |>
  tidyr::pivot_wider(names_from = geography, values_from = share)
sub_wide <- sub_wide[match(sub_bands, sub_wide$band), geo_order]

wb <- openxlsx2::wb_add_data(wb, "Subsector", x = sub_wide,
                             start_row = 2, start_col = 2, col_names = FALSE)

# n goes in row 12, under each geography.
sub_n <- sub_data |>
  dplyr::distinct(geography, n)
sub_n <- sub_n[match(geo_order, sub_n$geography), ]

wb <- openxlsx2::wb_add_data(wb, "Subsector", x = "n",
                             start_row = 12, start_col = 1, col_names = FALSE)
wb <- openxlsx2::wb_add_data(wb, "Subsector", x = as.data.frame(t(sub_n$n)),
                             start_row = 12, start_col = 2, col_names = FALSE)

# The Subsector cells have no percent format in the template, so add it.
wb <- openxlsx2::wb_add_numfmt(wb, "Subsector", dims = "B2:I11", numfmt = "0%")

#### Sheets with bands across the columns and geographies down the rows ####
# The number is how many bands the template has on each sheet.
banded_sheets <- c("Age" = 5, "Revenue" = 5, "Expenses" = 5,
                   "Operating Surplus" = 7, "Assets" = 5, "Liabilities" = 5,
                   "Employees" = 6)

for (sheet_name in names(banded_sheets)) {
  
  sheet_data <- long |>
    dplyr::filter(sheet == sheet_name)
  
  # Age has an extra "Not reported" band that the template does not have.
  bands <- unique(sheet_data$band)
  template_bands <- setdiff(bands, "Not reported")
  stopifnot("Number of bands does not match the template" =
              length(template_bands) == banded_sheets[[sheet_name]])
  
  # One row per geography, one column per band.
  wide <- sheet_data |>
    dplyr::mutate(share = share / 100) |>
    dplyr::select(geography, band, share) |>
    tidyr::pivot_wider(names_from = band, values_from = share)
  wide <- wide[match(geo_order, wide$geography), ]
  
  # Print which band fills which template column, so the pairing can be eyeballed.
  header <- openxlsx2::wb_to_df(wb, sheet_name, col_names = FALSE,
                                dims = paste0("B1:", LETTERS[1 + length(template_bands)], "1"))
  message(sheet_name, " columns (template <- band): ",
          paste(unlist(header), "<-", template_bands, collapse = "; "))

  # The bands go in B2 and across (the cells are already formatted as percent).
  wb <- openxlsx2::wb_add_data(wb, sheet_name, x = wide[, template_bands],
                               start_row = 2, start_col = 2, col_names = FALSE)
  
  # n goes in column J. Column G on some sheets holds a note, so we skip it.
  n_values <- sheet_data |>
    dplyr::distinct(geography, n)
  n_values <- n_values[match(geo_order, n_values$geography), ]
  
  wb <- openxlsx2::wb_add_data(wb, sheet_name, x = "n",
                               start_row = 1, start_col = 10, col_names = FALSE)
  wb <- openxlsx2::wb_add_data(wb, sheet_name, x = n_values$n,
                               start_row = 2, start_col = 10, col_names = FALSE)
  
  # Age: the "Not reported" share goes in column I.
  if (sheet_name == "Age") {
    wb <- openxlsx2::wb_add_data(wb, sheet_name, x = "Not reported",
                                 start_row = 1, start_col = 9, col_names = FALSE)
    wb <- openxlsx2::wb_add_data(wb, sheet_name, x = wide[["Not reported"]],
                                 start_row = 2, start_col = 9, col_names = FALSE)
    wb <- openxlsx2::wb_add_numfmt(wb, sheet_name, dims = "I2:I9", numfmt = "0%")
  }
  
  # Employees: relabel the 0 band.
  if (sheet_name == "Employees") {
    wb <- openxlsx2::wb_add_data(wb, sheet_name, x = "zero or not reported",
                                 start_row = 1, start_col = 2, col_names = FALSE)
  }
  
  message(sheet_name, ": done")
}

#### Source lines: fill the [Date] placeholder and name today's data products ####
bmf_text <- paste0("Source: National Center for Charitable Statistics Unified Business Master File, ",
                   bmf_vintage, " vintage")
pz_text <- paste0("Source: National Center for Charitable Statistics CORE series, tax year ",
                  core_tax_year, ", Form 990 and 990-EZ filers")
pc_text <- paste0("Source: National Center for Charitable Statistics CORE series, tax year ",
                  core_tax_year, ", Form 990 filers")

wb <- openxlsx2::wb_add_data(wb, "Number", x = bmf_text, start_row = 10, start_col = 1, col_names = FALSE)
wb <- openxlsx2::wb_add_data(wb, "Subsector", x = bmf_text, start_row = 13, start_col = 1, col_names = FALSE)
wb <- openxlsx2::wb_add_data(wb, "Age", x = bmf_text, start_row = 11, start_col = 1, col_names = FALSE)

for (sheet_name in c("Revenue", "Expenses", "Operating Surplus", "Assets", "Liabilities")) {
  wb <- openxlsx2::wb_add_data(wb, sheet_name, x = pz_text,
                               start_row = 11, start_col = 1, col_names = FALSE)
}
wb <- openxlsx2::wb_add_data(wb, "Employees", x = pc_text,
                             start_row = 11, start_col = 1, col_names = FALSE)

#### Save the copy ####
openxlsx2::wb_save(wb, new_path, overwrite = TRUE)
message("Saved: ", new_path)

#### Read the saved file back and check every row adds to 100% ####
saved <- openxlsx2::wb_load(new_path)
for (sheet_name in names(banded_sheets)) {
  cells <- openxlsx2::wb_to_df(saved, sheet_name, col_names = FALSE,
                               dims = paste0("B2:", LETTERS[1 + banded_sheets[[sheet_name]]], "9"))
  row_sums <- rowSums(cells)
  ok <- if (sheet_name == "Age") all(row_sums <= 1 + 1e-6) else all(abs(row_sums - 1) < 1e-6)
  message(sheet_name, " rows add to 100%: ", ok)
}