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
