# Pass 7: government grants dependence (e-file Phase 0, TY2020-2023).
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
source(here::here("R", "request_read.R"))
d <- file.path(req, "data")
gg <- arrow::read_parquet(file.path(d, "government_grants.parquet")) |>
  filter(form_type == "990", tax_year %in% 2020:2023) |>
  arrange(desc(filing_receipt_id)) |> distinct(ein, tax_year, .keep_all = TRUE) |>
  transmute(ein9 = ein, tax_year, govt_grants = government_grants)
record_pin(req, "efile-phase0-government_grants", vintage = "v2026.06 (latest)",
           source = "https://nccsdata.s3.amazonaws.com/processed/efile/phase0/latest/government_grants.parquet",
           n_rows = nrow(gg), note = "Form 990 only, TY2020-2023, one row per EIN x tax year")
p <- arrow::read_parquet(file.path(d, "panel_charities.parquet")) |> filter(tax_year >= 2020) |>
  left_join(gg, by = c("ein9", "tax_year")) |>
  mutate(grp = case_when(metro == "Nashville" ~ "Nashville", state == "TN" ~ "Rest of TN", TRUE ~ "Rest of US"),
         gg0 = coalesce(govt_grants, 0), has_gg = gg0 > 0,
         gg_share = ifelse(rev_total > 0, pmin(gg0 / rev_total, 1), NA),
         where = ifelse(geo_county_fips == "47037", "Davidson", "Collar"))
cat("match rate of panel rows to phase0:", round(100 * mean(!is.na(p$govt_grants) | TRUE)), "\n")
cat("rows with govt_grants NA (not reported):", round(100 * mean(is.na(p$govt_grants))), "%\n")

s <- function(df, ...) df |> group_by(...) |>
  summarise(filers = n(), share_with_gg = round(100 * mean(has_gg)),
            gg_m = round(sum(gg0) / 1e6), agg_gg_share_rev = round(100 * sum(gg0) / sum(rev_total, na.rm = TRUE), 1),
            med_share_among_recipients = round(100 * median(gg_share[has_gg], na.rm = TRUE)),
            reliant_25pct = round(100 * mean(gg_share >= 0.25, na.rm = TRUE)),
            reliant_50pct = round(100 * mean(gg_share >= 0.5, na.rm = TRUE)), .groups = "drop")
cat("\n== By group and year ==\n"); print(s(p, grp, tax_year) |> as.data.frame())
cat("\n== 2023 by subsector: Nashville vs Rest of US ==\n")
print(s(p |> filter(tax_year == 2023, grp != "Rest of TN"), grp, focus) |> filter(filers >= 30) |> arrange(focus, grp) |> as.data.frame())
cat("\n== 2023 Nashville by county ==\n")
print(s(p |> filter(tax_year == 2023, grp == "Nashville"), geo_county_fips) |> arrange(-filers) |> as.data.frame())
cat("\n== 2023 Nashville human services: Davidson vs collar ==\n")
print(s(p |> filter(tax_year == 2023, grp == "Nashville", focus == "HMS"), where) |> as.data.frame())
cat("\n== Peer metros 2023 ==\n")
print(s(p |> filter(tax_year == 2023), metro) |> arrange(-agg_gg_share_rev) |> as.data.frame())
cat("\n== Nashville 2023: top 15 government grant recipients ==\n")
print(p |> filter(tax_year == 2023, grp == "Nashville") |> arrange(-gg0) |> transmute(org_name, focus, county = geo_county_fips, gg_m = round(gg0 / 1e6, 1), share = round(100 * gg_share)) |> head(15) |> as.data.frame())
cat("\n== Nashville: deficit and reserves, government-reliant (>=25%) vs not, 2023 ==\n")
print(p |> filter(tax_year == 2023, grp %in% c("Nashville", "Rest of US")) |> mutate(reliant = gg_share >= 0.25) |> group_by(grp, reliant) |>
  summarise(n = n(), deficit = round(100 * mean(deficit, na.rm = TRUE)), under3mo = round(100 * mean(months_reserve < 3, na.rm = TRUE)), med_res = round(median(months_reserve, na.rm = TRUE), 1), .groups = "drop") |> as.data.frame())
