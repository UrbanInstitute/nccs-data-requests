library(dplyr)
source(here::here("R", "request_read.R"))

# This request's folder (used to write _pins.csv).
req <- here::here("requests", "2026-10-southeast-michigan")
out_dir <- file.path(req, "data", "output")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# For the region and each county compute every sheet, bands exactly as on the template,
# lower bound inclusive.
# Operating surplus is net income over total revenue;
# exclude negative-revenue rows (print the count) and
# assign zero when revenue or net income is zero (print the count).

bmf_cfsem_universe <- read.csv(file.path(out_dir, "universe.csv"))
financials <- read.csv(file.path(out_dir, "financials.csv"))

message("Public charities in universe: ", nrow(bmf_cfsem_universe))
message("Rows in financials: ", nrow(financials))

region_label <- "Seven-county region"
counties <- sort(unique(bmf_cfsem_universe$county_name))
geos <- c(region_label, counties)

#' Share of organizations in each band, for the region and each county
#'
#' @param data A data frame with one row per organization, a `county_name`
#'   column, and a `band` column holding the template category each
#'   organization falls in.
#' @param sheet The template sheet name, written into the output.
#' @param band_levels The template's categories in display order. Bands
#'   with no organizations still appear, with a share of zero.
#' @return A data frame with one row per geography and band: `geography`,
#'   `sheet`, `band`, `share` (percent of that geography's organizations)
#'   and `n` (the denominator, all organizations in that geography).
make_distribution <- function(data, sheet, band_levels) {
  both <- dplyr::bind_rows(
    dplyr::mutate(data, geography = region_label),
    dplyr::mutate(data, geography = county_name)
  )

  both |>
    dplyr::mutate(
      geography = factor(geography, levels = geos),
      band = factor(band, levels = band_levels)
    ) |>
    dplyr::count(geography, band, .drop = FALSE, name = "k") |>
    dplyr::group_by(geography) |>
    dplyr::mutate(
      n = sum(k),
      share = ifelse(n > 0, 100 * k / n, NA)
    ) |>
    dplyr::ungroup() |>
    dplyr::transmute(
      geography = as.character(geography),
      sheet = sheet,
      band = as.character(band),
      share, n
    )
}

#' Assign a dollar amount to one of the template's five bands
#'
#' @param x A numeric vector of dollar amounts.
#' @return A character vector of band labels. The lower bound of each band
#'   is inclusive, so exactly $100,000 is "$100K-499K". Negative amounts
#'   fall in the lowest band. Missing amounts return NA.
dollar_band <- function(x) {
  dplyr::case_when(
    is.na(x) ~ NA_character_,
    x < 1e5 ~ "<$100K",
    x < 5e5 ~ "$100K-499K",
    x < 1e6 ~ "$500K-999K",
    x < 1e7 ~ "$1M-9.9M",
    TRUE ~ "$10M+"
  )
}

dollar_levels <- c("<$100K", "$100K-499K", "$500K-999K", "$1M-9.9M", "$10M+")

number <- bmf_cfsem_universe |>
  dplyr::count(county_name, name = "n") |>
  dplyr::transmute(
    geography = county_name, sheet = "Number",
    band = "Public charities", share = NA_real_, n
  )

subsector_levels <- c(
  "Arts, Culture & Humanities", "Education", "Environment and Animals",
  "Health", "Human Services", "International Foreign Affairs",
  "Public, Societal Benefit", "Religion Related",
  "Mutual/Membership Benefit", "Unclassified"
)

subsector_data <- bmf_cfsem_universe |>
  dplyr::mutate(band = ifelse(subsector %in% subsector_levels, subsector, "Unclassified"))

message(
  "Subsector values outside the template list (counted as Unclassified): ",
  sum(!bmf_cfsem_universe$subsector %in% subsector_levels)
)

subsector <- make_distribution(subsector_data, "Subsector", subsector_levels)

#### Age sheet ####
# Age is 2026 minus the ruling year. Missing ruling dates go in "Not reported".
age_levels <- c("0-5", "6-10", "11-25", "26-49", "50+", "Not reported")

age_data <- bmf_cfsem_universe |>
  dplyr::mutate(
    ruling_year = as.integer(substr(ruling_date, 1, 4)),
    age = 2026L - ruling_year,
    band = dplyr::case_when(
      is.na(age) | age < 0 ~ "Not reported",
      age < 6 ~ "0-5",
      age < 11 ~ "6-10",
      age < 26 ~ "11-25",
      age < 50 ~ "26-49",
      TRUE ~ "50+"
    )
  )

message("Missing ruling date (Not reported): ", sum(is.na(age_data$ruling_year)))
message("Ruling year after 2026 (also Not reported): ", sum(age_data$age < 0, na.rm = TRUE))

age <- make_distribution(age_data, "Age", age_levels)

#### Revenue, Expenses, Assets, Liabilities sheets (990 and 990-EZ filers) ####
message("Source forms in financials:")
print(dplyr::count(financials, source_form))

revenue_data <- financials |>
  dplyr::mutate(band = dollar_band(total_revenue)) |>
  dplyr::filter(!is.na(band))
message(
  "Revenue: missing ", sum(is.na(financials$total_revenue)),
  ", negative (put in lowest band) ", sum(financials$total_revenue < 0, na.rm = TRUE)
)
revenue <- make_distribution(revenue_data, "Revenue", dollar_levels)

expenses_data <- financials |>
  dplyr::mutate(band = dollar_band(total_expenses)) |>
  dplyr::filter(!is.na(band))
message(
  "Expenses: missing ", sum(is.na(financials$total_expenses)),
  ", negative (put in lowest band) ", sum(financials$total_expenses < 0, na.rm = TRUE)
)
expenses <- make_distribution(expenses_data, "Expenses", dollar_levels)

assets_data <- financials |>
  dplyr::mutate(band = dollar_band(total_assets_eoy)) |>
  dplyr::filter(!is.na(band))
message(
  "Assets: missing ", sum(is.na(financials$total_assets_eoy)),
  ", negative (put in lowest band) ", sum(financials$total_assets_eoy < 0, na.rm = TRUE)
)
assets <- make_distribution(assets_data, "Assets", dollar_levels)

liabilities_data <- financials |>
  dplyr::mutate(band = dollar_band(total_liabilities_eoy)) |>
  dplyr::filter(!is.na(band))
message(
  "Liabilities: missing ", sum(is.na(financials$total_liabilities_eoy)),
  ", negative (put in lowest band) ", sum(financials$total_liabilities_eoy < 0, na.rm = TRUE)
)
liabilities <- make_distribution(liabilities_data, "Liabilities", dollar_levels)

#### Operating surplus sheet ####
# Net income divided by total revenue, as a percent.
surplus_levels <- c(
  "-20% or lower", "-19.99 to -5", "-4.99 to -0.01", "0",
  "0.1 to 4.99", "5 to 19.99", "20%+"
)

# Drop rows with negative revenue (counted) and rows missing revenue or net income.
message(
  "Operating surplus: negative-revenue rows excluded: ",
  sum(financials$total_revenue < 0, na.rm = TRUE)
)
message(
  "Operating surplus: missing revenue or net income (excluded): ",
  sum(is.na(financials$total_revenue) | is.na(financials$net_income))
)

surplus_data <- financials |>
  dplyr::filter(!is.na(total_revenue), !is.na(net_income), total_revenue >= 0)

# Zero revenue or zero net income is assigned a surplus of zero.
surplus_data <- surplus_data |>
  dplyr::mutate(
    assigned_zero = total_revenue == 0 | net_income == 0,
    pct = ifelse(assigned_zero, 0, 100 * net_income / total_revenue)
  )

message(
  "Operating surplus: assigned zero (revenue or net income is zero): ",
  sum(surplus_data$assigned_zero)
)

# Lower bound inclusive, so exactly -20% falls in "-19.99 to -5".
surplus_data <- surplus_data |>
  dplyr::mutate(band = dplyr::case_when(
    pct < -20 ~ "-20% or lower",
    pct < -5 ~ "-19.99 to -5",
    pct < 0 ~ "-4.99 to -0.01",
    pct == 0 ~ "0",
    pct < 5 ~ "0.1 to 4.99",
    pct < 20 ~ "5 to 19.99",
    TRUE ~ "20%+"
  ))

surplus <- make_distribution(surplus_data, "Operating Surplus", surplus_levels)

#### Employees sheet (full 990 filers only) ####
employee_levels <- c("Zero or not reported", "1", "2-9", "10-19", "20-49", "50+")

employee_data <- financials |>
  dplyr::filter(source_form == "990")

message("Full 990 filers: ", nrow(employee_data))
message(
  "Missing employee count (put in the zero band): ",
  sum(is.na(employee_data$n_employees_w3))
)

employee_data <- employee_data |>
  dplyr::mutate(
    employees = ifelse(is.na(n_employees_w3) | n_employees_w3 < 0,
      0, n_employees_w3
    ),
    band = dplyr::case_when(
      employees < 1 ~ "Zero or not reported",
      employees < 2 ~ "1",
      employees < 10 ~ "2-9",
      employees < 20 ~ "10-19",
      employees < 50 ~ "20-49",
      TRUE ~ "50+"
    )
  )

employees <- make_distribution(employee_data, "Employees", employee_levels)

#### Combine all sheets and check ####
measures <- dplyr::bind_rows(
  number, subsector, age, revenue, expenses,
  surplus, assets, liabilities, employees
)

# Shares should add to 100 for every geography and sheet (except Number).
share_totals <- measures |>
  dplyr::filter(sheet != "Number", n > 0) |>
  dplyr::group_by(geography, sheet) |>
  dplyr::summarise(total = sum(share), .groups = "drop")

message(
  "Rows where shares do not add to 100: ",
  sum(abs(share_totals$total - 100) > 0.000001)
)

#### Write output/measures-long.csv ####
write.csv(measures, file.path(out_dir, "measures-long.csv"), row.names = FALSE)
message("Rows written to measures-long.csv: ", nrow(measures))