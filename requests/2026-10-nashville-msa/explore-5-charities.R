# Pass 5: restrict to 501(c)(3) public charities (not private foundations),
# excluding hospitals and universities; per-capita by county.
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
d <- file.path(req, "data")
pop <- read.csv(file.path(d, "county_pop.csv"), colClasses = c(county_fips = "character"))
u <- arrow::read_parquet(file.path(d, "universe_tn.parquet")) |> filter(cbsa_code == "34980")
p <- arrow::read_parquet(file.path(d, "panel_with_geo.parquet")) |>
  filter(as.integer(subsection_code) == 3, !eds_meds) |>
  mutate(pay_per_emp = ifelse(employees > 0 & comp_total > 0, comp_total / employees, NA),
         pay_per_emp = ifelse(pay_per_emp >= 5000 & pay_per_emp <= 400000, pay_per_emp, NA),
         pay_per_emp_real = pay_per_emp * deflator,
         where = ifelse(geo_county_fips == "47037", "Davidson", "Collar"))

cat("\n== Subsection of panel rows lacking BMF match (Nashville) ==\n")
print(p |> filter(metro == "Nashville", tax_year == 2023) |> count(is.na(subsection_code)))

cat("\n== Registered 501(c)(3) orgs per 10k residents by county, 2010/2019/2023 ==\n")
reg <- function(y) u |> filter(as.integer(subsection_code) == 3, first_year_in_bmf <= y, last_year_in_bmf >= y) |> count(geo_county_fips, name = paste0("orgs", y))
r <- Reduce(function(a, b) full_join(a, b, by = "geo_county_fips"), lapply(c(2010, 2019, 2023), reg)) |>
  inner_join(pop, by = c("geo_county_fips" = "county_fips")) |>
  mutate(per10k_2010 = round(1e4 * orgs2010 / pop2010, 1), per10k_2019 = round(1e4 * orgs2019 / pop2019, 1), per10k_2023 = round(1e4 * orgs2023 / pop2023, 1),
         pop_growth_10_23 = round(100 * (pop2023 / pop2010 - 1)), org_growth_10_23 = round(100 * (orgs2023 / orgs2010 - 1))) |>
  select(county, pop2023, orgs2023, per10k_2010, per10k_2019, per10k_2023, pop_growth_10_23, org_growth_10_23) |> arrange(-pop2023)
print(as.data.frame(r))

cat("\n== 501(c)(3) full-990 filers (excl HOS/UNI): expenses per resident by county, 2019 vs 2023 (2023 $) ==\n")
e <- p |> filter(metro == "Nashville", tax_year %in% c(2019, 2023)) |> group_by(geo_county_fips, tax_year) |>
  summarise(filers = n(), exp_real_m = sum(exp_total * deflator, na.rm = TRUE) / 1e6, employees = sum(employees, na.rm = TRUE), .groups = "drop") |>
  tidyr::pivot_wider(names_from = tax_year, values_from = c(filers, exp_real_m, employees)) |>
  inner_join(pop, by = c("geo_county_fips" = "county_fips")) |>
  mutate(exp_per_cap_2019 = round(1e6 * exp_real_m_2019 / pop2019), exp_per_cap_2023 = round(1e6 * exp_real_m_2023 / pop2023),
         emp_per_1k_2019 = round(1e3 * employees_2019 / pop2019, 1), emp_per_1k_2023 = round(1e3 * employees_2023 / pop2023, 1)) |>
  select(county, filers_2019, filers_2023, exp_per_cap_2019, exp_per_cap_2023, emp_per_1k_2019, emp_per_1k_2023) |> arrange(-exp_per_cap_2023)
print(as.data.frame(e))

cat("\n== Human services 501(c)(3): expenses per resident and employees by county, 2023 ==\n")
print(p |> filter(metro == "Nashville", tax_year == 2023, focus == "HMS") |> group_by(geo_county_fips) |>
  summarise(filers = n(), exp_m = sum(exp_total, na.rm = TRUE) / 1e6, employees = sum(employees, na.rm = TRUE)) |>
  inner_join(pop, by = c("geo_county_fips" = "county_fips")) |>
  mutate(exp_per_cap = round(1e6 * exp_m / pop2023), emp_per_1k = round(1e3 * employees / pop2023, 1)) |>
  select(county, pop2023, filers, exp_per_cap, emp_per_1k) |> arrange(-exp_per_cap) |> as.data.frame())

cat("\n== Metro-year table, 501(c)(3) charities excl HOS/UNI: Nashville vs Rest of US ==\n")
my <- p |> group_by(metro, tax_year) |>
  summarise(filers = n(), employees = sum(employees, na.rm = TRUE),
            exp_real_m = round(sum(exp_total * deflator, na.rm = TRUE) / 1e6),
            med_pay_real = round(median(pay_per_emp_real, na.rm = TRUE)),
            med_contrib_share = round(100 * median(contrib_share, na.rm = TRUE)),
            deficit = round(100 * mean(deficit, na.rm = TRUE)), under3mo = round(100 * mean(months_reserve < 3, na.rm = TRUE)),
            med_reserve = round(median(months_reserve, na.rm = TRUE), 1), .groups = "drop")
print(my |> filter(metro %in% c("Nashville", "Rest of US")) |> as.data.frame())

cat("\n== Peer ranking 2019->2023, 501(c)(3) excl HOS/UNI ==\n")
print(my |> filter(tax_year %in% c(2019, 2023)) |> group_by(metro) |>
  summarise(filers_23 = filers[2], filer_growth = round(100 * (filers[2] / filers[1] - 1)),
            emp_growth = round(100 * (employees[2] / employees[1] - 1)),
            real_exp_growth = round(100 * (exp_real_m[2] / exp_real_m[1] - 1)),
            pay_growth = round(100 * (med_pay_real[2] / med_pay_real[1] - 1), 1), med_pay_23 = med_pay_real[2],
            deficit_19 = deficit[1], deficit_23 = deficit[2], under3mo_23 = under3mo[2], contrib_23 = med_contrib_share[2]) |>
  arrange(-pay_growth) |> as.data.frame())

cat("\n== Nashville 501(c)(3) excl HOS/UNI by subsector, 2019 vs 2023 ==\n")
print(p |> filter(metro == "Nashville", tax_year %in% c(2019, 2023)) |> group_by(focus, tax_year) |>
  summarise(filers = n(), employees = sum(employees, na.rm = TRUE), exp_real_m = round(sum(exp_total * deflator, na.rm = TRUE) / 1e6),
            med_pay_real = round(median(pay_per_emp_real, na.rm = TRUE)), deficit = round(100 * mean(deficit, na.rm = TRUE)),
            under3mo = round(100 * mean(months_reserve < 3, na.rm = TRUE)), .groups = "drop") |> arrange(focus, tax_year) |> as.data.frame())

cat("\n== Within-org (balanced 2019-2023) Nashville 501(c)(3): human services deficit transitions ==\n")
bal <- arrow::read_parquet(file.path(d, "balanced_2019_2023.parquet")) |> inner_join(p |> filter(tax_year == 2023) |> distinct(ein2, subsection_code), by = "ein2")
print(bal |> filter(metro == "Nashville") |> group_by(focus) |> summarise(n = n(), deficit_19 = round(100 * mean(deficit_2019, na.rm = TRUE)), deficit_23 = round(100 * mean(deficit_2023, na.rm = TRUE)), both = round(100 * mean(deficit_2019 & deficit_2023, na.rm = TRUE)), med_reserve_19 = round(median(months_reserve_2019, na.rm = TRUE), 1), med_reserve_23 = round(median(months_reserve_2023, na.rm = TRUE), 1)) |> filter(n >= 30) |> as.data.frame())
print(bal |> filter(metro == "Rest of US") |> group_by(focus) |> summarise(n = n(), deficit_19 = round(100 * mean(deficit_2019, na.rm = TRUE)), deficit_23 = round(100 * mean(deficit_2023, na.rm = TRUE)), med_reserve_19 = round(median(months_reserve_2019, na.rm = TRUE), 1), med_reserve_23 = round(median(months_reserve_2023, na.rm = TRUE), 1)) |> filter(n >= 30) |> as.data.frame())
