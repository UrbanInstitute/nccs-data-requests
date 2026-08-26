# build-ntee-filer-files.R — 2026-08 follow-up (requester): add legacy 3-char NTEE
# codes to the EIN-level filer files so the requester can apply their own
# 9-group scheme and adjusted-sample exclusions (defined on NTEE letters).
#
# Outputs (data/followup-2026-08-ntee/, gitignored bulk):
#   filers_2023_named_ntee.csv     — 2023 Form 990/990-EZ filers, MSA, EIN level
#   filers_by_year_1989_2023.csv   — same structure, one row per EIN x tax year
#   pf_filers_by_year_1989_2023.csv— Form 990-PF, reported separately
#
# Grain. The CORE merged tier is one row per (ein, tax_period), so an
# organization with two fiscal periods ending in the same calendar year
# (fiscal-year change, short-period return) has two rows in one tax year.
# These files are ENFORCED to one row per EIN x tax year: the filing with
# the latest tax_period in the year is kept (the full-period return after a
# fiscal-year change). `tax_period` and `n_filings_in_year` are carried so
# the choice is visible; `n_filings_in_year > 1` marks the affected rows.
#
# NTEE columns: ntee_code (current BMF, may be blank) and ntee_code_resolved
# (falls back to the NTEE-resolved crosswalk's most-recent code, ADR 0034),
# with ntee_source flagging which one filled it.

suppressMessages({ library(dplyr); library(arrow) })
setwd(here::here())
source(here::here("R", "request_read.R"))
req <- "requests/2026-06-milwaukee-msa"
out_dir <- file.path(req, "data", "followup-2026-08-ntee")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# --- MSA universe (same join as request.qmd; never re-derived) --------------
bmf <- read_bmf_master(
  req, state = "WI",
  columns = c("ein", "org_name_display", "geo_state_abbr", "geo_county",
              "ntee_code_clean", "nteev2_subsector",
              "first_year_in_bmf", "last_year_in_bmf"),
  cache = FALSE, note = "Requester follow-up: WI universe with legacy NTEE code"
)
xwalk_county <- read_crosswalk(req, "county-fips")
xwalk_cbsa   <- read_crosswalk(req, "cbsa")

msa <- bmf |>
  left_join(xwalk_county, by = c("geo_state_abbr", "geo_county" = "geo_county_raw")) |>
  left_join(xwalk_cbsa,   by = c("geo_county_fips" = "county_fips")) |>
  filter(cbsa_code == "33340")

# --- NTEE-resolved crosswalk (recovers codes blank in current BMF) ----------
# The published crosswalk is a rolling flat prefix; its vintage lives in the
# ADR 0014 _manifest.json, not the path. To pin a stable artifact: read the
# manifest, download the parquet into this request's data/ (skipped when the
# local copy already matches the manifest sha256), verify the hash, and pin
# the manifest vintage + sha256. Anonymous HTTPS, no credentials.
ntee_base     <- "https://nccsdata.s3.amazonaws.com/crosswalks/ntee-resolved"
ntee_manifest <- jsonlite::fromJSON(paste0(ntee_base, "/_manifest.json"))
ntee_file     <- "ntee_resolved_crosswalk.parquet"
ntee_expected_sha256 <- ntee_manifest$files[[ntee_file]]$sha256
ntee_local    <- file.path(req, "data", sprintf("%s-%s.parquet",
                                                tools::file_path_sans_ext(ntee_file),
                                                ntee_manifest$vintage))

file_sha256 <- function(file_path) {

  connection <- file(file_path, open = "rb")
  on.exit(close(connection))
  as.character(openssl::sha256(connection))

}

local_copy_matches <- file.exists(ntee_local) && file_sha256(ntee_local) == ntee_expected_sha256

if (!local_copy_matches) {

  # ~100 MB; R's default 60 s download timeout is too short.
  old_timeout <- options(timeout = max(3600, getOption("timeout")))
  utils::download.file(paste0(ntee_base, "/", ntee_file), ntee_local, mode = "wb", quiet = TRUE)
  options(old_timeout)

  if (file_sha256(ntee_local) != ntee_expected_sha256) {

    stop("ntee-resolved crosswalk download does not match the manifest sha256; ",
         "the artifact may have been republished mid-download. Re-run.")

  }

}

ntee_res <- arrow::open_dataset(ntee_local) |>
  select(ein, ntee_most_recent) |>
  filter(ein %in% msa$ein) |>
  collect()

record_pin(req, "crosswalk-ntee-resolved",
           vintage = ntee_manifest$vintage,
           source  = paste0("s3://nccsdata/crosswalks/ntee-resolved/", ntee_file),
           n_rows  = nrow(ntee_res),
           note    = sprintf("most-recent code, MSA EINs only; sha256 %s; built %s git %s",
                             ntee_expected_sha256, ntee_manifest$built_at, ntee_manifest$git_sha))

msa <- msa |>
  left_join(ntee_res, by = "ein") |>
  mutate(
    # Placeholder values ("UNDEFINED", "UNKNOWN", bare letters, and the Z
    # "unknown" major group, e.g. Z99) are not real codes: a valid legacy
    # NTEE code is a letter A-Y + 2 digits (+ optional specialty suffix).
    # Anything else is treated as missing.
    ntee_code = ifelse(grepl("^[A-Y][0-9]{2}", trimws(coalesce(ntee_code_clean, ""))),
                       trimws(ntee_code_clean), NA_character_),
    ntee_most_recent_valid = ifelse(grepl("^[A-Y][0-9]{2}", trimws(coalesce(ntee_most_recent, ""))),
                                    trimws(ntee_most_recent), NA_character_),
    ntee_code_resolved = coalesce(ntee_code, ntee_most_recent_valid),
    ntee_source = case_when(
      !is.na(ntee_code)                                  ~ "current_bmf",
      is.na(ntee_code) & !is.na(ntee_code_resolved)      ~ "resolved_crosswalk",
      TRUE                                               ~ "none"
    ),
    focus = ifelse(is.na(nteev2_subsector) | nteev2_subsector == "",
                   "UNU", nteev2_subsector)
  ) |>
  select(ein, org_name = org_name_display, county = geo_county_canonical,
         ntee_code, ntee_code_resolved, ntee_source, focus,
         first_year_in_bmf, last_year_in_bmf)

# --- CORE financials, per year (same fields as the June build) --------------
rev_cols <- c("total_revenue", "total_contributions", "program_service_revenue",
              "net_income_fundraising_events", "investment_income",
              "other_revenue_total_11e")

# Per-year reads to absorb legacy schema drift (see request.qmd note): a
# multi-year collect fails when arrow unifies an int32 year against a
# double year (Float ... truncated converting to int32).
pull_form <- function(form) {
  bind_rows(lapply(1989:2023, function(y) {
    df <- tryCatch(
      read_core(req, tier = "merged", tax_year = y, form = form,
                note = sprintf("Requester follow-up, %s %d", form, y)),
      error = function(e) { message(sprintf("skip %s %d: %s", form, y, conditionMessage(e))); NULL })
    if (is.null(df) || nrow(df) == 0) return(NULL)
    keep <- intersect(c("ein", "tax_year", "tax_period", rev_cols), names(df))
    df |>
      select(all_of(keep)) |>
      mutate(across(any_of(rev_cols), as.numeric), tax_year = as.integer(tax_year)) |>
      inner_join(msa, by = "ein") |>
      # Enforce one row per EIN x tax year (see header): count the filings in
      # the year, then keep the one with the latest tax_period.
      group_by(ein, tax_year) |>
      mutate(n_filings_in_year = n()) |>
      slice_max(tax_period, n = 1, with_ties = FALSE) |>
      ungroup() |>
      mutate(form = form)
  }))
}

pc <- pull_form("990combined")
pf <- pull_form("990pf")

# --- write ------------------------------------------------------------------
write.csv(filter(pc, tax_year == 2023),
          file.path(out_dir, "filers_2023_named_ntee.csv"), row.names = FALSE, na = "")
write.csv(pc, file.path(out_dir, "filers_by_year_1989_2023.csv"), row.names = FALSE, na = "")
write.csv(pf, file.path(out_dir, "pf_filers_by_year_1989_2023.csv"), row.names = FALSE, na = "")

cat(sprintf("2023 filers: %d | PC rows 1989-2023: %d | PF rows: %d\n",
            sum(pc$tax_year == 2023), nrow(pc), nrow(pf)))
cat(sprintf("EIN x year collapsed from >1 filing: PC %d | PF %d\n",
            sum(pc$n_filings_in_year > 1), sum(pf$n_filings_in_year > 1)))
stopifnot(!anyDuplicated(pc[, c("ein", "tax_year")]),
          !anyDuplicated(pf[, c("ein", "tax_year")]))
cat(sprintf("2023 NTEE coverage: current %d | resolved-only %d | none %d\n",
            sum(pc$tax_year==2023 & pc$ntee_source=="current_bmf"),
            sum(pc$tax_year==2023 & pc$ntee_source=="resolved_crosswalk"),
            sum(pc$tax_year==2023 & pc$ntee_source=="none")))
