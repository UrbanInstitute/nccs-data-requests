# build.R — pull BMF + CORE + e-file and write small aggregate CSVs to out/.
# Run from the repo root:  Rscript requests/2026-09-new-vs-established-nonprofits/build.R
# Every read is pinned to _pins.csv by the helpers in R/request_read.R.
suppressMessages({ library(dplyr); library(arrow); library(data.table); library(nccsdata) })
source(here::here("R", "request_read.R"))
req <- here::here("requests", "2026-09-new-vs-established-nonprofits")
out <- file.path(req, "out"); dir.create(out, showWarnings = FALSE)
options(arrow.unsafe_metadata = TRUE)

age_group <- function(age) {
  cut(age, breaks = c(-Inf, 4, 9, 19, 29, Inf),
      labels = c("0-4", "5-9", "10-19", "20-29", "30+"), right = TRUE)
}
# Hospitals (NTEE E20-E24) and higher education (B40-B59) dominate sector dollars.
flag_hosp_hied <- function(ntee) {
  n2 <- substr(ntee, 1, 2)
  !is.na(ntee) & (n2 == "E2" | n2 %in% c("B4", "B5"))
}

# ---- BMF: one row per EIN, ruling date + NTEE ---------------------------------
message("BMF ...")
bmf <- read_bmf_master(req, note = "full registry; ruling_date, NTEE, subsection")
bmf <- as.data.table(bmf)[, .(ein, ruling_date, ntee_code_clean, ntee_code_major_group,
                              subsection_code, foundation_code, income_amount, last_year_in_bmf)]
bmf[, ruling_year := as.integer(format(as.Date(ruling_date), "%Y"))]
bmf[ruling_year <= 1900, ruling_year := NA_integer_]
bmf[, hosp_hied := flag_hosp_hied(ntee_code_clean)]
bmf[, is_c3 := subsection_code %in% c("03", "3", 3L)]
message(sprintf("BMF rows %s; ruling_year missing %s", nrow(bmf), sum(is.na(bmf$ruling_year))))
print(table(bmf$subsection_code)[1:10])

# Entry series: registered orgs by ruling year (survivor-biased: only EINs still
# in the current BMF; auto-revoked orgs are gone unless reinstated).
fwrite(bmf[!is.na(ruling_year), .(n_all = .N, n_c3 = sum(is_c3)), by = ruling_year][order(ruling_year)],
       file.path(out, "bmf_rulings_by_year.csv"))

# ---- CORE: one row per filing, 1989-2023 -------------------------------------
message("CORE ...")
core_cols <- c("ein", "tax_year", "tax_period", "total_expenses", "total_revenue", "subsection_cd")
core <- read_core(req, tier = "merged", tax_year = 1989:2023, form = "990combined",
                  columns = core_cols, confirm = FALSE,
                  note = "990 + 990-EZ, all subsections, 1989-2023")
core <- as.data.table(core)
core <- core[!is.na(total_expenses) & total_expenses > 0]
setorder(core, ein, tax_year, -tax_period)
core <- core[, .SD[1], by = .(ein, tax_year)]           # one row per EIN x tax year
core[, first_core_year := min(tax_year), by = ein]      # first appearance in the panel
core <- merge(core, bmf[, .(ein, ruling_year, hosp_hied, is_c3)], by = "ein", all.x = TRUE)
core[, age_ruling := tax_year - ruling_year]
core[, in_bmf := !is.na(hosp_hied)]
core[is.na(hosp_hied), hosp_hied := FALSE]
core[, age_first := tax_year - first_core_year]
message(sprintf("CORE filings %s; unmatched to BMF %s; ruling postdates tax year %s",
                nrow(core), sum(!core$in_bmf), sum(core$age_ruling < 0, na.rm = TRUE)))

# Match/coverage diagnostics per year
fwrite(core[, .(filers = .N, exp_total = sum(total_expenses),
                unmatched_bmf = sum(!in_bmf), exp_unmatched = sum(total_expenses[!in_bmf]),
                ruling_missing = sum(in_bmf & is.na(age_ruling)),
                ruling_postdates = sum(age_ruling < 0, na.rm = TRUE),
                exp_ruling_postdates = sum(total_expenses[age_ruling < 0], na.rm = TRUE)),
             by = tax_year][order(tax_year)],
       file.path(out, "core_coverage_by_year.csv"))

# Age (ruling) x year x hospital/higher-ed flag: counts, expenses, medians
ok <- core[!is.na(age_ruling) & age_ruling >= 0]
ok[, age_grp := age_group(age_ruling)]
fwrite(ok[, .(n = .N, exp_sum = sum(total_expenses), rev_sum = sum(total_revenue, na.rm = TRUE),
              exp_median = median(total_expenses), exp_p90 = quantile(total_expenses, .9)),
          by = .(tax_year, age_grp, hosp_hied)][order(tax_year, age_grp, hosp_hied)],
       file.path(out, "core_by_age_ruling.csv"))
# Same for 501(c)(3) only
fwrite(ok[is_c3 == TRUE, .(n = .N, exp_sum = sum(total_expenses), exp_median = median(total_expenses)),
          by = .(tax_year, age_grp, hosp_hied)][order(tax_year, age_grp, hosp_hied)],
       file.path(out, "core_by_age_ruling_c3.csv"))

# Young-org share among the largest filers (top 1,000 and top 10,000 by expenses)
setorder(ok, tax_year, -total_expenses)
ok[, rank := seq_len(.N), by = tax_year]
fwrite(ok[rank <= 10000, .(top = ifelse(rank <= 1000, "top1000", "top10000")), by = .(tax_year, age_grp, ein)][
         , .(n = .N), by = .(tax_year, top, age_grp)][order(tax_year, top, age_grp)],
       file.path(out, "core_top_filers_by_age.csv"))

# Independent age proxy: years since first appearance in the CORE panel
# (left-censored at 1989; valid for "entered within last 10 years" from 1999 on)
core[, first_grp := age_group(age_first)]
fwrite(core[, .(n = .N, exp_sum = sum(total_expenses), exp_median = median(total_expenses)),
            by = .(tax_year, first_grp, hosp_hied)][order(tax_year, first_grp, hosp_hied)],
       file.path(out, "core_by_age_firstseen.csv"))
# Entrants into CORE per year and their expense share that year
fwrite(core[, .(entrants = sum(age_first == 0), exp_entrants = sum(total_expenses[age_first == 0]),
                filers = .N, exp_total = sum(total_expenses)), by = tax_year][order(tax_year)],
       file.path(out, "core_entrants_by_year.csv"))

# ---- E-file: self-reported formation year x expenses, TY2012-2023 ----------
message("E-file ...")
yrs <- 2012:2023
hdr <- read_efile_table(req, "F9-P00-T00-HEADER", yrs,
                        c("EIN2", "TAX_YEAR", "RETURN_TYPE", "F9_00_YEAR_FORMATION"),
                        note = "formation year, 990/990-EZ")
p01 <- read_efile_table(req, "F9-P01-T00-SUMMARY", yrs,
                        c("EIN2", "TAX_YEAR", "RETURN_TYPE", "F9_01_EXP_TOT_CY"),
                        note = "total expenses, current year")
hdr <- as.data.table(hdr); p01 <- as.data.table(p01)
stopifnot(all(hdr$TAX_YEAR == hdr$file_year), all(p01$TAX_YEAR == p01$file_year))
message("RETURN_TYPE values: ", paste(unique(hdr$RETURN_TYPE), collapse = ", "))
ef <- merge(hdr[, .(EIN2, TAX_YEAR, RETURN_TYPE, formation = as.integer(F9_00_YEAR_FORMATION))],
            p01[, .(EIN2, TAX_YEAR, RETURN_TYPE, exp = as.numeric(F9_01_EXP_TOT_CY))],
            by = c("EIN2", "TAX_YEAR", "RETURN_TYPE"))
ef <- ef[!is.na(exp) & exp > 0]
setorder(ef, EIN2, TAX_YEAR, -exp)
ef <- ef[, .SD[1], by = .(EIN2, TAX_YEAR)]
ef[, age_form := TAX_YEAR - formation]
ef[formation < 1700 | age_form < 0, age_form := NA_integer_]
bmf[, EIN2 := nccs_ein_to_ein2(ein)]
ef <- merge(ef, bmf[, .(EIN2, ruling_year, hosp_hied)], by = "EIN2", all.x = TRUE)
ef[is.na(hosp_hied), hosp_hied := FALSE]
message(sprintf("e-file rows %s; formation missing/invalid %s", nrow(ef), sum(is.na(ef$age_form))))
fwrite(ef[, .(filers = .N, exp_total = sum(exp), formation_missing = sum(is.na(age_form)),
              exp_formation_missing = sum(exp[is.na(age_form)])), by = TAX_YEAR][order(TAX_YEAR)],
       file.path(out, "efile_coverage_by_year.csv"))
efo <- ef[!is.na(age_form)]
efo[, age_grp := age_group(age_form)]
fwrite(efo[, .(n = .N, exp_sum = sum(exp), exp_median = median(exp)),
           by = .(TAX_YEAR, age_grp, hosp_hied)][order(TAX_YEAR, age_grp, hosp_hied)],
       file.path(out, "efile_by_age_formation.csv"))

# Cross-check: BMF ruling year vs self-reported formation year (one row per EIN,
# latest filing). Reinstatement after auto-revocation resets the ruling date.
setorder(efo, EIN2, -TAX_YEAR)
one <- efo[, .SD[1], by = EIN2][!is.na(ruling_year)]
one[, gap := ruling_year - formation]
fwrite(one[, .(n = .N), by = .(gap_bucket = cut(gap, c(-Inf, -1, 0, 1, 2, 5, 10, 20, Inf),
                                                 labels = c("ruling before formation", "0", "1", "2", "3-5", "6-10", "11-20", "21+")))][order(gap_bucket)],
       file.path(out, "xcheck_ruling_vs_formation.csv"))
fwrite(one[, .(n = .N, share_gap_gt5 = mean(gap > 5), share_gap_gt10 = mean(gap > 10)),
           by = .(ruling_year)][order(ruling_year)][ruling_year >= 1990],
       file.path(out, "xcheck_gap_by_ruling_year.csv"))
message("done")
