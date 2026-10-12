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

core <- bind_rows(lapply(2019:2023, function(y) {
  x <- nccsdata::nccs_read_core(tier = "merged", tax_year = y, form = "990combined",
                                columns = c("ein", "tax_year", "source_form", "tax_period", "total_expenses"), confirm = FALSE)
  record_pin(req, "core-merged-990combined", vintage = as.character(y), source = nccsdata::nccs_core_url("merged", y, "990combined"),
             n_rows = nrow(x), note = "TY2023 coverage comparison")
  x
})) |> mutate(ein9 = gsub("-", "", ein)) |> arrange(ein9, tax_year, desc(tax_period)) |> distinct(ein9, tax_year, .keep_all = TRUE)

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
