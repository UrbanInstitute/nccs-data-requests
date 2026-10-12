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
