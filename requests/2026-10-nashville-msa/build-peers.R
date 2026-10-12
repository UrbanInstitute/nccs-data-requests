# Peer-metro universes: read the BMF master for the states hosting the
# comparison metros and keep EIN -> CBSA / county / subsector.
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
source(here::here("R", "request_read.R"))
out_dir <- file.path(req, "data")

peer_cbsas <- c(
  "34980" = "Nashville", "32820" = "Memphis", "28940" = "Knoxville",
  "12420" = "Austin", "16740" = "Charlotte", "39580" = "Raleigh",
  "26900" = "Indianapolis", "31140" = "Louisville", "18140" = "Columbus",
  "28140" = "Kansas City", "27260" = "Jacksonville", "36420" = "Oklahoma City",
  "12060" = "Atlanta", "19740" = "Denver", "41180" = "St. Louis",
  "17140" = "Cincinnati", "40060" = "Richmond", "13820" = "Birmingham",
  "41700" = "San Antonio", "38060" = "Phoenix"
)

xwalk_cbsa   <- arrow::read_parquet(file.path(out_dir, "cbsa_crosswalk.parquet"))
xwalk_county <- arrow::read_parquet(file.path(out_dir, "county_fips_crosswalk.parquet"))

peer_counties <- xwalk_cbsa |> filter(cbsa_code %in% names(peer_cbsas))
peer_states <- unique(xwalk_county$geo_state_abbr[xwalk_county$geo_county_fips %in% peer_counties$county_fips])
cat("states:", peer_states, "\n")

bmf_manifest <- jsonlite::fromJSON("https://nccsdata.s3.amazonaws.com/geocoding/unified-bmf/latest/_manifest.json")
bmf_identity <- sprintf("vintage %s, git %s, sha256 %s", bmf_manifest$vintage, bmf_manifest$git_sha,
                        bmf_manifest$files$bmf_unified_geocoded.parquet$sha256)
bmf <- read_bmf_master(
  req, state = peer_states, cache = FALSE,
  columns = c("ein", "geo_state_abbr", "geo_county", "subsection_code",
              "foundation_code", "nteev2_subsector", "nteev2_code", "ntee_code_clean",
              "first_year_in_bmf", "last_year_in_bmf", "ruling_date"),
  note = paste("peer-metro states for CBSA benchmarking;", bmf_identity)
)

peers <- bmf |>
  left_join(xwalk_county, by = c("geo_state_abbr", "geo_county" = "geo_county_raw")) |>
  left_join(xwalk_cbsa, by = c("geo_county_fips" = "county_fips")) |>
  filter(cbsa_code %in% names(peer_cbsas)) |>
  mutate(metro = peer_cbsas[cbsa_code], ein9 = gsub("-", "", ein))

arrow::write_parquet(peers, file.path(out_dir, "universe_peers.parquet"))
print(peers |> filter(last_year_in_bmf >= 2026) |> count(metro, sort = TRUE) |> as.data.frame())
