# Pass 13: the round 2 charts and tables for the sector health profile of
# Davidson County (Metro Nashville). Every table and chart names its filing
# population (reviewer's design rule, RESPONSE-REVIEWER-ROUND2.md).
#
# Sections:
#   A. Coverage: registry count against returns actually observed for tax
#      year 2023 (full 990, 990-EZ, 990-PF, none seen). The CORE tier has no
#      990-N file, so postcard filers and non-filers are one group.
#   B. Starts: registry recognitions (ruling year) of organizations still on
#      the registry, by year.
#   C. Exits, two series kept separate: (1) stopped filing: no return of any
#      type for two consecutive form years after the last one, judged through
#      form year 2021 (2022 provisional because the 2024 CORE release is
#      partial); (2) left the registry: last registry vintage seen before 2026.
#   D. Operating expenses by percentile, tax year 2023, full 990 and 990-EZ
#      together, all Davidson charities and human services.
#   E. Reported government grants (line 1e) as a share of revenue, 2020 to
#      2023, full-990 charities, Davidson vs peer metros vs rest of US.
#   F. Full-990 charity filers, inflation-adjusted spending and reported
#      employees, 2019 to 2023, indexed to 2019.
#
# Tax year means the IRS form year (period beginning in that year). The
# CORE tier labels by period-end year and is relabeled here (see
# explore-14-profile.R and checklist.md).

library(dplyr)
library(ggplot2)

request_dir <- here::here("requests", "2026-10-nashville-msa")
source(here::here("R", "request_read.R"))
data_dir <- file.path(request_dir, "data")
output_dir <- file.path(request_dir, "output")

davidson_fips <- "47037"

registry_tn <- arrow::read_parquet(file.path(data_dir, "universe_tn.parquet"))

davidson_registry <- registry_tn |>
  filter(geo_county_fips == davidson_fips) |>
  mutate(
    is_501c3 = as.integer(subsection_code) == 3L,
    is_private_foundation = is_501c3 & foundation_code %in% c("2", "3", "4"),
    is_charity = is_501c3 & !is_private_foundation,
    # Hospitals and universities are flagged by the NTEE-V2 subsector code.
    # Institutions whose registry NTEE code is undefined are not caught by
    # the code; the Davidson ones found by listing full-990 filers with
    # undefined codes and expenses over $20M are added here by EIN
    # (second-analyst review, 2026-10-29).
    is_hos_uni = nteev2_subsector %in% c("HOS", "UNI") |
      ein9 %in% c("620485733",   # Lipscomb University
                  "061395640"),  # Richmond, The American International University in London (Nashville office)
    is_human_services = nteev2_subsector %in% "HMS",
    ruling_year = as.integer(substr(as.character(ruling_date), 1, 4)),
    on_registry_2026 = last_year_in_bmf >= 2026
  )

save_chart <- function(plot, file_name, width = 8, height = 5) {
  ggsave(file.path(output_dir, file_name), plot, width = width, height = height, dpi = 150, bg = "white")
}


# --- CORE returns for Tennessee EINs, relabeled to form year ----------------

relabel_form_year <- function(core_table) {
  core_table |>
    mutate(
      ein9 = gsub("-", "", ein),
      period_end_year = as.integer(substr(tax_period, 1, 4)),
      period_end_month = as.integer(substr(tax_period, 5, 6)),
      form_year = if_else(period_end_month == 12L, period_end_year, period_end_year - 1L)
    )
}

tn_ein9 <- unique(registry_tn$ein9)

core_990_ez <- bind_rows(lapply(2015:2024, function(core_year) {
  read_core(request_dir, tier = "merged", tax_year = core_year, form = "990combined",
            columns = c("ein", "tax_year", "source_form", "tax_period", "total_expenses", "total_revenue"),
            note = "Davidson coverage, exits and expense percentiles; relabeled to form year")
})) |>
  relabel_form_year() |>
  filter(ein9 %in% tn_ein9)

core_pf <- bind_rows(lapply(c(2015, 2016, 2020:2024), function(core_year) {
  read_core(request_dir, tier = "merged", tax_year = core_year, form = "990pf",
            columns = c("ein", "tax_year", "tax_period"),
            note = "Davidson coverage and exits (990-PF); 2017-2019 absent from the tier")
})) |>
  relabel_form_year() |>
  mutate(source_form = "990pf") |>
  filter(ein9 %in% tn_ein9)

# The merged tier has no 990-PF for 2017-2019 (nccsdata documentation); the
# exit series below therefore treats private foundations separately.

efile_panel <- arrow::read_parquet(file.path(data_dir, "panel_990_national.parquet")) |>
  filter(ein9 %in% tn_ein9) |>
  transmute(ein9, form_year = tax_year, source_form = "990", total_expenses = exp_total,
            total_revenue = rev_total, employees)

# One record per EIN and form year, full 990 preferred over EZ, e-file and
# CORE unioned (each release misses some of the other's filings).
returns <- bind_rows(
  core_990_ez |> select(ein9, form_year, source_form, total_expenses, total_revenue) |> mutate(from = "core"),
  core_pf |> select(ein9, form_year, source_form) |> mutate(from = "core"),
  efile_panel |> select(ein9, form_year, source_form, total_expenses, total_revenue) |> mutate(from = "efile")
) |>
  mutate(form_rank = match(source_form, c("990", "990pf", "990ez")),
         source_rank = match(from, c("efile", "core"))) |>
  arrange(ein9, form_year, form_rank, source_rank) |>
  distinct(ein9, form_year, .keep_all = TRUE)


# --- A. Coverage: registry against observed returns, tax year 2023 ---------

returns_2023 <- returns |> filter(form_year == 2023L) |> select(ein9, source_form_2023 = source_form)

coverage <- davidson_registry |>
  filter(on_registry_2026) |>
  left_join(returns_2023, by = "ein9") |>
  mutate(filing_2023 = case_when(
    source_form_2023 == "990" ~ "Full Form 990",
    source_form_2023 == "990ez" ~ "Form 990-EZ",
    source_form_2023 == "990pf" ~ "Form 990-PF",
    TRUE ~ "No return seen (990-N postcard or none)"
  ))

coverage_table <- bind_rows(
  coverage |> mutate(population = "All registered organizations"),
  coverage |> filter(is_501c3) |> mutate(population = "501(c)(3), all"),
  coverage |> filter(is_charity) |> mutate(population = "501(c)(3) public charities"),
  coverage |> filter(is_charity, !is_hos_uni) |> mutate(population = "501(c)(3) public charities excl. hospitals and universities"),
  coverage |> filter(is_charity, is_human_services) |> mutate(population = "501(c)(3) human services charities")
) |>
  count(population, filing_2023) |>
  group_by(population) |>
  mutate(registry_count = sum(n), share = round(100 * n / registry_count)) |>
  ungroup()

cat("== A. Davidson County registry (on the 2026 registry) against tax year 2023 returns observed ==\n")
print(coverage_table |> select(population, registry_count, filing_2023, n, share) |> as.data.frame())
write.csv(coverage_table, file.path(output_dir, "chart_a_coverage_ty2023.csv"), row.names = FALSE)

cat("\n== A2. Hospitals and universities on the Davidson registry (NTEE-V2 subsector HOS or UNI) ==\n")
print(coverage |> filter(is_501c3, is_hos_uni) |> count(nteev2_subsector, filing_2023) |> as.data.frame())
hos_uni_expenses <- coverage |> filter(is_501c3, source_form_2023 == "990") |>
  inner_join(returns |> filter(form_year == 2023L) |> select(ein9, total_expenses), by = "ein9") |>
  group_by(is_hos_uni) |> summarise(filers = n(), expenses_bn = round(sum(total_expenses, na.rm = TRUE) / 1e9, 2), .groups = "drop")
print(as.data.frame(hos_uni_expenses))


# --- B. Starts: recognitions by ruling year, organizations still registered ---

starts <- davidson_registry |>
  filter(on_registry_2026, ruling_year >= 2005, ruling_year <= 2026) |>
  mutate(group = case_when(is_charity & is_human_services ~ "Human services charities",
                           is_charity ~ "Other public charities",
                           is_private_foundation ~ "Private foundations",
                           TRUE ~ "Other exempt organizations")) |>
  count(ruling_year, group)

cat("\n== B. Davidson recognitions by ruling year, organizations still on the 2026 registry (2026 partial) ==\n")
print(starts |> tidyr::pivot_wider(names_from = group, values_from = n, values_fill = 0) |> as.data.frame())
write.csv(starts, file.path(output_dir, "chart_b_starts_by_ruling_year.csv"), row.names = FALSE)

chart_b <- ggplot(starts |> filter(ruling_year <= 2025), aes(ruling_year, n, fill = group)) +
  geom_col() +
  labs(title = "Davidson County: organizations recognized by the IRS, by year",
       subtitle = "Registry (BMF) ruling year; organizations still on the registry in 2026. Recognition, not founding.",
       x = NULL, y = "Organizations", fill = NULL) +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
save_chart(chart_b, "chart_b_starts.png")


# --- C. Exits: two series, kept separate ----------------------------------

# (1) Stopped filing. Universe: Davidson organizations (not private
# foundations, because 990-PF is absent from the tier for 2017-2019) that
# filed any 990 or 990-EZ for form years 2015 to 2021. An organization stops
# filing after form year Y if it filed for Y and nothing for Y+1 and Y+2.
filers_990_ez <- returns |>
  filter(source_form %in% c("990", "990ez")) |>
  semi_join(davidson_registry |> filter(!is_private_foundation), by = "ein9")

filed_years <- filers_990_ez |> distinct(ein9, form_year)

stopped <- bind_rows(lapply(2015:2022, function(last_year) {
  filed_last <- filed_years |> filter(form_year == last_year) |> pull(ein9)
  filed_after <- filed_years |> filter(form_year %in% c(last_year + 1L, last_year + 2L)) |> pull(ein9)
  tibble(last_form_year = last_year, filers = length(filed_last),
         stopped_after = sum(!(filed_last %in% filed_after)))
})) |>
  mutate(exit_year = last_form_year + 1L, share_pct = round(100 * stopped_after / filers, 1),
         status = if_else(last_form_year >= 2022L, "provisional: 2024 release partial", "judged"))

cat("\n== C1. Stopped filing: Davidson 990/990-EZ filers (not private foundations) with no return in the next two form years ==\n")
print(as.data.frame(stopped))
write.csv(stopped, file.path(output_dir, "chart_c1_stopped_filing.csv"), row.names = FALSE)

# (2) Left the registry: last BMF vintage seen. Registry vintages step, and
# revocation lists lag, so the series is lumpy (round 1 caveat 6).
left_registry <- davidson_registry |>
  filter(first_year_in_bmf <= 2018) |>
  mutate(left_year = if_else(last_year_in_bmf < 2026, last_year_in_bmf + 1L, NA_integer_)) |>
  filter(!is.na(left_year), left_year >= 2015) |>
  count(left_year, is_charity) |>
  tidyr::pivot_wider(names_from = is_charity, values_from = n, values_fill = 0,
                     names_prefix = "charity_")

cat("\n== C2. Left the registry: Davidson organizations on the registry by 2018, by first vintage year absent ==\n")
print(as.data.frame(left_registry))
write.csv(left_registry, file.path(output_dir, "chart_c2_left_registry.csv"), row.names = FALSE)

# Chart shows judged years only. "Stopped filing" is a two-year filing
# interruption, not a confirmed closure: some organizations file again later.
chart_c <- ggplot(stopped |> filter(status == "judged"), aes(exit_year, share_pct)) +
  geom_col(fill = "#F8766D") +
  scale_x_continuous(breaks = 2016:2022) +
  labs(title = "Davidson County: share of 990 and 990-EZ filers with a two-year filing gap",
       subtitle = "Filed for the prior form year, no return of either type in the next two years.\nA filing gap, not a confirmed closure. Private foundations excluded.",
       x = "First year without a return", y = "Percent of prior-year filers") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
save_chart(chart_c, "chart_c_stopped_filing.png")


# --- D. Operating expenses by percentile, tax year 2023 --------------------

expenses_2023 <- returns |>
  filter(form_year == 2023L, source_form %in% c("990", "990ez"), !is.na(total_expenses), total_expenses > 0) |>
  inner_join(davidson_registry |> filter(is_charity) |> select(ein9, is_hos_uni, is_human_services), by = "ein9")

percentile_table <- function(values, label) {
  qs <- quantile(values, c(0.1, 0.25, 0.5, 0.75, 0.9, 0.95), na.rm = TRUE)
  tibble(population = label, filers = length(values),
         p10 = qs[1], p25 = qs[2], median = qs[3], p75 = qs[4], p90 = qs[5], p95 = qs[6],
         share_under_250k = round(100 * mean(values < 250e3)),
         share_under_1m = round(100 * mean(values < 1e6)))
}

percentiles <- bind_rows(
  percentile_table(expenses_2023$total_expenses, "All Davidson charities, full 990 and 990-EZ"),
  percentile_table(expenses_2023$total_expenses[!expenses_2023$is_hos_uni], "Excl. hospitals and universities"),
  percentile_table(expenses_2023$total_expenses[expenses_2023$is_human_services], "Human services"),
  percentile_table(expenses_2023 |> filter(source_form == "990") |> pull(total_expenses), "Full 990 only, all charities"),
  percentile_table(expenses_2023 |> filter(source_form == "990", is_human_services) |> pull(total_expenses), "Full 990 only, human services")
)

cat("\n== D. Total expenses by percentile, tax year 2023, Davidson 501(c)(3) public charities ==\n")
print(percentiles |> mutate(across(p10:p95, ~ round(.x / 1e3))) |> as.data.frame())
cat("(p10 to p95 in $ thousands; filers reporting zero expenses dropped; 990-N filers, under $50,000 in receipts, are not in any row)\n")
write.csv(percentiles, file.path(output_dir, "chart_d_expense_percentiles_ty2023.csv"), row.names = FALSE)

chart_d_data <- expenses_2023 |>
  filter(!is_hos_uni) |>
  mutate(population = if_else(is_human_services, "Human services", "All other charities"))
chart_d <- ggplot(chart_d_data, aes(total_expenses, colour = population)) +
  stat_ecdf(linewidth = 0.9) +
  scale_x_log10(breaks = c(1e4, 1e5, 1e6, 1e7, 1e8), labels = c("$10k", "$100k", "$1M", "$10M", "$100M")) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Davidson County charities: total expenses, tax year 2023",
       subtitle = "Full 990 and 990-EZ filers, excl. hospitals and universities. Share of filers at or below each level.",
       x = "Total expenses (log scale)", y = "Share of filers", colour = NULL) +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
save_chart(chart_d, "chart_d_expense_distribution.png")


# --- E. Reported government grants (line 1e) share of revenue, 2020-2023 ---

government_grants <- arrow::read_parquet(file.path(data_dir, "government_grants.parquet")) |>
  filter(form_type == "990", tax_year %in% 2020:2023) |>
  arrange(desc(filing_receipt_id)) |>
  distinct(ein, tax_year, .keep_all = TRUE) |>
  transmute(ein9 = ein, tax_year, govt_grants = coalesce(government_grants, 0))

panel_charities <- arrow::read_parquet(file.path(data_dir, "panel_charities.parquet"))

grant_share <- panel_charities |>
  filter(tax_year %in% 2020:2023) |>
  inner_join(government_grants, by = c("ein9", "tax_year")) |>
  mutate(group = case_when(grp == "Nashville" & geo_county_fips == davidson_fips ~ "Davidson County",
                           grp == "Peer metros" ~ "Peer metros",
                           grp == "Rest of US" ~ "Rest of US",
                           TRUE ~ NA_character_)) |>
  filter(!is.na(group)) |>
  mutate(human_services = focus == "HMS")

grant_share_table <- bind_rows(
  grant_share |> mutate(population = "All charities"),
  grant_share |> filter(human_services) |> mutate(population = "Human services")
) |>
  group_by(population, group, tax_year) |>
  summarise(filers = n(), share_reporting_1e = round(100 * mean(govt_grants > 0)),
            aggregate_1e_share_of_revenue = round(100 * sum(govt_grants) / sum(rev_total, na.rm = TRUE), 1),
            .groups = "drop")

cat("\n== E. Line 1e government grants as a share of total revenue, full-990 charities excl. hospitals and universities ==\n")
print(as.data.frame(grant_share_table))
write.csv(grant_share_table, file.path(output_dir, "chart_e_govt_grant_share_2020_2023.csv"), row.names = FALSE)

chart_e <- ggplot(grant_share_table, aes(tax_year, aggregate_1e_share_of_revenue, colour = group)) +
  geom_line(linewidth = 0.9) + geom_point() +
  facet_wrap(~ population) +
  labs(title = "Reported government grants (Form 990 line 1e) as a share of total revenue",
       subtitle = "Full-990 501(c)(3) charities excl. hospitals and universities.\nGrants only; contracts and reimbursements are not on this line.",
       x = "Tax year", y = "Percent of revenue", colour = NULL) +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
save_chart(chart_e, "chart_e_govt_grant_share.png", width = 9)


# --- F. Filers, real spending, employees, 2019-2023, indexed ---------------

workforce <- panel_charities |>
  filter(tax_year %in% 2019:2023, grp == "Nashville", geo_county_fips == davidson_fips) |>
  group_by(tax_year) |>
  summarise(filers = n(), spending_2023_dollars = sum(exp_total * deflator, na.rm = TRUE),
            employees = sum(employees, na.rm = TRUE), .groups = "drop") |>
  mutate(across(c(filers, spending_2023_dollars, employees), ~ round(100 * .x / .x[tax_year == 2019], 1), .names = "{.col}_index"))

cat("\n== F. Davidson full-990 charities excl. hospitals and universities, 2019-2023 (index 2019 = 100) ==\n")
print(as.data.frame(workforce))

# Sensitivity: the same organizations in both 2019 and 2023 (balanced), and
# the 2019 to 2022 endpoint, because the 2023 e-file release is incomplete
# and the filer population changes.
davidson_panel <- panel_charities |> filter(grp == "Nashville", geo_county_fips == davidson_fips)
balanced_change <- function(end_year) {
  in_both <- davidson_panel |> filter(tax_year %in% c(2019, end_year)) |> count(ein9) |> filter(n == 2) |> pull(ein9)
  davidson_panel |> filter(ein9 %in% in_both, tax_year %in% c(2019, end_year)) |>
    group_by(tax_year) |> summarise(organizations = n(), employees = sum(employees, na.rm = TRUE),
                                    spending_2023_dollars = sum(exp_total * deflator, na.rm = TRUE), .groups = "drop") |>
    mutate(endpoint = end_year)
}
workforce_sensitivity <- bind_rows(balanced_change(2023), balanced_change(2022)) |>
  group_by(endpoint) |>
  summarise(organizations = first(organizations),
            employees_change_pct = round(100 * (last(employees) / first(employees) - 1), 1),
            spending_change_pct = round(100 * (last(spending_2023_dollars) / first(spending_2023_dollars) - 1), 1), .groups = "drop")
cat("\n== F2. Same organizations in both years (balanced): change from 2019 ==\n")
print(as.data.frame(workforce_sensitivity))
write.csv(workforce_sensitivity, file.path(output_dir, "chart_f_balanced_sensitivity.csv"), row.names = FALSE)
write.csv(workforce, file.path(output_dir, "chart_f_filers_spending_employees.csv"), row.names = FALSE)

chart_f <- workforce |>
  select(tax_year, Filers = filers_index, `Spending (2023 dollars)` = spending_2023_dollars_index,
         `Reported employees` = employees_index) |>
  tidyr::pivot_longer(-tax_year, names_to = "series", values_to = "index") |>
  ggplot(aes(tax_year, index, colour = series)) +
  geom_line(linewidth = 0.9) + geom_point() +
  geom_hline(yintercept = 100, linetype = "dotted") +
  labs(title = "Davidson County full-990 charities: filers, spending and employees",
       subtitle = "501(c)(3) excl. hospitals and universities; e-file release; index 2019 = 100.\nEmployee counts on the 990 are noisy.",
       x = "Tax year", y = "Index (2019 = 100)", colour = NULL) +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
save_chart(chart_f, "chart_f_filers_spending_employees.png")

cat("\ncharts written to output/: chart_b, chart_c, chart_d, chart_e, chart_f (PNG) with CSV tables\n")
