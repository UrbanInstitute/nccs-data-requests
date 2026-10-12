# Exploration pass 3: org-level, median-based, trimmed; balanced panel.
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
d <- file.path(req, "data")
p <- arrow::read_parquet(file.path(d, "panel_with_geo.parquet")) |>
  filter(!eds_meds) |>
  mutate(pay_per_emp = ifelse(employees > 0 & comp_total > 0, comp_total / employees, NA),
         pay_per_emp = ifelse(pay_per_emp >= 5000 & pay_per_emp <= 400000, pay_per_emp, NA),
         pay_per_emp_real = pay_per_emp * deflator,
         has_staff = !is.na(employees) & employees > 0,
         comp_share = ifelse(exp_total > 0 & !is.na(comp_total), comp_total / exp_total, NA))

focus_metros <- c("Nashville", "Memphis", "Knoxville", "Austin", "Charlotte", "Raleigh",
                  "Indianapolis", "Louisville", "Columbus", "Kansas City", "Jacksonville",
                  "Oklahoma City", "Atlanta", "Denver", "Rest of US")

cat("\n== Median real pay per employee (2023 $), staffed orgs, excl eds/meds ==\n")
med <- p |> filter(has_staff, tax_year %in% c(2015, 2019, 2021, 2023)) |>
  group_by(metro, tax_year) |> summarise(med = median(pay_per_emp_real, na.rm = TRUE), n = sum(!is.na(pay_per_emp_real)), .groups = "drop") |>
  tidyr::pivot_wider(names_from = tax_year, values_from = c(med, n)) |>
  mutate(growth_19_23 = round(100 * (med_2023 / med_2019 - 1), 1)) |>
  arrange(-growth_19_23)
print(med |> mutate(across(starts_with("med"), round)) |> as.data.frame())

cat("\n== Same, human services (HMS) only ==\n")
medh <- p |> filter(has_staff, focus == "HMS", tax_year %in% c(2019, 2023)) |>
  group_by(metro, tax_year) |> summarise(med = median(pay_per_emp_real, na.rm = TRUE), n = sum(!is.na(pay_per_emp_real)), .groups = "drop") |>
  tidyr::pivot_wider(names_from = tax_year, values_from = c(med, n)) |>
  mutate(growth_19_23 = round(100 * (med_2023 / med_2019 - 1), 1)) |> arrange(-med_2023)
print(medh |> mutate(across(starts_with("med"), round)) |> as.data.frame())

cat("\n== Balanced panel: orgs filing full 990 in both 2019 and 2023 ==\n")
bal <- p |> filter(tax_year %in% c(2019, 2023)) |> group_by(ein2) |> filter(n() == 2) |> ungroup() |>
  select(ein2, metro, focus, geo_county_fips, tax_year, employees, comp_total, exp_total, rev_total, deflator, deficit, months_reserve, pay_per_emp_real) |>
  tidyr::pivot_wider(names_from = tax_year, values_from = c(employees, comp_total, exp_total, rev_total, deflator, deficit, months_reserve, pay_per_emp_real)) |>
  mutate(emp_chg = ifelse(employees_2019 > 0 & employees_2023 >= 0, employees_2023 / employees_2019 - 1, NA),
         exp_chg = ifelse(exp_total_2019 > 0, exp_total_2023 * deflator_2023 / (exp_total_2019 * deflator_2019) - 1, NA),
         comp_chg = ifelse(comp_total_2019 > 0, comp_total_2023 * deflator_2023 / (comp_total_2019 * deflator_2019) - 1, NA),
         pay_chg = pay_per_emp_real_2023 / pay_per_emp_real_2019 - 1)
summ <- bal |> group_by(metro) |>
  summarise(n = n(),
            med_emp_chg = round(100 * median(emp_chg, na.rm = TRUE), 1),
            share_cut_staff = round(100 * mean(emp_chg < 0, na.rm = TRUE), 1),
            share_grew_staff = round(100 * mean(emp_chg > 0, na.rm = TRUE), 1),
            med_real_exp_chg = round(100 * median(exp_chg, na.rm = TRUE), 1),
            med_real_comp_chg = round(100 * median(comp_chg, na.rm = TRUE), 1),
            med_real_pay_chg = round(100 * median(pay_chg, na.rm = TRUE), 1),
            agg_emp_chg = round(100 * (sum(employees_2023, na.rm = TRUE) / sum(employees_2019, na.rm = TRUE) - 1), 1),
            deficit_19 = round(100 * mean(deficit_2019, na.rm = TRUE)), deficit_23 = round(100 * mean(deficit_2023, na.rm = TRUE)),
            new_deficit = round(100 * mean(!deficit_2019 & deficit_2023, na.rm = TRUE), 1)) |>
  filter(metro %in% focus_metros) |> arrange(-med_real_pay_chg)
print(as.data.frame(summ))

cat("\n== Nashville balanced panel by subsector ==\n")
print(bal |> filter(metro == "Nashville") |> group_by(focus) |>
  summarise(n = n(), med_emp_chg = round(100 * median(emp_chg, na.rm = TRUE), 1),
            share_cut_staff = round(100 * mean(emp_chg < 0, na.rm = TRUE)),
            med_real_exp_chg = round(100 * median(exp_chg, na.rm = TRUE), 1),
            med_real_pay_chg = round(100 * median(pay_chg, na.rm = TRUE), 1),
            deficit_19 = round(100 * mean(deficit_2019, na.rm = TRUE)), deficit_23 = round(100 * mean(deficit_2023, na.rm = TRUE))) |>
  filter(n >= 20) |> arrange(-n) |> as.data.frame())

cat("\n== Nashville balanced panel: Davidson vs collar ==\n")
print(bal |> filter(metro == "Nashville") |> mutate(where = ifelse(geo_county_fips == "47037", "Davidson", "Collar")) |> group_by(where) |>
  summarise(n = n(), med_emp_chg = round(100 * median(emp_chg, na.rm = TRUE), 1),
            share_cut_staff = round(100 * mean(emp_chg < 0, na.rm = TRUE)),
            med_real_exp_chg = round(100 * median(exp_chg, na.rm = TRUE), 1),
            med_real_pay_chg = round(100 * median(pay_chg, na.rm = TRUE), 1),
            deficit_19 = round(100 * mean(deficit_2019, na.rm = TRUE)), deficit_23 = round(100 * mean(deficit_2023, na.rm = TRUE))) |> as.data.frame())

cat("\n== Nashville: median org size, staffed share, comp share of expenses by year ==\n")
print(p |> filter(metro == "Nashville") |> group_by(tax_year) |>
  summarise(filers = n(), staffed = round(100 * mean(has_staff)), med_emp_staffed = median(employees[has_staff]),
            med_exp_real_k = round(median(exp_total * deflator, na.rm = TRUE) / 1e3),
            med_comp_share = round(100 * median(comp_share, na.rm = TRUE)),
            med_pay_real = round(median(pay_per_emp_real, na.rm = TRUE)),
            med_contrib_share = round(100 * median(contrib_share, na.rm = TRUE)),
            deficit = round(100 * mean(deficit, na.rm = TRUE)), under3mo = round(100 * mean(months_reserve < 3, na.rm = TRUE))) |> as.data.frame())

cat("\n== Rest of US same ==\n")
print(p |> filter(metro == "Rest of US") |> group_by(tax_year) |>
  summarise(filers = n(), staffed = round(100 * mean(has_staff)), med_emp_staffed = median(employees[has_staff]),
            med_exp_real_k = round(median(exp_total * deflator, na.rm = TRUE) / 1e3),
            med_comp_share = round(100 * median(comp_share, na.rm = TRUE)),
            med_pay_real = round(median(pay_per_emp_real, na.rm = TRUE)),
            med_contrib_share = round(100 * median(contrib_share, na.rm = TRUE)),
            deficit = round(100 * mean(deficit, na.rm = TRUE)), under3mo = round(100 * mean(months_reserve < 3, na.rm = TRUE))) |> as.data.frame())
arrow::write_parquet(bal, file.path(d, "balanced_2019_2023.parquet"))
