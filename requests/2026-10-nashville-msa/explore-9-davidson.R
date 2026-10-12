# Pass 9: Davidson County (Metro Nashville) alone, benchmarked against one
# county per peer metro.
#
# Peer county = the county in each peer metro with the most registered
# organizations in 2026. This is an analyst choice, not a definition of the
# central city: it picks St. Louis County (not St. Louis city) and Henrico
# (not Richmond city). Rankings below are rankings among these counties.
#
# Also: 2019-2022 sensitivity for every ranking (REVIEW.md finding 2), the
# QCEW benchmark in 2023 dollars (finding 9), and human services line 1e by
# county (finding 3).
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
d <- file.path(req, "data")
tn <- arrow::read_parquet(file.path(d, "universe_tn.parquet"))
peers <- arrow::read_parquet(file.path(d, "universe_peers.parquet"))
p <- arrow::read_parquet(file.path(d, "panel_charities.parquet"))
cpi <- read.csv(file.path(d, "cpi.csv"))
gg <- arrow::read_parquet(file.path(d, "government_grants.parquet")) |> filter(form_type == "990") |>
  arrange(desc(filing_receipt_id)) |> distinct(ein, tax_year, .keep_all = TRUE) |> transmute(ein9 = ein, tax_year, govt_grants = government_grants)

principal <- peers |> filter(last_year_in_bmf >= 2026) |> count(metro, geo_county_fips, county_name) |> group_by(metro) |> slice_max(n, n = 1) |> ungroup()
cat("== Peer counties (most registered organizations in each metro) ==\n"); print(as.data.frame(principal |> select(metro, county_name)))

cat("\n== Satellite cities inside Davidson (geocoded city), active 2026 501(c)(3) ==\n")
print(tn |> filter(geo_county_fips == "47037", last_year_in_bmf >= 2026, as.integer(subsection_code) == 3) |> count(geo_city, sort = TRUE) |> head(8) |> as.data.frame())

pc <- p |> inner_join(principal |> select(metro, geo_county_fips), by = c("metro", "geo_county_fips"))
us <- p |> filter(grp == "Rest of US")
both <- bind_rows(pc, us) |> left_join(gg, by = c("ein9", "tax_year")) |>
  mutate(gg0 = coalesce(govt_grants, 0), gg_share = ifelse(rev_total > 0, gg0 / rev_total, NA))

level <- function(df, years) df |> filter(tax_year %in% years) |> group_by(metro, tax_year) |>
  summarise(filers = n(), employees = sum(employees, na.rm = TRUE), exp_real_m = sum(exp_total * deflator, na.rm = TRUE) / 1e6,
            med_pay = median(pay_per_emp_real, na.rm = TRUE), n_pay = sum(!is.na(pay_per_emp_real)),
            exp_gt_rev = mean(deficit, na.rm = TRUE), under3mo = mean(months_reserve < 3, na.rm = TRUE),
            gg_share_agg = sum(gg0) / sum(rev_total, na.rm = TRUE), any_gg = mean(gg0 > 0), med_contrib = median(contrib_share, na.rm = TRUE), .groups = "drop")
growth <- function(y1) {
  tab <- level(both, c(2019, y1))
  tab |> group_by(metro) |> summarise(span = paste("2019", y1), filers_end = filers[2], filer_g = round(100 * (filers[2] / filers[1] - 1)),
    emp_g = round(100 * (employees[2] / employees[1] - 1), 1), exp_g = round(100 * (exp_real_m[2] / exp_real_m[1] - 1)),
    pay_g = round(100 * (med_pay[2] / med_pay[1] - 1), 1), n_pay_end = n_pay[2], med_pay_end = round(med_pay[2]), .groups = "drop") |>
    arrange(-pay_g) |> mutate(pay_rank_of_20 = ifelse(metro == "Rest of US", NA, cumsum(metro != "Rest of US")))
}
cat("\n== Peer counties, 501(c)(3) excl HOS/UNI: growth 2019 -> 2023 ==\n"); print(as.data.frame(growth(2023)))
cat("\n== Same, 2019 -> 2022 (sensitivity to the incomplete TY2023) ==\n"); print(as.data.frame(growth(2022)))

cat("\n== Peer counties 2023 levels ==\n")
print(level(both, 2023) |> transmute(metro, filers, med_pay = round(med_pay), n_pay, exp_gt_rev = round(100 * exp_gt_rev), under3mo = round(100 * under3mo),
  line1e_share = round(100 * gg_share_agg, 1), any_line1e = round(100 * any_gg), med_contrib = round(100 * med_contrib)) |> arrange(-med_pay) |> as.data.frame())

cat("\n== Peer counties, human services only, 2023 (ranked on line 1e share; Rest of US shown but not ranked) ==\n")
h <- both |> filter(tax_year == 2023, focus == "HMS") |> group_by(metro) |>
  summarise(filers = n(), employees = sum(employees, na.rm = TRUE), med_pay = round(median(pay_per_emp_real, na.rm = TRUE)), exp_gt_rev = round(100 * mean(deficit, na.rm = TRUE)),
            line1e_share = round(100 * sum(gg0) / sum(rev_total, na.rm = TRUE), 1), any_line1e = round(100 * mean(gg0 > 0))) |> arrange(-line1e_share) |>
  mutate(rank_of_20 = ifelse(metro == "Rest of US", NA, cumsum(metro != "Rest of US")))
print(as.data.frame(h))

cat("\n== Davidson by year (charities excl HOS/UNI) ==\n")
print(p |> filter(metro == "Nashville", geo_county_fips == "47037") |> left_join(gg, by = c("ein9", "tax_year")) |> mutate(gg0 = coalesce(govt_grants, 0)) |> group_by(tax_year) |>
  summarise(filers = n(), employees = sum(employees, na.rm = TRUE), exp_real_m = round(sum(exp_total * deflator, na.rm = TRUE) / 1e6), med_pay = round(median(pay_per_emp_real, na.rm = TRUE)), n_pay = sum(!is.na(pay_per_emp_real)),
            exp_gt_rev = round(100 * mean(deficit, na.rm = TRUE)), under3mo = round(100 * mean(months_reserve < 3, na.rm = TRUE)),
            line1e_share = round(100 * sum(gg0) / sum(rev_total, na.rm = TRUE), 1)) |> mutate(line1e_share = ifelse(tax_year >= 2020, line1e_share, NA)) |> as.data.frame())

cat("\n== Nashville human services line 1e share by county, 2023 ==\n")
print(p |> filter(metro == "Nashville", tax_year == 2023, focus == "HMS") |> left_join(gg, by = c("ein9", "tax_year")) |> mutate(gg0 = coalesce(govt_grants, 0)) |>
  group_by(geo_county_fips) |> summarise(filers = n(), line1e_share = round(100 * sum(gg0) / sum(rev_total, na.rm = TRUE), 1), any_line1e = round(100 * mean(gg0 > 0))) |> arrange(-filers) |> as.data.frame())

cat("\n== QCEW private-sector benchmark, Davidson, in 2023 dollars ==\n")
q <- read.csv(file.path(req, "output", "qcew_private_pay_benchmarks.csv"), colClasses = c(county_fips = "character", naics = "character"))
deflate <- cpi$cpi[cpi$year == 2023] / cpi$cpi[match(q$year, cpi$year)]
q <- q |> mutate(avg_annual_pay_2023usd = round(avg_annual_pay * deflate))
print(q |> filter(county_fips == "47037") |> select(naics, year, annual_avg_employment, avg_annual_pay, avg_annual_pay_2023usd) |>
  tidyr::pivot_wider(names_from = year, values_from = c(annual_avg_employment, avg_annual_pay, avg_annual_pay_2023usd)) |>
  mutate(real_growth = round(100 * (avg_annual_pay_2023usd_2023 / avg_annual_pay_2023usd_2019 - 1), 1)) |> as.data.frame())
cat("Nonprofit comparison (metro HMS median pay per head, 2023 $): see explore-6 'Human services only' med_pay_real 2019 vs 2023\n")
