# Pass 6: national 501(c)(3) benchmark (needs subsection for every EIN),
# robustness of the Nashville headline numbers.
#
# Comparison groups: a mutually exclusive partition of every full-990 filer
# (REVIEW.md finding 6 and RESPONSE-REVIEW.md item 1). Set here, carried in
# panel_charities.parquet as `grp`, and never redefined downstream.
#   Nashville    = CBSA 34980
#   Peer metros  = all 19 other benchmark metros, including Memphis and Knoxville
#   Rest of TN   = Tennessee outside the 20 metros
#   Rest of US   = everything else
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
source(here::here("R", "request_read.R"))
d <- file.path(req, "data")
# Re-read on every run (no cache) so the pin always describes the file used.
bmf_manifest <- jsonlite::fromJSON("https://nccsdata.s3.amazonaws.com/geocoding/unified-bmf/latest/_manifest.json")
bmf_identity <- sprintf("vintage %s, git %s, sha256 %s", bmf_manifest$vintage, bmf_manifest$git_sha,
                        bmf_manifest$files$bmf_unified_geocoded.parquet$sha256)
nat <- read_bmf_master(req, cache = FALSE, columns = c("ein", "subsection_code", "foundation_code", "nteev2_subsector", "geo_state_abbr"),
                       note = paste("national slim read for 501(c)(3) benchmark;", bmf_identity))
arrow::write_parquet(nat, file.path(d, "bmf_national_slim.parquet"))
nat <- nat |> mutate(ein9 = gsub("-", "", ein)) |> distinct(ein9, .keep_all = TRUE)

raw <- arrow::read_parquet(file.path(d, "panel_with_geo.parquet")) |>
  select(-subsection_code, -nteev2_subsector, -focus, -eds_meds) |>
  left_join(nat |> select(ein9, subsection_code, foundation_code, nteev2_subsector, state = geo_state_abbr), by = "ein9")

cat("== Full-990 rows with no BMF match (dropped by the subsection filter) ==\n")
print(raw |> group_by(tax_year) |> summarise(rows = n(), no_bmf_match = sum(is.na(subsection_code))) |> filter(tax_year %in% c(2019, 2023)) |> as.data.frame())

p <- raw |>
  mutate(focus = ifelse(is.na(nteev2_subsector) | nteev2_subsector == "", "UNU", nteev2_subsector),
         eds_meds = focus %in% c("HOS", "UNI"),
         pay_per_emp = ifelse(employees > 0 & comp_total > 0, comp_total / employees, NA),
         pay_per_emp = ifelse(pay_per_emp >= 5000 & pay_per_emp <= 400000, pay_per_emp, NA),
         pay_per_emp_real = pay_per_emp * deflator,
         grp = case_when(metro == "Nashville" ~ "Nashville",
                         metro != "Rest of US" ~ "Peer metros",
                         state == "TN" ~ "Rest of TN",
                         TRUE ~ "Rest of US")) |>
  filter(as.integer(subsection_code) == 3, !eds_meds)

cat("\n== Current BMF foundation code among full-990 filers kept (should be public-charity codes) ==\n")
print(p |> filter(tax_year == 2023) |> count(grp, foundation_code) |> tidyr::pivot_wider(names_from = grp, values_from = n) |> as.data.frame())
cat("Nashville 2023 full-990 filers with private-foundation code (02-04):\n")
print(p |> filter(tax_year == 2023, grp == "Nashville", as.integer(foundation_code) %in% 2:4) |> select(org_name, foundation_code, rev_total) |> as.data.frame())

arrow::write_parquet(p, file.path(d, "panel_charities.parquet"))

cat("\n== By group and year, 501(c)(3) excl HOS/UNI ==\n")
yr <- p |> group_by(grp, tax_year) |>
  summarise(filers = n(), employees = sum(employees, na.rm = TRUE), exp_real_m = round(sum(exp_total * deflator, na.rm = TRUE) / 1e6),
            med_pay_real = round(median(pay_per_emp_real, na.rm = TRUE)), n_pay = sum(!is.na(pay_per_emp_real)),
            med_contrib = round(100 * median(contrib_share, na.rm = TRUE)),
            exp_gt_rev = round(100 * mean(deficit, na.rm = TRUE)), under3mo = round(100 * mean(months_reserve < 3, na.rm = TRUE)), .groups = "drop")
print(yr |> filter(tax_year >= 2017) |> as.data.frame())

cat("\n== Growth 2019->2023 and 2019->2022 ==\n")
g <- function(y0, y1) yr |> filter(tax_year %in% c(y0, y1)) |> group_by(grp) |>
  summarise(span = paste(y0, y1), filer_g = round(100 * (filers[2] / filers[1] - 1)), emp_g = round(100 * (employees[2] / employees[1] - 1), 1),
            exp_g = round(100 * (exp_real_m[2] / exp_real_m[1] - 1)), pay_g = round(100 * (med_pay_real[2] / med_pay_real[1] - 1), 1), .groups = "drop")
print(bind_rows(g(2019, 2023), g(2019, 2022)) |> as.data.frame())

cat("\n== Human services only ==\n")
yh <- p |> filter(focus == "HMS") |> group_by(grp, tax_year) |>
  summarise(filers = n(), employees = sum(employees, na.rm = TRUE), exp_real_m = round(sum(exp_total * deflator, na.rm = TRUE) / 1e6),
            med_pay_real = round(median(pay_per_emp_real, na.rm = TRUE)), n_pay = sum(!is.na(pay_per_emp_real)),
            exp_gt_rev = round(100 * mean(deficit, na.rm = TRUE)), under3mo = round(100 * mean(months_reserve < 3, na.rm = TRUE)), .groups = "drop")
print(yh |> filter(tax_year %in% c(2015, 2019, 2021, 2022, 2023)) |> as.data.frame())

cat("\n== Nashville HMS: five largest 2019 employers (by EIN), 2019 vs 2023 ==\n")
wide <- p |> filter(grp == "Nashville", focus == "HMS", tax_year %in% c(2019, 2023)) |>
  select(ein2, tax_year, employees, exp_total) |>
  tidyr::pivot_wider(names_from = tax_year, values_from = c(employees, exp_total))
names_2023 <- p |> filter(tax_year == 2023) |> distinct(ein2, org_name)
top5 <- wide |> arrange(-employees_2019) |> head(5)
print(top5 |> left_join(names_2023, by = "ein2") |> select(org_name, ein2, employees_2019, employees_2023) |> as.data.frame())
print(p |> filter(grp == "Nashville", focus == "HMS", tax_year %in% c(2019, 2023)) |> group_by(tax_year, top5 = ein2 %in% top5$ein2) |>
  summarise(n = n(), employees = sum(employees, na.rm = TRUE), .groups = "drop") |> as.data.frame())

cat("\n== Balanced 2019-2023 within-org, by group and for human services ==\n")
bal <- p |> filter(tax_year %in% c(2019, 2023)) |> group_by(ein2) |> filter(n() == 2) |> ungroup() |>
  select(ein2, grp, focus, geo_county_fips, tax_year, employees, exp_total, deflator, deficit, months_reserve, pay_per_emp_real) |>
  tidyr::pivot_wider(names_from = tax_year, values_from = c(employees, exp_total, deflator, deficit, months_reserve, pay_per_emp_real)) |>
  mutate(emp_chg = ifelse(employees_2019 > 0, employees_2023 / employees_2019 - 1, NA),
         exp_chg = ifelse(exp_total_2019 > 0, exp_total_2023 * deflator_2023 / (exp_total_2019 * deflator_2019) - 1, NA),
         pay_chg = pay_per_emp_real_2023 / pay_per_emp_real_2019 - 1)
s <- function(df) df |> summarise(n = n(), med_emp_chg = round(100 * median(emp_chg, na.rm = TRUE), 1), cut_staff = round(100 * mean(emp_chg < 0, na.rm = TRUE)),
            med_exp_chg = round(100 * median(exp_chg, na.rm = TRUE), 1), n_pay = sum(!is.na(pay_chg)), med_pay_chg = round(100 * median(pay_chg, na.rm = TRUE), 1),
            exp_gt_rev_19 = round(100 * mean(deficit_2019, na.rm = TRUE)), exp_gt_rev_23 = round(100 * mean(deficit_2023, na.rm = TRUE)),
            med_na_months_19 = round(median(months_reserve_2019, na.rm = TRUE), 1), med_na_months_23 = round(median(months_reserve_2023, na.rm = TRUE), 1), .groups = "drop")
print(bal |> group_by(grp) |> s() |> as.data.frame())
print(bal |> filter(focus == "HMS") |> group_by(grp) |> s() |> as.data.frame())
arrow::write_parquet(bal, file.path(d, "balanced_charities_2019_2023.parquet"))

cat("\n== Exit and entrant cohorts: metro and Davidson, with bootstrap intervals on the median gap ==\n")
in19 <- p |> filter(tax_year == 2019) |> pull(ein2)
in23 <- p |> filter(tax_year == 2023) |> pull(ein2)
boot_gap <- function(a, b, reps = 2000) {
  set.seed(20261012)
  gaps <- replicate(reps, median(sample(a, replace = TRUE)) - median(sample(b, replace = TRUE)))
  round(quantile(gaps, c(0.025, 0.975)))
}
exit_tab <- function(df, label) {
  x <- df |> filter(tax_year == 2019, employees > 0) |> mutate(exited = !(ein2 %in% in23))
  a <- x$pay_per_emp_real[x$exited & !is.na(x$pay_per_emp_real)]
  b <- x$pay_per_emp_real[!x$exited & !is.na(x$pay_per_emp_real)]
  ci <- boot_gap(a, b)
  data.frame(group = label, n_exit = sum(x$exited), n_exit_with_pay = length(a), n_stay = sum(!x$exited), n_stay_with_pay = length(b),
             med_pay_exit = round(median(a)), med_pay_stay = round(median(b)), gap = round(median(a) - median(b)), ci_low = ci[1], ci_high = ci[2])
}
print(bind_rows(exit_tab(p |> filter(grp == "Nashville"), "Nashville metro"),
                exit_tab(p |> filter(grp == "Nashville", geo_county_fips == "47037"), "Davidson"),
                exit_tab(p |> filter(grp == "Peer metros"), "Peer metros"),
                exit_tab(p |> filter(grp == "Rest of US"), "Rest of US")), row.names = FALSE)
print(p |> filter(tax_year == 2023, employees > 0) |> mutate(entrant = !(ein2 %in% in19)) |> group_by(grp, entrant) |>
  summarise(n = n(), med_pay = round(median(pay_per_emp_real, na.rm = TRUE)), med_emp = median(employees), .groups = "drop") |> as.data.frame())
