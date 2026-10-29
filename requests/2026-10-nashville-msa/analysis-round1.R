

# =============================================================================
# Pass 1-universe (formerly explore-1-universe.R)
# =============================================================================

# Exploration pass 1: the Nashville metro registered universe (BMF).
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
u <- arrow::read_parquet(file.path(req, "data", "universe_tn.parquet"))

nash <- u |> filter(cbsa_code == "34980") |>
  mutate(county = sub(" County", "", county_name),
         davidson = geo_county_fips == "47037",
         focus = ifelse(is.na(nteev2_subsector) | nteev2_subsector == "", "UNU", nteev2_subsector))

cat("\n== Nashville MSA orgs by county, active in selected years ==\n")
active_by <- function(y) nash |> filter(first_year_in_bmf <= y, last_year_in_bmf >= y) |>
  count(county, name = paste0("y", y))
tab <- Reduce(function(a, b) full_join(a, b, by = "county"),
              lapply(c(2005, 2010, 2015, 2020, 2026), active_by))
tab <- tab |> mutate(growth_2015_2026 = round(100 * (y2026 / y2015 - 1))) |> arrange(-y2026)
print(as.data.frame(tab))

cat("\n== Davidson share of metro orgs over time ==\n")
for (y in c(2000, 2005, 2010, 2015, 2020, 2026)) {
  a <- nash |> filter(first_year_in_bmf <= y, last_year_in_bmf >= y)
  cat(y, nrow(a), round(100 * mean(a$davidson), 1), "\n")
}

cat("\n== New registrations (first_year_in_bmf) per year, Davidson vs collar, 2010+ ==\n")
print(nash |> filter(first_year_in_bmf >= 2010) |>
  count(first_year_in_bmf, where = ifelse(davidson, "Davidson", "Collar")) |>
  tidyr::pivot_wider(names_from = where, values_from = n) |> as.data.frame())

cat("\n== Current (2026) by subsector x Davidson/collar ==\n")
cur <- nash |> filter(last_year_in_bmf >= 2026)
print(cur |> count(focus, where = ifelse(davidson, "Davidson", "Collar")) |>
  tidyr::pivot_wider(names_from = where, values_from = n) |>
  mutate(dav_share = round(100 * Davidson / (Davidson + Collar))) |> arrange(-Davidson) |> as.data.frame())

cat("\n== Subsection codes current ==\n")
print(cur |> count(subsection_code, sort = TRUE) |> head(8) |> as.data.frame())

cat("\n== Geocoding resolution rate, TN orgs active 2026 ==\n")
print(u |> filter(last_year_in_bmf >= 2026) |> summarise(n = n(), has_fips = mean(!is.na(geo_county_fips))))

cat("\n== Current public charities (501c3 non-PF) by city within Davidson ==\n")
print(cur |> filter(davidson, subsection_code == "03") |> count(geo_city, sort = TRUE) |> head(10) |> as.data.frame())

cat("\n== Ruling-year cohorts still active in 2026, metro: share formed 2015+ ==\n")
cur <- cur |> mutate(ruling_year = as.integer(substr(as.character(ruling_date), 1, 4)))
print(cur |> summarise(n = n(), formed_2015_plus = mean(ruling_year >= 2015, na.rm = TRUE), formed_2020_plus = mean(ruling_year >= 2020, na.rm = TRUE)))
print(cur |> group_by(where = ifelse(davidson, "Davidson", "Collar")) |> summarise(n = n(), formed_2015_plus = round(mean(ruling_year >= 2015, na.rm = TRUE), 3), formed_2020_plus = round(mean(ruling_year >= 2020, na.rm = TRUE), 3)))


# =============================================================================
# Pass 2-finance (formerly explore-2-finance.R)
# =============================================================================

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


# =============================================================================
# Pass 3-clean (formerly explore-3-clean.R)
# =============================================================================

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


# =============================================================================
# Pass 5-charities (formerly explore-5-charities.R)
# =============================================================================

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


# =============================================================================
# Pass 6-national (formerly explore-6-national.R)
# =============================================================================

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


# =============================================================================
# Pass 7-govgrants (formerly explore-7-govgrants.R)
# =============================================================================

# Pass 7: reported government grants (Form 990 Part VIII line 1e) as a
# share of revenue, e-file Phase 0, TY2020-2023.
#
# Line 1e is grants only. Government payments booked as program-service
# revenue (contracts, Medicaid and other reimbursements) are on line 2 and
# are NOT counted here. Every figure below is "reported line 1e government
# grants", not total government revenue (REVIEW.md finding 3).
#
# A blank line 1e is treated as zero. That is an assumption: the Phase 0
# extraction leaves the amount NULL when the XML element is absent, which is
# how filers with nothing on the line file, but it has not been verified
# against source filings. The blank share is reported by group and year so
# the assumption is visible (REVIEW.md finding 11).
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
d <- file.path(req, "data")
gg <- arrow::read_parquet(file.path(d, "government_grants.parquet")) |>
  filter(form_type == "990", tax_year %in% 2020:2023) |>
  arrange(desc(filing_receipt_id)) |> distinct(ein, tax_year, .keep_all = TRUE) |>
  transmute(ein9 = ein, tax_year, govt_grants = government_grants, in_phase0 = TRUE)
p <- arrow::read_parquet(file.path(d, "panel_charities.parquet")) |> filter(tax_year >= 2020) |>
  left_join(gg, by = c("ein9", "tax_year")) |>
  mutate(in_phase0 = coalesce(in_phase0, FALSE),
         gg0 = coalesce(govt_grants, 0), has_gg = gg0 > 0,
         gg_share = ifelse(rev_total > 0, gg0 / rev_total, NA),
         where = ifelse(geo_county_fips == "47037", "Davidson", "Collar"))

cat("== Join coverage and blank line 1e, by group and year ==\n")
print(p |> group_by(grp, tax_year) |> summarise(rows = n(), unmatched = sum(!in_phase0), blank_1e = round(100 * mean(is.na(govt_grants))),
                                                 share_over_1 = sum(gg_share > 1, na.rm = TRUE), .groups = "drop") |> as.data.frame())
stopifnot(all(p$in_phase0))

s <- function(df, ...) df |> group_by(...) |>
  summarise(filers = n(), share_reporting_1e = round(100 * mean(has_gg)),
            gg_m = round(sum(gg0) / 1e6), agg_1e_share_rev = round(100 * sum(gg0) / sum(rev_total, na.rm = TRUE), 1),
            med_share_among_recipients = round(100 * median(gg_share[has_gg], na.rm = TRUE)),
            share_25pct_plus = round(100 * mean(gg_share >= 0.25, na.rm = TRUE)),
            share_50pct_plus = round(100 * mean(gg_share >= 0.5, na.rm = TRUE)), .groups = "drop")
cat("\n== By group and year ==\n"); print(s(p, grp, tax_year) |> as.data.frame())
cat("\n== 2023 by subsector: Nashville vs Peer metros vs Rest of US ==\n")
print(s(p |> filter(tax_year == 2023, grp != "Rest of TN"), grp, focus) |> filter(filers >= 30) |> arrange(focus, grp) |> as.data.frame())
cat("\n== 2023 Nashville by county, all charities ==\n")
print(s(p |> filter(tax_year == 2023, grp == "Nashville"), geo_county_fips) |> arrange(-filers) |> as.data.frame())
cat("\n== 2023 Nashville by county, human services only ==\n")
print(s(p |> filter(tax_year == 2023, grp == "Nashville", focus == "HMS"), geo_county_fips) |> arrange(-filers) |> as.data.frame())
cat("\n== 2023 Nashville human services: Davidson vs collar ==\n")
print(s(p |> filter(tax_year == 2023, grp == "Nashville", focus == "HMS"), where) |> as.data.frame())
cat("\n== Davidson by year ==\n")
print(s(p |> filter(grp == "Nashville", where == "Davidson"), tax_year) |> as.data.frame())
cat("\n== Peer metros 2023 ==\n")
print(s(p |> filter(tax_year == 2023), metro) |> arrange(-agg_1e_share_rev) |> as.data.frame())
cat("\n== Nashville 2023: 15 largest reported line 1e amounts ==\n")
print(p |> filter(tax_year == 2023, grp == "Nashville") |> arrange(-gg0) |> transmute(org_name, focus, county = geo_county_fips, gg_m = round(gg0 / 1e6, 1), share = round(100 * gg_share)) |> head(15) |> as.data.frame())


# =============================================================================
# Pass 8-bmf (formerly explore-8-bmf.R)
# =============================================================================

# Pass 8: what the current (2026) Business Master File says on its own:
# formation, attrition, who is forming, private foundations, size.
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
d <- file.path(req, "data")
pop <- read.csv(file.path(d, "county_pop.csv"), colClasses = c(county_fips = "character"))
tn <- arrow::read_parquet(file.path(d, "universe_tn.parquet"))
peers <- arrow::read_parquet(file.path(d, "universe_peers.parquet"))

prep <- function(df) df |> mutate(
  ruling_year = as.integer(substr(as.character(ruling_date), 1, 4)),
  charity = as.integer(subsection_code) == 3 & !(foundation_code %in% c("02", "03", "04", "2", "3", "4")),
  pf = as.integer(subsection_code) == 3 & foundation_code %in% c("02", "03", "04", "2", "3", "4"),
  focus = ifelse(is.na(nteev2_subsector) | nteev2_subsector == "", "UNU", nteev2_subsector))
tn <- prep(tn); peers <- prep(peers)
cat("foundation_code values:\n"); print(head(sort(table(peers$foundation_code), decreasing = TRUE), 8))

cat("\n== Formation and attrition by metro, 501(c)(3) ==\n")
m <- peers |> filter(as.integer(subsection_code) == 3) |> group_by(metro) |>
  summarise(active_2026 = sum(last_year_in_bmf >= 2026),
            new_share_2020plus = round(100 * mean(ruling_year[last_year_in_bmf >= 2026] >= 2020, na.rm = TRUE)),
            active_2019 = sum(first_year_in_bmf <= 2019 & last_year_in_bmf >= 2019),
            gone_by_2026 = round(100 * mean(last_year_in_bmf[first_year_in_bmf <= 2019 & last_year_in_bmf >= 2019] < 2026)),
            growth_2019_2026 = round(100 * (active_2026 / active_2019 - 1)),
            pf_share_2026 = round(100 * mean(pf[last_year_in_bmf >= 2026], na.rm = TRUE), 1),
            pf_growth_2015_2026 = round(100 * (sum(pf & last_year_in_bmf >= 2026) / sum(pf & first_year_in_bmf <= 2015 & last_year_in_bmf >= 2015) - 1))) |>
  arrange(-growth_2019_2026)
print(as.data.frame(m))

cat("\n== Subsector mix of organizations ruled 2020+ and active 2026: Nashville vs all peers, charities ==\n")
mix <- peers |> filter(charity, last_year_in_bmf >= 2026, ruling_year >= 2020) |>
  mutate(g = ifelse(metro == "Nashville", "Nashville", "Peers")) |> count(g, focus) |> group_by(g) |> mutate(pct = round(100 * n / sum(n), 1)) |>
  select(-n) |> tidyr::pivot_wider(names_from = g, values_from = pct) |> mutate(diff = Nashville - Peers) |> arrange(-diff)
print(as.data.frame(mix))
cat("\n== Same for the stock active 2026 (all ruling years) ==\n")
mix2 <- peers |> filter(charity, last_year_in_bmf >= 2026) |>
  mutate(g = ifelse(metro == "Nashville", "Nashville", "Peers")) |> count(g, focus) |> group_by(g) |> mutate(pct = round(100 * n / sum(n), 1)) |>
  select(-n) |> tidyr::pivot_wider(names_from = g, values_from = pct) |> mutate(diff = Nashville - Peers) |> arrange(-diff)
print(as.data.frame(mix2))

nash <- tn |> filter(cbsa_code == "34980") |> mutate(county = sub(" County", "", county_name))
cat("\n== Nashville by county: formation, attrition, private foundations, size (charities + PF) ==\n")
print(nash |> filter(as.integer(subsection_code) == 3) |> group_by(county) |>
  summarise(active_2026 = sum(last_year_in_bmf >= 2026),
            new_2020plus = round(100 * mean(ruling_year[last_year_in_bmf >= 2026] >= 2020, na.rm = TRUE)),
            gone_by_2026 = round(100 * mean(last_year_in_bmf[first_year_in_bmf <= 2019 & last_year_in_bmf >= 2019] < 2026)),
            pf_2026 = sum(pf & last_year_in_bmf >= 2026),
            pf_growth_15_26 = round(100 * (pf_2026 / sum(pf & first_year_in_bmf <= 2015 & last_year_in_bmf >= 2015) - 1)),
            med_revenue_k = round(median(revenue_amount[last_year_in_bmf >= 2026 & revenue_amount > 0], na.rm = TRUE) / 1e3),
            share_rev_under_50k = round(100 * mean(revenue_amount[last_year_in_bmf >= 2026 & !is.na(revenue_amount)] < 50000)),
            share_rev_missing = round(100 * mean(is.na(revenue_amount[last_year_in_bmf >= 2026]))),
            assets_m = round(sum(asset_amount[last_year_in_bmf >= 2026], na.rm = TRUE) / 1e6)) |>
  inner_join(pop |> transmute(county = sub(" County", "", county), pop2023), by = "county") |>
  mutate(pf_per_10k = round(1e4 * pf_2026 / pop2023, 1), assets_per_cap = round(1e6 * assets_m / pop2023)) |> arrange(-active_2026) |> as.data.frame())

cat("\n== Nashville private foundations: assets by county, and top 10 ==\n")
print(nash |> filter(pf, last_year_in_bmf >= 2026) |> arrange(-asset_amount) |> transmute(org_name_display, county, assets_m = round(asset_amount / 1e6), ruling_year) |> head(10) |> as.data.frame())

# Period shares use the FULL active stock as the denominator (pre-2010 rulings
# included as their own row). An earlier version filtered to ruling_year >= 2010
# before computing pct, so the shares were of post-2010 rulings only while the
# label said "stock"; caught in the 2026-10-19 foundation-count review.
cat("\n== Private foundation formation by period, Nashville vs peers (share of each metro's full active PF stock) ==\n")
print(peers |> filter(pf, last_year_in_bmf >= 2026) |> mutate(g = ifelse(metro == "Nashville", "Nashville", "Peers"), period = cut(ruling_year, c(-Inf, 2009, 2014, 2019, 2022, 2026), labels = c("pre-2010", "2010-14", "2015-19", "2020-22", "2023-26"))) |>
  count(g, period) |> group_by(g) |> mutate(pct = round(100 * n / sum(n), 1)) |> as.data.frame())
cat("\n== Private foundation rulings by year 2015-2026, Nashville metro vs pooled peers (active stock; 2026 is partial, rulings through April in this build) ==\n")
print(peers |> filter(pf, last_year_in_bmf >= 2026, ruling_year >= 2015) |> mutate(g = ifelse(metro == "Nashville", "Nashville", "Peers")) |> count(g, ruling_year) |> tidyr::pivot_wider(names_from = g, values_from = n) |> as.data.frame())
cat("\n== Davidson County private foundations by ruling year 2015-2026 (active stock) ==\n")
print(nash |> filter(pf, last_year_in_bmf >= 2026, county == "Davidson", ruling_year >= 2015) |> count(ruling_year) |> as.data.frame())

cat("\n== Davidson zip codes: charities active 2026, ranked by number ruled 2020+ (current address, not address at founding) ==\n")
z <- nash |> filter(charity, geo_county_fips == "47037", last_year_in_bmf >= 2026) |> group_by(zip = org_addr_zip5) |>
  summarise(n = n(), ruled_2020plus = sum(ruling_year >= 2020, na.rm = TRUE), hms_all = sum(focus == "HMS"), hms_ruled_2020plus = sum(focus == "HMS" & ruling_year >= 2020, na.rm = TRUE),
            orgs_assets_over_10m = sum(asset_amount >= 1e7, na.rm = TRUE), assets_m = round(sum(asset_amount, na.rm = TRUE) / 1e6)) |> filter(n >= 40) |> arrange(-ruled_2020plus)
print(as.data.frame(z))

cat("\n== Attrition by subsector, Nashville vs peers: of charities active 2019, share gone by 2026 ==\n")
print(peers |> filter(charity, first_year_in_bmf <= 2019, last_year_in_bmf >= 2019) |> mutate(g = ifelse(metro == "Nashville", "Nashville", "Peers")) |>
  group_by(g, focus) |> summarise(n = n(), gone = round(100 * mean(last_year_in_bmf < 2026)), .groups = "drop") |>
  tidyr::pivot_wider(names_from = g, values_from = c(n, gone)) |> as.data.frame())


# =============================================================================
# Pass 9-davidson (formerly explore-9-davidson.R)
# =============================================================================

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


# =============================================================================
# Pass 10-volunteers (formerly explore-10-volunteers.R)
# =============================================================================

# Pass 10: volunteer reliance. Form 990 Part I line 6 (total number of
# volunteers, a headcount estimate the filer supplies; many leave it blank
# or enter 0). 501(c)(3) charities excluding hospitals and universities.
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
d <- file.path(req, "data")
p <- arrow::read_parquet(file.path(d, "panel_charities.parquet")) |>
  # `grp` is the partition set in explore-6; only Nashville is split here.
  mutate(grp = case_when(grp == "Nashville" & geo_county_fips == "47037" ~ "Davidson",
                         grp == "Nashville" ~ "Nashville collar",
                         TRUE ~ grp),
         vol = volunteers, emp = employees,
         reports_vol = !is.na(vol) & vol > 0,   # strictly positive
         vol_nonmissing = !is.na(vol),
         vol_per_emp = ifelse(reports_vol & emp > 0, vol / emp, NA),
         volunteer_only = reports_vol & (is.na(emp) | emp == 0),
         vol_heavy = reports_vol & emp > 0 & vol >= 10 * emp)

s <- function(df, ...) df |> group_by(...) |>
  summarise(filers = n(), share_positive_volunteers = round(100 * mean(reports_vol)), share_nonmissing = round(100 * mean(vol_nonmissing)),
            volunteers_total = sum(vol, na.rm = TRUE), employees_total = sum(emp, na.rm = TRUE),
            vol_per_emp_agg = round(sum(vol[reports_vol & emp > 0], na.rm = TRUE) / sum(emp[reports_vol & emp > 0], na.rm = TRUE), 2),
            med_vol_positive = median(vol[reports_vol]), med_vol_positive_with_staff = median(vol[reports_vol & emp > 0], na.rm = TRUE), med_vol_per_emp = round(median(vol_per_emp, na.rm = TRUE), 1),
            share_volunteer_only = round(100 * mean(volunteer_only)), share_vol_heavy = round(100 * mean(vol_heavy)), .groups = "drop")

cat("== By group, selected years ==\n")
print(s(p |> filter(tax_year %in% c(2015, 2019, 2021, 2023)), grp, tax_year) |> arrange(grp, tax_year) |> as.data.frame())

cat("\n== Davidson and metro by year ==\n")
print(s(p |> filter(metro == "Nashville"), tax_year) |> as.data.frame())

cat("\n== 2023 by subsector: Davidson vs Rest of US ==\n")
print(s(p |> filter(tax_year == 2023, grp %in% c("Davidson", "Rest of US")), grp, focus) |> filter(filers >= 30) |> arrange(focus, grp) |>
  select(grp, focus, filers, share_positive_volunteers, share_nonmissing, med_vol_positive, med_vol_positive_with_staff, med_vol_per_emp, share_volunteer_only, share_vol_heavy) |> as.data.frame())

cat("\n== Peer central counties 2023 (principal county of each metro) ==\n")
peers <- arrow::read_parquet(file.path(d, "universe_peers.parquet"))
principal <- peers |> filter(last_year_in_bmf >= 2026) |> count(metro, geo_county_fips) |> group_by(metro) |> slice_max(n, n = 1) |> ungroup()
print(s(p |> filter(tax_year == 2023) |> inner_join(principal |> select(metro, geo_county_fips), by = c("metro", "geo_county_fips")), metro) |>
  arrange(-med_vol_per_emp) |> select(metro, filers, share_positive_volunteers, share_nonmissing, med_vol_positive, med_vol_positive_with_staff, med_vol_per_emp, share_volunteer_only, share_vol_heavy) |> as.data.frame())

cat("\n== Balanced 2019-2023: organizations with POSITIVE volunteers in both years (excludes moves to zero/blank) ==\n")
bal <- p |> filter(tax_year %in% c(2019, 2023), reports_vol) |> group_by(ein2) |> filter(n() == 2) |> ungroup() |>
  select(ein2, grp, focus, tax_year, vol) |> tidyr::pivot_wider(names_from = tax_year, values_from = vol, names_prefix = "v") |>
  mutate(chg = v2023 / v2019 - 1)
print(bal |> group_by(grp) |> summarise(n = n(), med_chg = round(100 * median(chg), 1), share_down = round(100 * mean(chg < 0)), share_up = round(100 * mean(chg > 0))) |> as.data.frame())
print(bal |> filter(grp == "Davidson") |> group_by(focus) |> summarise(n = n(), med_chg = round(100 * median(chg), 1), share_down = round(100 * mean(chg < 0))) |> filter(n >= 20) |> as.data.frame())

cat("\n== Davidson: contribution of the largest 2019->2023 declines to the total change ==\n")
print(bal |> filter(grp == "Davidson") |> mutate(d = v2023 - v2019) |> arrange(d) |> inner_join(p |> filter(tax_year == 2023) |> distinct(ein2, org_name), by = "ein2") |> transmute(org_name, v2019, v2023, d) |> head(5) |> as.data.frame())
print(bal |> filter(grp == "Davidson") |> summarise(n = n(), total_2019 = sum(v2019), total_2023 = sum(v2023), med_chg = round(100 * median(chg), 1)) |> as.data.frame())
cat("\n== Davidson 2023: largest volunteer counts ==\n")
print(p |> filter(tax_year == 2023, grp == "Davidson") |> arrange(-vol) |> transmute(org_name, focus, volunteers = vol, employees = emp) |> head(10) |> as.data.frame())


# =============================================================================
# Pass 11-exit-trace (formerly explore-11-exit-trace.R)
# =============================================================================

# Pass 11: trace the exit cohort. Charities (501(c)(3), excl HOS/UNI) in the
# Nashville metro with paid staff on a full Form 990 for TY2019 that have no
# full Form 990 for TY2023 in the e-file panel. Where did they go?
#   - CORE merged tier (990combined = full 990 + 990-EZ, from IRS SOI
#     extracts, not e-file): did they file anything for TY2021-2024, and on
#     which form?
#   - The e-file panel itself: did they file a full 990 for TY2020-2022?
#   - BMF: are they still registered in 2026?
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
source(here::here("R", "request_read.R"))
d <- file.path(req, "data")
p <- arrow::read_parquet(file.path(d, "panel_charities.parquet"))
panel_all <- arrow::read_parquet(file.path(d, "panel_990_national.parquet"))
tn <- arrow::read_parquet(file.path(d, "universe_tn.parquet"))

nash19 <- p |> filter(grp == "Nashville", tax_year == 2019, employees > 0)
in23 <- p |> filter(tax_year == 2023) |> pull(ein2)
cohort <- nash19 |> mutate(exited = !(ein2 %in% in23), davidson = geo_county_fips == "47037") |>
  select(ein2, ein9, org_name, focus, davidson, exited, employees_2019 = employees, rev_2019 = rev_total, exp_2019 = exp_total, pay_2019 = pay_per_emp_real)
cat("cohort:", nrow(cohort), "staffed 2019 filers;", sum(cohort$exited), "exited\n")

# e-file panel presence by year
pres <- panel_all |> filter(ein2 %in% cohort$ein2, tax_year %in% 2020:2023) |> distinct(ein2, tax_year) |> mutate(v = TRUE) |>
  tidyr::pivot_wider(names_from = tax_year, values_from = v, names_prefix = "efile_", values_fill = FALSE)
cohort <- cohort |> left_join(pres, by = "ein2") |> mutate(across(starts_with("efile_"), ~ coalesce(.x, FALSE)))

# CORE merged tier, 990combined, TY2021-2024
core <- bind_rows(lapply(2021:2024, function(y) {
  x <- nccsdata::nccs_read_core(tier = "merged", tax_year = y, form = "990combined",
                                columns = c("ein", "tax_year", "source_form", "total_revenue", "total_expenses", "tax_period"), confirm = FALSE)
  record_pin(req, "core-merged-990combined", vintage = as.character(y), source = nccsdata::nccs_core_url("merged", y, "990combined"),
             n_rows = nrow(x), note = "exit-cohort trace")
  x
})) |> mutate(ein9 = gsub("-", "", ein))
cat("CORE EIN sample:", head(core$ein, 2), " source_form values:", paste(names(table(core$source_form)), collapse = ", "), "\n")

# CORE labels a return by the year its accounting period ENDS; the e-file
# panel and the IRS label by the form year (period beginning). Relabel so
# that "TY2023" means the same thing in both sources (second-analyst
# review, 2026-10-29; before this, 58 June-year form-2022 returns were
# read as 2023 returns missing from the e-file release).
core <- core |>
  mutate(period_end_year = as.integer(substr(tax_period, 1, 4)),
         period_end_month = as.integer(substr(tax_period, 5, 6)),
         tax_year = if_else(period_end_month == 12L, period_end_year, period_end_year - 1L))

core_c <- core |> filter(ein9 %in% cohort$ein9) |> arrange(ein9, tax_year, desc(tax_period)) |> distinct(ein9, tax_year, .keep_all = TRUE)
core_wide <- core_c |> select(ein9, tax_year, source_form) |> tidyr::pivot_wider(names_from = tax_year, values_from = source_form, names_prefix = "core_")
# After relabeling, a form year may have no cohort returns at all (form 2024
# is only in the partial 2024 release); keep every column the status rules use.
for (missing_col in setdiff(paste0("core_", 2021:2024), names(core_wide))) core_wide[[missing_col]] <- NA_character_
core_rev23 <- core_c |> filter(tax_year == 2023) |> select(ein9, rev_2023_core = total_revenue, form_2023 = source_form)
cohort <- cohort |> left_join(core_wide, by = "ein9") |> left_join(core_rev23, by = "ein9") |>
  left_join(tn |> select(ein9, last_year_in_bmf), by = "ein9")

cohort <- cohort |> mutate(
  status = case_when(
    !exited ~ "stayed (full 990 TY2023 in e-file)",
    !is.na(core_2023) & grepl("EZ", core_2023, ignore.case = TRUE) ~ "switched to 990-EZ (CORE TY2023)",
    !is.na(core_2023) ~ "full 990 TY2023 in CORE, missing from e-file release",
    !is.na(core_2024) ~ "no TY2023 return; filed TY2024",
    efile_2022 | !is.na(core_2022) ~ "last return TY2022 (late or stopped)",
    efile_2021 | !is.na(core_2021) ~ "last return TY2021",
    last_year_in_bmf < 2026 ~ "no return since TY2020 and dropped from BMF",
    TRUE ~ "no return since TY2020, still registered in BMF"))

cat("\n== Exit cohort status, metro and Davidson ==\n")
print(cohort |> filter(exited) |> count(status, sort = TRUE) |> as.data.frame())
print(cohort |> filter(exited, davidson) |> count(status, sort = TRUE) |> as.data.frame())

cat("\n== 2019 pay per head and size by status (metro) ==\n")
print(cohort |> group_by(status) |> summarise(n = n(), n_pay = sum(!is.na(pay_2019)), med_pay_2019 = round(median(pay_2019, na.rm = TRUE)),
  med_employees_2019 = median(employees_2019), med_rev_2019_k = round(median(rev_2019, na.rm = TRUE) / 1e3), med_rev_2023_core_k = round(median(rev_2023_core, na.rm = TRUE) / 1e3)) |> arrange(-n) |> as.data.frame())

cat("\n== Exiters: pay gap vs stayers after removing those that merely switched to the 990-EZ or appear in CORE ==\n")
stay <- cohort |> filter(!exited) |> pull(pay_2019)
for (g in unique(cohort$status[cohort$exited])) {
  x <- cohort$pay_2019[cohort$status == g]
  cat(sprintf("%-60s n=%3d med=%6.0f gap vs stayers=%6.0f\n", g, sum(!is.na(x)), median(x, na.rm = TRUE), median(x, na.rm = TRUE) - median(stay, na.rm = TRUE)))
}
truly_gone <- cohort |> filter(exited, !grepl("EZ|CORE|TY2024", status))
cat(sprintf("\nExiters with no TY2023 or TY2024 return anywhere: n=%d, median 2019 pay %.0f vs stayers %.0f (n=%d)\n",
            sum(!is.na(truly_gone$pay_2019)), median(truly_gone$pay_2019, na.rm = TRUE), median(stay, na.rm = TRUE), sum(!is.na(stay))))

cat("\n== Peer metros and Rest of US: same classification using CORE only (share of exiters that filed a 990-EZ in TY2023) ==\n")
for (g in c("Peer metros", "Rest of US")) {
  x19 <- p |> filter(grp == g, tax_year == 2019, employees > 0) |> mutate(exited = !(ein2 %in% in23))
  ex <- x19 |> filter(exited) |> select(ein9, pay_2019 = pay_per_emp_real)
  cw <- core |> filter(ein9 %in% ex$ein9, tax_year == 2023) |> distinct(ein9, .keep_all = TRUE) |> select(ein9, form_2023 = source_form)
  ex <- ex |> left_join(cw, by = "ein9") |> mutate(status = case_when(grepl("EZ", form_2023, ignore.case = TRUE) ~ "990-EZ TY2023", !is.na(form_2023) ~ "full 990 TY2023 in CORE", TRUE ~ "no TY2023 return in CORE"))
  print(ex |> group_by(status) |> summarise(n = n(), share = round(100 * n() / nrow(ex)), med_pay_2019 = round(median(pay_2019, na.rm = TRUE))) |> mutate(group = g) |> as.data.frame())
}

utils::write.csv(cohort |> filter(exited) |> select(org_name, focus, davidson, status, employees_2019, rev_2019, pay_2019, rev_2023_core, last_year_in_bmf),
                 file.path(req, "output", "exit_cohort_trace.csv"), row.names = FALSE)


# =============================================================================
# Pass 12-coverage (formerly explore-12-coverage.R)
# =============================================================================

# Pass 12: how incomplete is TY2023 in the e-file v2.1 release? Compare the
# count of full Form 990 filings per tax year in the CORE merged tier (IRS
# SOI extracts) with the e-file panel, for the same EIN sets. Also a
# bootstrap interval on the pay gap for exiters with no TY2023/2024 return.
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
source(here::here("R", "request_read.R"))
d <- file.path(req, "data")
p <- arrow::read_parquet(file.path(d, "panel_charities.parquet"))
peers <- arrow::read_parquet(file.path(d, "universe_peers.parquet")) |> distinct(ein9, .keep_all = TRUE)
tn <- arrow::read_parquet(file.path(d, "universe_tn.parquet"))
nat <- arrow::read_parquet(file.path(d, "bmf_national_slim.parquet")) |> mutate(ein9 = gsub("-", "", ein)) |> distinct(ein9, .keep_all = TRUE)

core <- bind_rows(lapply(2019:2024, function(y) {
  x <- nccsdata::nccs_read_core(tier = "merged", tax_year = y, form = "990combined",
                                columns = c("ein", "tax_year", "source_form", "tax_period", "total_expenses"), confirm = FALSE)
  record_pin(req, "core-merged-990combined", vintage = as.character(y), source = nccsdata::nccs_core_url("merged", y, "990combined"),
             n_rows = nrow(x), note = "TY2023 coverage comparison")
  x
})) |> mutate(ein9 = gsub("-", "", ein)) |>
  # Relabel CORE's period-end year to the IRS form year (see pass 11).
  mutate(period_end_year = as.integer(substr(tax_period, 1, 4)),
         period_end_month = as.integer(substr(tax_period, 5, 6)),
         tax_year = if_else(period_end_month == 12L, period_end_year, period_end_year - 1L)) |>
  arrange(ein9, tax_year, desc(tax_period)) |> distinct(ein9, tax_year, .keep_all = TRUE)

# Same population definition as the panel: 501(c)(3), excl HOS/UNI (current BMF).
charity <- nat |> filter(as.integer(subsection_code) == 3, !(nteev2_subsector %in% c("HOS", "UNI"))) |> select(ein9, state = geo_state_abbr)
geo <- peers |> select(ein9, metro, geo_county_fips)
core_c <- core |> inner_join(charity, by = "ein9") |> left_join(geo, by = "ein9") |>
  mutate(grp = case_when(metro == "Nashville" ~ "Nashville", !is.na(metro) ~ "Peer metros", state == "TN" ~ "Rest of TN", TRUE ~ "Rest of US"),
         davidson = metro == "Nashville" & geo_county_fips == "47037")

efile_n <- p |> filter(tax_year %in% 2019:2023) |> count(grp, tax_year, name = "efile_full_990")
core_n <- core_c |> filter(source_form == "990") |> count(grp, tax_year, name = "core_full_990")
core_ez <- core_c |> filter(source_form == "990ez") |> count(grp, tax_year, name = "core_990ez")
both <- core_c |> filter(source_form == "990") |> semi_join(p, by = c("ein9", "tax_year")) |> count(grp, tax_year, name = "in_both")
cat("== Full Form 990 filings per year: e-file v2.1 panel vs CORE (SOI), same EIN population ==\n")
print(efile_n |> full_join(core_n, by = c("grp", "tax_year")) |> full_join(both, by = c("grp", "tax_year")) |> full_join(core_ez, by = c("grp", "tax_year")) |>
  mutate(core_not_in_efile = core_full_990 - in_both, efile_not_in_core = efile_full_990 - in_both,
         efile_share_of_core = round(100 * efile_full_990 / core_full_990)) |> arrange(grp, tax_year) |> as.data.frame())

cat("\n== Davidson only ==\n")
dav_e <- p |> filter(metro == "Nashville", geo_county_fips == "47037", tax_year %in% 2019:2023) |> count(tax_year, name = "efile_full_990")
dav_c <- core_c |> filter(davidson, source_form == "990") |> count(tax_year, name = "core_full_990")
print(dav_e |> full_join(dav_c, by = "tax_year") |> mutate(efile_share_of_core = round(100 * efile_full_990 / core_full_990)) |> as.data.frame())

cat("\n== Bootstrap on the pay gap: exiters with no TY2023/TY2024 return vs stayers (metro) ==\n")
trace <- read.csv(file.path(req, "output", "exit_cohort_trace.csv"))
gone <- trace$pay_2019[!grepl("EZ|CORE|TY2024", trace$status) & !is.na(trace$pay_2019)]
in23 <- p |> filter(tax_year == 2023) |> pull(ein2)
stay <- p |> filter(grp == "Nashville", tax_year == 2019, employees > 0, ein2 %in% in23, !is.na(pay_per_emp_real)) |> pull(pay_per_emp_real)
set.seed(20261012)
gaps <- replicate(2000, median(sample(gone, replace = TRUE)) - median(sample(stay, replace = TRUE)))
cat(sprintf("n_gone=%d n_stay=%d median gap=%.0f  95%% interval %.0f to %.0f\n", length(gone), length(stay), median(gone) - median(stay), quantile(gaps, .025), quantile(gaps, .975)))

cat("\n== Same for peer metros and rest of US, 'no TY2023 return in CORE' exiters vs stayers ==\n")
core23 <- core |> filter(tax_year == 2023) |> distinct(ein9)
for (g in c("Peer metros", "Rest of US")) {
  x19 <- p |> filter(grp == g, tax_year == 2019, employees > 0, !is.na(pay_per_emp_real)) |> mutate(exited = !(ein2 %in% in23), in_core23 = ein9 %in% core23$ein9)
  gone_g <- x19$pay_per_emp_real[x19$exited & !x19$in_core23]; stay_g <- x19$pay_per_emp_real[!x19$exited]
  gaps <- replicate(500, median(sample(gone_g, replace = TRUE)) - median(sample(stay_g, replace = TRUE)))
  cat(sprintf("%-12s n_gone=%5d n_stay=%6d median gap=%.0f  95%% interval %.0f to %.0f\n", g, length(gone_g), length(stay_g), median(gone_g) - median(stay_g), quantile(gaps, .025), quantile(gaps, .975)))
}
