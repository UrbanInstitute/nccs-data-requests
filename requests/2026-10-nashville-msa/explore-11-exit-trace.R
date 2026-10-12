# Pass 11: trace the exit cohort. Charities (501(c)(3), excl HOS/UNI) in the
# Nashville metro with paid staff on a full Form 990 for TY2019 that have no
# full Form 990 for TY2023 in the e-file panel. Where did they go?
#   - CORE merged tier (990combined = full 990 + 990-EZ, from IRS SOI
#     extracts, not e-file): did they file anything for TY2021-2024, and on
#     which form?
#   - The e-file panel itself: did they file a full 990 for TY2020-2022?
#   - BMF: are they still registered in 2026?
library(dplyr)
req <- here::here("requests", "2026-10-nashville-msa")
source(here::here("R", "request_read.R"))
d <- file.path(req, "data")
p <- arrow::read_parquet(file.path(d, "panel_charities.parquet"))
panel_all <- arrow::read_parquet(file.path(d, "panel_990_national.parquet"))
tn <- arrow::read_parquet(file.path(d, "universe_tn.parquet"))

nash19 <- p |> filter(grp == "Nashville", tax_year == 2019, employees > 0)
in23 <- p |> filter(tax_year == 2023) |> pull(ein2)
cohort <- nash19 |> mutate(exited = !(ein2 %in% in23), davidson = geo_county_fips == "47037") |>
  select(ein2, ein9, org_name, focus, davidson, exited, employees_2019 = employees, rev_2019 = rev_total, exp_2019 = exp_total, pay_2019 = pay_per_emp_real)
cat("cohort:", nrow(cohort), "staffed 2019 filers;", sum(cohort$exited), "exited\n")

# e-file panel presence by year
pres <- panel_all |> filter(ein2 %in% cohort$ein2, tax_year %in% 2020:2023) |> distinct(ein2, tax_year) |> mutate(v = TRUE) |>
  tidyr::pivot_wider(names_from = tax_year, values_from = v, names_prefix = "efile_", values_fill = FALSE)
cohort <- cohort |> left_join(pres, by = "ein2") |> mutate(across(starts_with("efile_"), ~ coalesce(.x, FALSE)))

# CORE merged tier, 990combined, TY2021-2024
core <- bind_rows(lapply(2021:2024, function(y) {
  x <- nccsdata::nccs_read_core(tier = "merged", tax_year = y, form = "990combined",
                                columns = c("ein", "tax_year", "source_form", "total_revenue", "total_expenses", "tax_period"), confirm = FALSE)
  record_pin(req, "core-merged-990combined", vintage = as.character(y), source = nccsdata::nccs_core_url("merged", y, "990combined"),
             n_rows = nrow(x), note = "exit-cohort trace")
  x
})) |> mutate(ein9 = gsub("-", "", ein))
cat("CORE EIN sample:", head(core$ein, 2), " source_form values:", paste(names(table(core$source_form)), collapse = ", "), "\n")

core_c <- core |> filter(ein9 %in% cohort$ein9) |> arrange(ein9, tax_year, desc(tax_period)) |> distinct(ein9, tax_year, .keep_all = TRUE)
core_wide <- core_c |> select(ein9, tax_year, source_form) |> tidyr::pivot_wider(names_from = tax_year, values_from = source_form, names_prefix = "core_")
core_rev23 <- core_c |> filter(tax_year == 2023) |> select(ein9, rev_2023_core = total_revenue, form_2023 = source_form)
cohort <- cohort |> left_join(core_wide, by = "ein9") |> left_join(core_rev23, by = "ein9") |>
  left_join(tn |> select(ein9, last_year_in_bmf), by = "ein9")

cohort <- cohort |> mutate(
  status = case_when(
    !exited ~ "stayed (full 990 TY2023 in e-file)",
    !is.na(core_2023) & grepl("EZ", core_2023, ignore.case = TRUE) ~ "switched to 990-EZ (CORE TY2023)",
    !is.na(core_2023) ~ "full 990 TY2023 in CORE, missing from e-file release",
    !is.na(core_2024) ~ "no TY2023 return; filed TY2024",
    efile_2022 | !is.na(core_2022) ~ "last return TY2022 (late or stopped)",
    efile_2021 | !is.na(core_2021) ~ "last return TY2021",
    last_year_in_bmf < 2026 ~ "no return since TY2020 and dropped from BMF",
    TRUE ~ "no return since TY2020, still registered in BMF"))

cat("\n== Exit cohort status, metro and Davidson ==\n")
print(cohort |> filter(exited) |> count(status, sort = TRUE) |> as.data.frame())
print(cohort |> filter(exited, davidson) |> count(status, sort = TRUE) |> as.data.frame())

cat("\n== 2019 pay per head and size by status (metro) ==\n")
print(cohort |> group_by(status) |> summarise(n = n(), n_pay = sum(!is.na(pay_2019)), med_pay_2019 = round(median(pay_2019, na.rm = TRUE)),
  med_employees_2019 = median(employees_2019), med_rev_2019_k = round(median(rev_2019, na.rm = TRUE) / 1e3), med_rev_2023_core_k = round(median(rev_2023_core, na.rm = TRUE) / 1e3)) |> arrange(-n) |> as.data.frame())

cat("\n== Exiters: pay gap vs stayers after removing those that merely switched to the 990-EZ or appear in CORE ==\n")
stay <- cohort |> filter(!exited) |> pull(pay_2019)
for (g in unique(cohort$status[cohort$exited])) {
  x <- cohort$pay_2019[cohort$status == g]
  cat(sprintf("%-60s n=%3d med=%6.0f gap vs stayers=%6.0f\n", g, sum(!is.na(x)), median(x, na.rm = TRUE), median(x, na.rm = TRUE) - median(stay, na.rm = TRUE)))
}
truly_gone <- cohort |> filter(exited, !grepl("EZ|CORE|TY2024", status))
cat(sprintf("\nExiters with no TY2023 or TY2024 return anywhere: n=%d, median 2019 pay %.0f vs stayers %.0f (n=%d)\n",
            sum(!is.na(truly_gone$pay_2019)), median(truly_gone$pay_2019, na.rm = TRUE), median(stay, na.rm = TRUE), sum(!is.na(stay))))

cat("\n== Peer metros and Rest of US: same classification using CORE only (share of exiters that filed a 990-EZ in TY2023) ==\n")
for (g in c("Peer metros", "Rest of US")) {
  x19 <- p |> filter(grp == g, tax_year == 2019, employees > 0) |> mutate(exited = !(ein2 %in% in23))
  ex <- x19 |> filter(exited) |> select(ein9, pay_2019 = pay_per_emp_real)
  cw <- core |> filter(ein9 %in% ex$ein9, tax_year == 2023) |> distinct(ein9, .keep_all = TRUE) |> select(ein9, form_2023 = source_form)
  ex <- ex |> left_join(cw, by = "ein9") |> mutate(status = case_when(grepl("EZ", form_2023, ignore.case = TRUE) ~ "990-EZ TY2023", !is.na(form_2023) ~ "full 990 TY2023 in CORE", TRUE ~ "no TY2023 return in CORE"))
  print(ex |> group_by(status) |> summarise(n = n(), share = round(100 * n() / nrow(ex)), med_pay_2019 = round(median(pay_2019, na.rm = TRUE))) |> mutate(group = g) |> as.data.frame())
}

utils::write.csv(cohort |> filter(exited) |> select(org_name, focus, davidson, status, employees_2019, rev_2019, pay_2019, rev_2023_core, last_year_in_bmf),
                 file.path(req, "output", "exit_cohort_trace.csv"), row.names = FALSE)
