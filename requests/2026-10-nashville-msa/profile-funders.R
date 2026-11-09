# Pass 15: who funded whom among the requester's listed organizations,
# tax years 2019 to 2023. Nashville-based funders only (the build-funders.R
# extract: funders whose registry address is in Davidson County) giving to
# listed organizations matched in explore-14. Grants to individuals are
# excluded. Cash and noncash are kept separate.
#
# Two match routes. Schedule I rows carry the recipient EIN, so the match
# is exact. 990-PF rows carry only a name and city, so the match is on a
# cleaned name against the 126 matched listed names (and their registry
# names), restricted to Tennessee recipient cities, and every PF name pair
# is written out for a hand check.
#
# Scope: recipients are the listed organizations whose registry address is
# in Davidson County (the requester narrowed the funder piece to
# Nashville-based funders giving to Nashville-based listed organizations).
# Listed organizations registered elsewhere are counted separately.
#
# Reading the result: a shared funder is a shared funder, not duplication;
# a listed organization with no matched grant may be funded by funders based
# outside Davidson, below the Schedule I itemization threshold ($5,000 in
# aggregate), or under a name the match missed. Donor-advised fund grants
# appear under the sponsoring organization.
#
# Outputs:
#   data/funders_to_listed_grants.csv   grant-level rows (names: private)
#   data/funders_to_listed_pf_name_pairs.csv  PF name matches for hand check
#   output/explore-15-funders-listed.txt       counts and aggregates only

library(dplyr)

request_dir <- here::here("requests", "2026-10-nashville-msa")
data_dir <- file.path(request_dir, "data")

grants <- arrow::read_parquet(file.path(data_dir, "funders_davidson_2019_2023.parquet")) |>
  filter(!recipient_is_individual)

davidson_ein9 <- arrow::read_parquet(file.path(data_dir, "universe_tn.parquet")) |>
  filter(geo_county_fips == "47037") |>
  pull(ein9)

listed_all <- read.csv(file.path(data_dir, "list_matched.csv"),
                       colClasses = "character", na.strings = "") |>
  filter(!is.na(ein9)) |>
  select(row_id, listed_name = name, org_type, ein9, registry_name = org_name_display,
         match_confidence = confidence) |>
  mutate(registered_in_davidson = ein9 %in% davidson_ein9)

listed <- listed_all |> filter(registered_in_davidson)
cat("listed organizations matched to an EIN:", nrow(listed_all),
    "; registered in Davidson County and in scope:", nrow(listed), "\n")

clean_name <- function(x) {
  x <- tolower(x)
  x <- gsub("[^a-z0-9 ]", " ", iconv(x, to = "ASCII//TRANSLIT"))
  x <- gsub("\\b(inc|incorporated|the|of|and|corp|corporation|co|foundation|fdn)\\b", " ", x)
  trimws(gsub(" +", " ", x))
}


# --- 1. Schedule I: exact EIN match ------------------------------------------

# The EIN the funder wrote on Schedule I takes precedence; the provisional
# name-and-city match from build-funders.R is used only where no nine-digit
# EIN was supplied (second-analyst review, 2026-10-29).
schedule_i_hits <- grants |>
  filter(source_table == "Schedule I Part II (full 990)") |>
  mutate(recipient_key = if_else(!is.na(recipient_ein9) & nchar(recipient_ein9) == 9,
                                 recipient_ein9, recipient_ein9_matched),
         match_route = if_else(!is.na(recipient_ein9) & nchar(recipient_ein9) == 9,
                               "Schedule I, recipient EIN as filed",
                               "Schedule I, recipient name and city (provisional)")) |>
  inner_join(listed |> rename(listed_ein9 = ein9), by = c("recipient_key" = "listed_ein9")) |>
  mutate(ein9 = recipient_key)


# --- 2. 990-PF: name match against the listed names ------------------------

listed_keys <- listed |>
  mutate(key_listed = listed_name, key_registry = registry_name) |>
  tidyr::pivot_longer(c(key_listed, key_registry), names_to = "key_source",
                      values_to = "key_name") |>
  filter(!is.na(key_name)) |>
  mutate(key_clean = clean_name(key_name)) |>
  filter(nchar(key_clean) >= 6) |>
  distinct(ein9, key_clean, .keep_all = TRUE)

pf_rows <- grants |>
  filter(source_table == "990-PF grants paid", recipient_in_tennessee %in% TRUE) |>
  mutate(recipient_clean = clean_name(recipient_name))

# Hand-check exclusions (2026-10-29): a same-named organization in another
# town, and a separate supporting foundation that shares the operating
# organization's name.
pf_false_positives <- tibble::tribble(
  ~recipient_name,              ~recipient_city,
  "COMMUNITY RESOURCE CENTER",  "PEGRAM",
  "CENTERSTONE FOUNDATION",     "NASHVILLE"
)

pf_name_pairs <- pf_rows |>
  distinct(recipient_name, recipient_clean, recipient_city) |>
  anti_join(pf_false_positives, by = c("recipient_name", "recipient_city")) |>
  inner_join(listed_keys |> select(ein9, key_clean, listed_name), by = c("recipient_clean" = "key_clean")) |>
  distinct(recipient_name, recipient_city, ein9, listed_name)

write.csv(pf_name_pairs, file.path(data_dir, "funders_to_listed_pf_name_pairs.csv"), row.names = FALSE)

pf_hits <- pf_rows |>
  inner_join(pf_name_pairs |> select(recipient_name, recipient_city, ein9), by = c("recipient_name", "recipient_city")) |>
  inner_join(listed, by = "ein9") |>
  mutate(match_route = "990-PF, recipient name (exact after cleaning)")


# --- 3. Combine, aggregate ---------------------------------------------------

# 990-PF grants paid carry one amount with no cash/noncash split; build-funders
# stored it as amount_cash. amount_total is the comparable column across
# both sources; cash and noncash are meaningful for Schedule I rows only.
hits <- bind_rows(schedule_i_hits, pf_hits) |>
  mutate(amount_total = coalesce(amount_cash, 0) + coalesce(amount_noncash, 0)) |>
  mutate(listed_recipient_is_funder = ein9 %in% grants$funder_ein9,
         funder_is_listed = funder_ein9 %in% listed$ein9) |>
  select(match_route, source_table, tax_year, funder_ein9, funder_name, funder_name_registry,
         funder_is_private_foundation, funder_is_listed, recipient_row_id = row_id,
         recipient_listed_name = listed_name, recipient_type = org_type, recipient_ein9 = ein9,
         amount_total, amount_cash, amount_noncash, purpose, match_confidence)

stopifnot(!any(is.na(hits$recipient_ein9)))

write.csv(hits, file.path(data_dir, "funders_to_listed_grants.csv"), row.names = FALSE, na = "")

cat("== Grant rows from Davidson-based funders to listed organizations, TY2019-2023 ==\n")
print(hits |> count(match_route, tax_year) |> tidyr::pivot_wider(names_from = tax_year, values_from = n, values_fill = 0) |> as.data.frame())
cat("PF name pairs written for hand check:", nrow(pf_name_pairs), "\n")

cat("\n== Totals by year ($ millions; Schedule I cash and noncash separate, 990-PF a single amount) ==\n")
print(hits |> group_by(tax_year) |>
        summarise(grant_rows = n(), funders = n_distinct(funder_ein9), recipients = n_distinct(recipient_ein9),
                  total_m = round(sum(amount_total) / 1e6, 2),
                  schedule_i_cash_m = round(sum(amount_cash[source_table != "990-PF grants paid"], na.rm = TRUE) / 1e6, 2),
                  schedule_i_noncash_m = round(sum(amount_noncash[source_table != "990-PF grants paid"], na.rm = TRUE) / 1e6, 2),
                  pf_amount_m = round(sum(amount_total[source_table == "990-PF grants paid"]) / 1e6, 2), .groups = "drop") |> as.data.frame())

cat("\n== Listed organizations reached, by the requester's type ==\n")
reached <- listed |> mutate(reached = ein9 %in% hits$recipient_ein9)
print(reached |> count(org_type, reached) |> tidyr::pivot_wider(names_from = reached, values_from = n, values_fill = 0) |> as.data.frame())
cat("listed organizations registered in Davidson:", nrow(listed), "; with at least one matched grant:", sum(reached$reached), "\n")
cat("listed organizations registered outside Davidson (out of scope, not searched):", sum(!listed_all$registered_in_davidson), "\n")

cat("\n== Funders per recipient (five-year, distinct funders) ==\n")
per_recipient <- hits |> group_by(recipient_ein9) |> summarise(funders = n_distinct(funder_ein9), cash = sum(amount_total), .groups = "drop")
print(summary(per_recipient$funders))
print(per_recipient |> count(funders_band = cut(funders, c(0, 1, 2, 5, 10, 20, 100), labels = c("1", "2", "3-5", "6-10", "11-20", "21+"))) |> as.data.frame())

cat("\n== Recipients per funder (five-year, among listed recipients) ==\n")
per_funder <- hits |> group_by(funder_ein9, funder_is_private_foundation, funder_is_listed) |>
  summarise(recipients = n_distinct(recipient_ein9), cash = sum(amount_total), .groups = "drop")
print(per_funder |> count(funder_is_private_foundation, funder_is_listed, recipients_band = cut(recipients, c(0, 1, 2, 5, 10, 20, 200), labels = c("1", "2", "3-5", "6-10", "11-20", "21+"))) |> as.data.frame())
cat("funders giving to at least one listed organization:", nrow(per_funder),
    "; of which listed themselves:", sum(per_funder$funder_is_listed), "\n")

cat("\n== Concentration: share of matched grant dollars from the top funders ==\n")
top <- per_funder |> arrange(desc(cash)) |> mutate(cum_share = round(100 * cumsum(cash) / sum(cash)))
cat("top 1:", top$cum_share[1], "%  top 3:", top$cum_share[3], "%  top 5:", top$cum_share[5], "%  top 10:", top$cum_share[10], "%\n")

cat("\n== Listed-to-listed giving (both funder and recipient on the list) ==\n")
print(hits |> filter(funder_is_listed) |> group_by(tax_year) |>
        summarise(rows = n(), funders = n_distinct(funder_ein9), recipients = n_distinct(recipient_ein9),
                  total_m = round(sum(amount_total) / 1e6, 2), .groups = "drop") |> as.data.frame())
