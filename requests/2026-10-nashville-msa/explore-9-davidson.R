# Pass 9: Davidson County (Metro Nashville) alone, benchmarked against the
# principal central county of each peer metro.
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
d <- file.path(req, "data")
tn <- arrow::read_parquet(file.path(d, "universe_tn.parquet"))
peers <- arrow::read_parquet(file.path(d, "universe_peers.parquet"))
p <- arrow::read_parquet(file.path(d, "panel_charities.parquet"))
gg <- arrow::read_parquet(file.path(d, "government_grants.parquet")) |> filter(form_type == "990") |>
  arrange(desc(filing_receipt_id)) |> distinct(ein, tax_year, .keep_all = TRUE) |> transmute(ein9 = ein, tax_year, govt_grants = government_grants)

# Principal county per peer metro: the county with the most registered orgs.
principal <- peers |> filter(last_year_in_bmf >= 2026) |> count(metro, geo_county_fips, county_name) |> group_by(metro) |> slice_max(n, n = 1) |> ungroup()
cat("== Principal counties ==\n"); print(as.data.frame(principal |> select(metro, county_name)))

cat("\n== Satellite cities inside Davidson (geocoded city), active 2026 501(c)(3) ==\n")
print(tn |> filter(geo_county_fips == "47037", last_year_in_bmf >= 2026, as.integer(subsection_code) == 3) |> count(geo_city, sort = TRUE) |> head(8) |> as.data.frame())

pc <- p |> inner_join(principal |> select(metro, geo_county_fips), by = c("metro", "geo_county_fips")) |>
  left_join(gg, by = c("ein9", "tax_year")) |> mutate(gg0 = coalesce(govt_grants, 0), gg_share = ifelse(rev_total > 0, pmin(gg0 / rev_total, 1), NA))
us <- p |> filter(metro == "Rest of US") |> left_join(gg, by = c("ein9", "tax_year")) |> mutate(gg0 = coalesce(govt_grants, 0), gg_share = ifelse(rev_total > 0, pmin(gg0 / rev_total, 1), NA), metro = "Rest of US")

tab <- bind_rows(pc, us) |> filter(tax_year %in% c(2019, 2023)) |> group_by(metro, tax_year) |>
  summarise(filers = n(), employees = sum(employees, na.rm = TRUE), exp_real_m = sum(exp_total * deflator, na.rm = TRUE) / 1e6,
            med_pay = median(pay_per_emp_real, na.rm = TRUE), deficit = mean(deficit, na.rm = TRUE), under3mo = mean(months_reserve < 3, na.rm = TRUE),
            gg_share_agg = sum(gg0) / sum(rev_total, na.rm = TRUE), any_gg = mean(gg0 > 0), med_contrib = median(contrib_share, na.rm = TRUE), .groups = "drop")
cat("\n== Central counties, 501(c)(3) excl HOS/UNI: 2019 -> 2023 and 2023 levels ==\n")
print(tab |> group_by(metro) |> summarise(filers_23 = filers[2], filer_g = round(100 * (filers[2] / filers[1] - 1)), emp_g = round(100 * (employees[2] / employees[1] - 1)),
  exp_g = round(100 * (exp_real_m[2] / exp_real_m[1] - 1)), pay_g = round(100 * (med_pay[2] / med_pay[1] - 1), 1), med_pay_23 = round(med_pay[2]),
  deficit_23 = round(100 * deficit[2]), under3mo_23 = round(100 * under3mo[2]), gov_share_23 = round(100 * gg_share_agg[2], 1), any_gov_23 = round(100 * any_gg[2]), contrib_23 = round(100 * med_contrib[2])) |>
  arrange(-pay_g) |> as.data.frame())

cat("\n== Central counties, human services only, 2023 ==\n")
print(bind_rows(pc, us) |> filter(tax_year == 2023, focus == "HMS") |> group_by(metro) |>
  summarise(filers = n(), employees = sum(employees, na.rm = TRUE), med_pay = round(median(pay_per_emp_real, na.rm = TRUE)), deficit = round(100 * mean(deficit, na.rm = TRUE)),
            gov_share = round(100 * sum(gg0) / sum(rev_total, na.rm = TRUE), 1), any_gov = round(100 * mean(gg0 > 0))) |> arrange(-gov_share) |> as.data.frame())

cat("\n== Davidson by year (charities excl HOS/UNI) ==\n")
print(p |> filter(metro == "Nashville", geo_county_fips == "47037") |> left_join(gg, by = c("ein9", "tax_year")) |> mutate(gg0 = coalesce(govt_grants, 0)) |> group_by(tax_year) |>
  summarise(filers = n(), employees = sum(employees, na.rm = TRUE), exp_real_m = round(sum(exp_total * deflator, na.rm = TRUE) / 1e6), med_pay = round(median(pay_per_emp_real, na.rm = TRUE)),
            deficit = round(100 * mean(deficit, na.rm = TRUE)), under3mo = round(100 * mean(months_reserve < 3, na.rm = TRUE)),
            gov_share = round(100 * sum(gg0) / sum(rev_total, na.rm = TRUE), 1)) |> mutate(gov_share = ifelse(tax_year >= 2020, gov_share, NA)) |> as.data.frame())

cat("\n== Davidson exit cohort pay vs stayers (2019 staffed charities) ==\n")
in23 <- p |> filter(tax_year == 2023) |> pull(ein2)
print(p |> filter(tax_year == 2019, employees > 0, geo_county_fips == "47037", metro == "Nashville") |> mutate(exited = !(ein2 %in% in23)) |> group_by(exited) |>
  summarise(n = n(), med_pay_2019 = round(median(pay_per_emp_real, na.rm = TRUE))) |> as.data.frame())
