library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
d <- file.path(req, "data")
p <- arrow::read_parquet(file.path(d, "panel_with_geo.parquet")) |> filter(metro == "Nashville") |>
  mutate(where = ifelse(geo_county_fips == "47037", "Davidson", "Collar"),
         pay_per_emp = ifelse(employees > 0 & comp_total > 0, comp_total / employees, NA),
         pay_per_emp = ifelse(pay_per_emp >= 5000 & pay_per_emp <= 400000, pay_per_emp, NA),
         pay_per_emp_real = pay_per_emp * deflator)
bal <- arrow::read_parquet(file.path(d, "balanced_2019_2023.parquet"))

cat("\n== Davidson share of metro (excl eds/meds): filers, employees, real expenses, comp by year ==\n")
print(p |> filter(!eds_meds) |> group_by(tax_year) |>
  summarise(filers_dav = round(100 * mean(where == "Davidson")),
            emp_dav = round(100 * sum(employees[where == "Davidson"], na.rm = TRUE) / sum(employees, na.rm = TRUE)),
            exp_dav = round(100 * sum(exp_total[where == "Davidson"], na.rm = TRUE) / sum(exp_total, na.rm = TRUE)),
            comp_dav = round(100 * sum(comp_total[where == "Davidson"], na.rm = TRUE) / sum(comp_total, na.rm = TRUE)),
            exp_collar_real_m = round(sum(exp_total[where == "Collar"] * deflator[where == "Collar"], na.rm = TRUE) / 1e6),
            exp_dav_real_m = round(sum(exp_total[where == "Davidson"] * deflator[where == "Davidson"], na.rm = TRUE) / 1e6)) |> as.data.frame())

cat("\n== Top 12 collar-county orgs by 2023 expenses (excl eds/meds) ==\n")
print(p |> filter(!eds_meds, where == "Collar", tax_year == 2023) |> arrange(-exp_total) |>
  transmute(org_name, county = geo_county_fips, focus, exp_m = round(exp_total / 1e6), employees) |> head(12) |> as.data.frame())
cat("\n== Same orgs in 2019? top 12 by 2019 expenses ==\n")
print(p |> filter(!eds_meds, where == "Collar", tax_year == 2019) |> arrange(-exp_total) |>
  transmute(org_name, county = geo_county_fips, focus, exp_m = round(exp_total / 1e6), employees) |> head(12) |> as.data.frame())

cat("\n== Collar real expense growth 2019-2023 with and without the top 5 2023 orgs ==\n")
top5 <- p |> filter(!eds_meds, where == "Collar", tax_year == 2023) |> arrange(-exp_total) |> head(5) |> pull(ein2)
print(p |> filter(!eds_meds, where == "Collar", tax_year %in% c(2019, 2023)) |>
  group_by(tax_year, in_top5 = ein2 %in% top5) |> summarise(exp_real_m = round(sum(exp_total * deflator, na.rm = TRUE) / 1e6), n = n(), .groups = "drop") |> as.data.frame())

cat("\n== HMS balanced-panel per-org real pay change by metro (median, IQR, n) ==\n")
print(bal |> filter(focus == "HMS", !is.na(pay_chg)) |> group_by(metro) |>
  summarise(n = n(), med = round(100 * median(pay_chg), 1), q25 = round(100 * quantile(pay_chg, .25), 1), q75 = round(100 * quantile(pay_chg, .75), 1),
            share_up = round(100 * mean(pay_chg > 0))) |> filter(n >= 60) |> arrange(-med) |> as.data.frame())

cat("\n== All-sector balanced-panel per-org real pay change by metro ==\n")
print(bal |> filter(!is.na(pay_chg)) |> group_by(metro) |>
  summarise(n = n(), med = round(100 * median(pay_chg), 1), share_up = round(100 * mean(pay_chg > 0))) |> filter(n >= 200) |> arrange(-med) |> as.data.frame())

cat("\n== Nashville HMS: pay by year, staffed orgs ==\n")
print(p |> filter(focus == "HMS", employees > 0) |> group_by(tax_year) |>
  summarise(n = n(), med_pay_real = round(median(pay_per_emp_real, na.rm = TRUE)), med_pay_nominal = round(median(pay_per_emp, na.rm = TRUE)),
            employees = sum(employees), deficit = round(100 * mean(deficit, na.rm = TRUE)), under3mo = round(100 * mean(months_reserve < 3, na.rm = TRUE))) |> as.data.frame())

cat("\n== Nashville HMS by county 2023 ==\n")
print(p |> filter(focus == "HMS", tax_year == 2023) |> group_by(geo_county_fips) |>
  summarise(n = n(), employees = sum(employees, na.rm = TRUE), exp_m = round(sum(exp_total, na.rm = TRUE) / 1e6), med_pay = round(median(pay_per_emp, na.rm = TRUE))) |> arrange(-n) |> as.data.frame())
