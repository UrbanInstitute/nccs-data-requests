# Pass 6: national 501(c)(3) benchmark (needs subsection for every EIN),
# robustness of the Nashville headline numbers.
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
source(here::here("R", "request_read.R"))
d <- file.path(req, "data")
nat_path <- file.path(d, "bmf_national_slim.parquet")
if (!file.exists(nat_path)) {
  nat <- read_bmf_master(req, cache = FALSE, columns = c("ein", "subsection_code", "nteev2_subsector", "geo_state_abbr"),
                         note = "national slim read for 501(c)(3) benchmark")
  arrow::write_parquet(nat, nat_path)
}
nat <- arrow::read_parquet(nat_path) |> mutate(ein9 = gsub("-", "", ein)) |> distinct(ein9, .keep_all = TRUE)

p <- arrow::read_parquet(file.path(d, "panel_with_geo.parquet")) |>
  select(-subsection_code, -nteev2_subsector, -focus, -eds_meds) |>
  left_join(nat |> select(ein9, subsection_code, nteev2_subsector, state = geo_state_abbr), by = "ein9") |>
  mutate(focus = ifelse(is.na(nteev2_subsector) | nteev2_subsector == "", "UNU", nteev2_subsector),
         eds_meds = focus %in% c("HOS", "UNI"),
         pay_per_emp = ifelse(employees > 0 & comp_total > 0, comp_total / employees, NA),
         pay_per_emp = ifelse(pay_per_emp >= 5000 & pay_per_emp <= 400000, pay_per_emp, NA),
         pay_per_emp_real = pay_per_emp * deflator) |>
  filter(as.integer(subsection_code) == 3, !eds_meds)
arrow::write_parquet(p, file.path(d, "panel_charities.parquet"))

cat("\n== US (all, incl peer metros) vs Nashville vs Tennessee-outside-Nashville, 501(c)(3) excl HOS/UNI ==\n")
p <- p |> mutate(grp = case_when(metro == "Nashville" ~ "Nashville", state == "TN" ~ "Rest of TN", TRUE ~ "Rest of US"))
yr <- p |> group_by(grp, tax_year) |>
  summarise(filers = n(), employees = sum(employees, na.rm = TRUE), exp_real_m = round(sum(exp_total * deflator, na.rm = TRUE) / 1e6),
            med_pay_real = round(median(pay_per_emp_real, na.rm = TRUE)), med_contrib = round(100 * median(contrib_share, na.rm = TRUE)),
            deficit = round(100 * mean(deficit, na.rm = TRUE)), under3mo = round(100 * mean(months_reserve < 3, na.rm = TRUE)), .groups = "drop")
print(yr |> filter(tax_year >= 2017) |> as.data.frame())

cat("\n== Growth 2019->2023 and 2019->2022 ==\n")
g <- function(y0, y1) yr |> filter(tax_year %in% c(y0, y1)) |> group_by(grp) |>
  summarise(span = paste(y0, y1), filer_g = round(100 * (filers[2] / filers[1] - 1)), emp_g = round(100 * (employees[2] / employees[1] - 1)),
            exp_g = round(100 * (exp_real_m[2] / exp_real_m[1] - 1)), pay_g = round(100 * (med_pay_real[2] / med_pay_real[1] - 1), 1), .groups = "drop")
print(bind_rows(g(2019, 2023), g(2019, 2022)) |> as.data.frame())

cat("\n== Human services only: same ==\n")
yh <- p |> filter(focus == "HMS") |> group_by(grp, tax_year) |>
  summarise(filers = n(), employees = sum(employees, na.rm = TRUE), exp_real_m = round(sum(exp_total * deflator, na.rm = TRUE) / 1e6),
            med_pay_real = round(median(pay_per_emp_real, na.rm = TRUE)), deficit = round(100 * mean(deficit, na.rm = TRUE)),
            under3mo = round(100 * mean(months_reserve < 3, na.rm = TRUE)), .groups = "drop")
print(yh |> filter(tax_year %in% c(2015, 2019, 2021, 2022, 2023)) |> as.data.frame())

cat("\n== Nashville HMS: largest employers 2019 vs 2023 ==\n")
big <- p |> filter(grp == "Nashville", focus == "HMS", tax_year %in% c(2019, 2023)) |> select(org_name, ein2, tax_year, employees, exp_total) |>
  tidyr::pivot_wider(names_from = tax_year, values_from = c(employees, exp_total)) |> arrange(-pmax(employees_2019, employees_2023, na.rm = TRUE)) |> head(12)
print(as.data.frame(big))

cat("\n== Nashville HMS employees change excluding top 5 employers of 2019 ==\n")
top5 <- big$ein2[1:5]
print(p |> filter(grp == "Nashville", focus == "HMS", tax_year %in% c(2019, 2023)) |> group_by(tax_year, top = ein2 %in% top5) |>
  summarise(n = n(), employees = sum(employees, na.rm = TRUE), .groups = "drop") |> as.data.frame())

cat("\n== Balanced 2019-2023 within-org: Nashville vs Rest of US, by focus (charities) ==\n")
bal <- p |> filter(tax_year %in% c(2019, 2023)) |> group_by(ein2) |> filter(n() == 2) |> ungroup() |>
  select(ein2, grp, focus, tax_year, employees, exp_total, deflator, deficit, months_reserve, pay_per_emp_real) |>
  tidyr::pivot_wider(names_from = tax_year, values_from = c(employees, exp_total, deflator, deficit, months_reserve, pay_per_emp_real)) |>
  mutate(emp_chg = ifelse(employees_2019 > 0, employees_2023 / employees_2019 - 1, NA),
         exp_chg = ifelse(exp_total_2019 > 0, exp_total_2023 * deflator_2023 / (exp_total_2019 * deflator_2019) - 1, NA),
         pay_chg = pay_per_emp_real_2023 / pay_per_emp_real_2019 - 1)
s <- function(df) df |> summarise(n = n(), med_emp_chg = round(100 * median(emp_chg, na.rm = TRUE), 1), cut_staff = round(100 * mean(emp_chg < 0, na.rm = TRUE)),
            med_exp_chg = round(100 * median(exp_chg, na.rm = TRUE), 1), med_pay_chg = round(100 * median(pay_chg, na.rm = TRUE), 1), pay_up = round(100 * mean(pay_chg > 0, na.rm = TRUE)),
            deficit_19 = round(100 * mean(deficit_2019, na.rm = TRUE)), deficit_23 = round(100 * mean(deficit_2023, na.rm = TRUE)),
            med_res_19 = round(median(months_reserve_2019, na.rm = TRUE), 1), med_res_23 = round(median(months_reserve_2023, na.rm = TRUE), 1), .groups = "drop")
print(bal |> group_by(grp) |> s() |> as.data.frame())
print(bal |> filter(focus == "HMS") |> group_by(grp) |> s() |> as.data.frame())
