# Exploration pass 2: Form 990 finances and workforce, Nashville vs peers vs US.
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
d <- file.path(req, "data")
panel <- arrow::read_parquet(file.path(d, "panel_990_national.parquet"))
peers <- arrow::read_parquet(file.path(d, "universe_peers.parquet")) |>
  select(ein9, metro, cbsa_code, geo_county_fips, subsection_code, nteev2_subsector, ruling_date) |>
  distinct(ein9, .keep_all = TRUE)
cpi <- read.csv(file.path(d, "cpi.csv"))
base_cpi <- cpi$cpi[cpi$year == 2023]

p <- panel |>
  left_join(peers, by = "ein9") |>
  mutate(metro = ifelse(is.na(metro), "Rest of US", metro),
         focus = ifelse(is.na(nteev2_subsector) | nteev2_subsector == "", "UNU", nteev2_subsector),
         eds_meds = focus %in% c("HOS", "UNI"),
         comp_total = rowSums(cbind(comp_officers, comp_disqualified, comp_other_salaries,
                                    comp_pension, comp_benefits, comp_payroll_tax), na.rm = TRUE),
         comp_total = ifelse(is.na(comp_other_salaries) & is.na(comp_officers), NA, comp_total),
         deflator = base_cpi / cpi$cpi[match(tax_year, cpi$year)],
         deficit = exp_total > rev_total,
         months_reserve = ifelse(exp_total > 0, 12 * net_assets_eoy / exp_total, NA),
         contrib_share = ifelse(rev_total > 0, rev_contributions / rev_total, NA))

metro_year <- function(df) df |>
  group_by(metro, tax_year) |>
  summarise(filers = n(),
            employees = sum(employees, na.rm = TRUE),
            comp_real_m = sum(comp_total * deflator, na.rm = TRUE) / 1e6,
            exp_real_m = sum(exp_total * deflator, na.rm = TRUE) / 1e6,
            rev_real_m = sum(rev_total * deflator, na.rm = TRUE) / 1e6,
            pay_per_emp_real = sum(comp_total * deflator, na.rm = TRUE) /
                               sum(employees[!is.na(comp_total)], na.rm = TRUE),
            exp_gt_rev_share = mean(deficit, na.rm = TRUE),
            med_months_reserve = median(months_reserve, na.rm = TRUE),
            under_3mo = mean(months_reserve < 3, na.rm = TRUE),
            contrib_share_agg = sum(rev_contributions, na.rm = TRUE) / sum(rev_total, na.rm = TRUE),
            .groups = "drop")

cat("\n== Nashville MSA, all full-990 filers, by year ==\n")
print(metro_year(p |> filter(metro == "Nashville")) |> mutate(across(where(is.numeric), ~ round(.x, 2))) |> as.data.frame())

cat("\n== Nashville MSA excluding hospitals and universities ==\n")
print(metro_year(p |> filter(metro == "Nashville", !eds_meds)) |> mutate(across(where(is.numeric), ~ round(.x, 2))) |> as.data.frame())

cat("\n== Peer comparison, 2019 -> 2023 changes, excluding hospitals/universities ==\n")
my <- metro_year(p |> filter(!eds_meds))
cmp <- my |> filter(tax_year %in% c(2019, 2023)) |>
  group_by(metro) |>
  summarise(filers_23 = filers[tax_year == 2023],
            emp_growth = 100 * (employees[tax_year == 2023] / employees[tax_year == 2019] - 1),
            real_comp_growth = 100 * (comp_real_m[tax_year == 2023] / comp_real_m[tax_year == 2019] - 1),
            real_pay_per_emp_growth = 100 * (pay_per_emp_real[tax_year == 2023] / pay_per_emp_real[tax_year == 2019] - 1),
            pay_per_emp_23 = pay_per_emp_real[tax_year == 2023],
            real_exp_growth = 100 * (exp_real_m[tax_year == 2023] / exp_real_m[tax_year == 2019] - 1),
            deficit_23 = 100 * exp_gt_rev_share[tax_year == 2023],
            deficit_19 = 100 * exp_gt_rev_share[tax_year == 2019],
            under3mo_23 = 100 * under_3mo[tax_year == 2023],
            med_reserve_23 = med_months_reserve[tax_year == 2023],
            contrib_share_23 = 100 * contrib_share_agg[tax_year == 2023]) |>
  mutate(across(where(is.numeric), ~ round(.x, 1))) |> arrange(-real_pay_per_emp_growth)
print(as.data.frame(cmp))

cat("\n== Nashville 2023 by subsector (excl none) ==\n")
print(p |> filter(metro == "Nashville", tax_year == 2023) |> group_by(focus) |>
  summarise(filers = n(), employees = sum(employees, na.rm = TRUE),
            comp_m = sum(comp_total, na.rm = TRUE) / 1e6,
            exp_m = sum(exp_total, na.rm = TRUE) / 1e6,
            pay_per_emp = round(sum(comp_total, na.rm = TRUE) / sum(employees[!is.na(comp_total)], na.rm = TRUE)),
            deficit = round(100 * mean(deficit, na.rm = TRUE)),
            under3mo = round(100 * mean(months_reserve < 3, na.rm = TRUE))) |>
  arrange(-exp_m) |> mutate(across(where(is.numeric), ~ round(.x, 1))) |> as.data.frame())

cat("\n== Nashville: Davidson vs collar, excl eds/meds, 2019 vs 2023 ==\n")
print(p |> filter(metro == "Nashville", !eds_meds, tax_year %in% c(2017, 2019, 2021, 2023)) |>
  mutate(where = ifelse(geo_county_fips == "47037", "Davidson", "Collar")) |>
  group_by(where, tax_year) |>
  summarise(filers = n(), employees = sum(employees, na.rm = TRUE),
            exp_real_m = round(sum(exp_total * deflator, na.rm = TRUE) / 1e6),
            comp_real_m = round(sum(comp_total * deflator, na.rm = TRUE) / 1e6),
            deficit = round(100 * mean(deficit, na.rm = TRUE)),
            under3mo = round(100 * mean(months_reserve < 3, na.rm = TRUE)), .groups = "drop") |> as.data.frame())

arrow::write_parquet(p, file.path(d, "panel_with_geo.parquet"))
