# Independent review. Run with Rscript review-foundations.R from this folder.
suppressPackageStartupMessages(library(dplyr))
prepare_universe <- function(path) {
  arrow::read_parquet(path) |>
    dplyr::mutate(
      ruling_year = as.integer(format(ruling_date, "%Y")),
      pf = as.integer(subsection_code) == 3 &
        foundation_code %in% c("02", "03", "04", "2", "3", "4"),
      period = cut(ruling_year, c(2009, 2014, 2019, 2022, 2026),
        labels = c("2010-14", "2015-19", "2020-22", "2023-26")))
}
tennessee <- prepare_universe("../data/universe_tn.parquet")
peers <- prepare_universe("../data/universe_peers.parquet")
davidson_all <- tennessee |> dplyr::filter(pf, county_name == "Davidson County")
davidson <- davidson_all |> dplyr::filter(last_year_in_bmf >= 2026)
cat("Davidson stock:", nrow(davidson), "\n")
print(davidson |> dplyr::count(period, .drop = FALSE))
print(davidson |> dplyr::filter(ruling_year >= 2015) |> dplyr::count(ruling_year), n = Inf)
cat("Latest year:", max(tennessee$last_year_in_bmf), "\n")
cat("TN and peer duplicate EIN:", anyDuplicated(tennessee$ein), anyDuplicated(peers$ein), "\n")
cat("PF storage, all TN:\n")
print(tennessee |> dplyr::filter(pf) |> dplyr::count(foundation_code))
cat("Davidson code counts:\n")
print(davidson |> dplyr::count(foundation_code))
cat("Dates, all Davidson PF and current subset:\n")
date_diagnostics <- function(data) {
  data |> dplyr::summarise(rows = dplyr::n(), missing = sum(is.na(ruling_date)),
    before_1900 = sum(ruling_year < 1900, na.rm = TRUE),
    after_2026 = sum(ruling_year > 2026, na.rm = TRUE),
    earliest = min(ruling_date, na.rm = TRUE), latest = max(ruling_date, na.rm = TRUE))
}
print(date_diagnostics(davidson_all)); print(date_diagnostics(davidson))
print(davidson |> dplyr::filter(ruling_year == 2026) |> dplyr::count(ruling_date))
cat("Year parsing agreement:", identical(davidson$ruling_year,
  as.integer(substr(as.character(davidson$ruling_date), 1, 4))), "\n")
cat("County identities:\n")
print(davidson |> dplyr::count(geo_county, geo_county_canonical, county_name, geo_county_fips))
cat("Available address and county fields:\n")
print(names(tennessee)[grepl("county|addr", names(tennessee))])
cat("Sensitivity counts:\n")
print(data.frame(definition = c("baseline", "all observed years", "code 04 only",
  "codes 02/03 only", "no subsection restriction", "Nashville metro"),
  n = c(nrow(davidson), nrow(davidson_all), sum(davidson$foundation_code %in% c("4", "04")),
    sum(davidson$foundation_code %in% c("2", "3", "02", "03")),
    nrow(tennessee |> dplyr::filter(foundation_code %in% c("2", "3", "4", "02", "03", "04"),
      last_year_in_bmf >= 2026, county_name == "Davidson County")),
    nrow(tennessee |> dplyr::filter(pf, last_year_in_bmf >= 2026, cbsa_code == "34980")))))
active_peers <- peers |> dplyr::filter(pf, last_year_in_bmf >= 2026) |>
  dplyr::mutate(g = ifelse(metro == "Nashville", "Nashville", "Peers"))
cat("Original period table reproduced:\n")
original <- active_peers |> dplyr::filter(ruling_year >= 2010) |>
  dplyr::count(g, period) |> dplyr::group_by(g) |>
  dplyr::mutate(pct = round(100 * n / sum(n))) |> dplyr::ungroup()
print(original)
cat("Correct full-stock denominators:\n")
stocks <- active_peers |> dplyr::count(g, name = "stock")
correct <- original |> dplyr::left_join(stocks, by = "g") |>
  dplyr::mutate(pct_stock = round(100 * n / stock, 2))
print(correct)
cat("Per-metro stock and period counts:\n")
metro_counts <- active_peers |> dplyr::group_by(metro) |>
  dplyr::summarise(stock = dplyr::n(),
    n_2010_14 = sum(period == "2010-14", na.rm = TRUE),
    n_2015_19 = sum(period == "2015-19", na.rm = TRUE),
    n_2020_22 = sum(period == "2020-22", na.rm = TRUE),
    n_2023_26 = sum(period == "2023-26", na.rm = TRUE),
    n_2022 = sum(ruling_year == 2022, na.rm = TRUE),
    n_2023 = sum(ruling_year == 2023, na.rm = TRUE),
    n_2024 = sum(ruling_year == 2024, na.rm = TRUE),
    n_2025 = sum(ruling_year == 2025, na.rm = TRUE),
    n_2026 = sum(ruling_year == 2026, na.rm = TRUE))
print(as.data.frame(metro_counts))
utils::write.csv(metro_counts, "../output/review-foundations-metros.csv", row.names = FALSE)
period_shares <- active_peers |> dplyr::count(metro, period, .drop = FALSE) |>
  dplyr::left_join(metro_counts |> dplyr::select(metro, stock), by = "metro") |>
  dplyr::mutate(pct_stock = 100 * n / stock)
utils::write.csv(period_shares, "../output/review-foundations-period-shares.csv", row.names = FALSE)
cat("Pooled annual counts:\n")
print(active_peers |> dplyr::filter(ruling_year >= 2019) |> dplyr::count(g, ruling_year), n = Inf)
# Fast detector for the misleading denominator in the original table.
stopifnot(all(tapply(original$n, original$g, sum) < stocks$stock[match(names(tapply(original$n, original$g, sum)), stocks$g)]))
stopifnot(nrow(davidson) == dplyr::n_distinct(davidson$ein),
  sum(is.na(davidson$ruling_date)) == 0, max(tennessee$last_year_in_bmf) == 2026)
if (file.exists("../data/review_foundations_vintage_evidence.parquet")) {
  evidence <- arrow::read_parquet("../data/review_foundations_vintage_evidence.parquet")
  monthly <- davidson |> dplyr::left_join(evidence, by = "ein")
  cat("Monthly evidence from the pinned September build (latest observed month is July):\n")
  print(monthly |> dplyr::count(last_vintage_ym, status_code))
  latest_month <- max(evidence$last_vintage_ym)
  print(monthly |> dplyr::filter(last_vintage_ym == latest_month) |> dplyr::count(period))
  print(monthly |> dplyr::filter(last_vintage_ym == latest_month, ruling_year >= 2015) |> dplyr::count(ruling_year), n = Inf)
  stopifnot(sum(monthly$last_vintage_ym == latest_month) == 397)
}
cat("Latest ruling dates in each universe:\n")
print(max(tennessee$ruling_date, na.rm = TRUE)); print(max(peers$ruling_date, na.rm = TRUE))
cat("Davidson earliest BMF observation 2023 onward:", sum(davidson$first_year_in_bmf >= 2023), "\n")
cat("Input SHA256:\n")
paths <- c("../data/universe_tn.parquet", "../data/universe_peers.parquet")
print(data.frame(path = paths, sha256 = vapply(paths, function(path) {
  connection <- file(path, "rb"); on.exit(close(connection));
  as.character(openssl::sha256(connection))
}, character(1))))
cat("Session:\n"); print(sessionInfo())
