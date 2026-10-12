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
