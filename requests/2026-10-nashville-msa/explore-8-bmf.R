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

cat("\n== Private foundation formation by year, Nashville vs peers (share of each metro's PF stock) ==\n")
print(peers |> filter(pf, last_year_in_bmf >= 2026, ruling_year >= 2010) |> mutate(g = ifelse(metro == "Nashville", "Nashville", "Peers"), period = cut(ruling_year, c(2009, 2014, 2019, 2022, 2026), labels = c("2010-14", "2015-19", "2020-22", "2023-26"))) |>
  count(g, period) |> group_by(g) |> mutate(pct = round(100 * n / sum(n))) |> as.data.frame())

cat("\n== Davidson zip codes: charities active 2026, ranked by number ruled 2020+ (current address, not address at founding) ==\n")
z <- nash |> filter(charity, geo_county_fips == "47037", last_year_in_bmf >= 2026) |> group_by(zip = org_addr_zip5) |>
  summarise(n = n(), ruled_2020plus = sum(ruling_year >= 2020, na.rm = TRUE), hms_all = sum(focus == "HMS"), hms_ruled_2020plus = sum(focus == "HMS" & ruling_year >= 2020, na.rm = TRUE),
            orgs_assets_over_10m = sum(asset_amount >= 1e7, na.rm = TRUE), assets_m = round(sum(asset_amount, na.rm = TRUE) / 1e6)) |> filter(n >= 40) |> arrange(-ruled_2020plus)
print(as.data.frame(z))

cat("\n== Attrition by subsector, Nashville vs peers: of charities active 2019, share gone by 2026 ==\n")
print(peers |> filter(charity, first_year_in_bmf <= 2019, last_year_in_bmf >= 2019) |> mutate(g = ifelse(metro == "Nashville", "Nashville", "Peers")) |>
  group_by(g, focus) |> summarise(n = n(), gone = round(100 * mean(last_year_in_bmf < 2026)), .groups = "drop") |>
  tidyr::pivot_wider(names_from = g, values_from = c(n, gone)) |> as.data.frame())
