# build-ntee-filer-files.R — 2026-08 follow-up (WPF): add legacy 3-char NTEE
# codes to the EIN-level filer files so the requester can apply their own
# 9-group scheme and adjusted-sample exclusions (defined on NTEE letters).
#
# Outputs (data/followup-2026-08-ntee/, gitignored bulk):
#   filers_2023_named_ntee.csv     — 2023 Form 990/990-EZ filers, MSA, EIN level
#   filers_by_year_1989_2023.csv   — same structure, one row per EIN x year
#   pf_filers_by_year_1989_2023.csv— Form 990-PF, reported separately
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
  cache = FALSE, note = "WPF follow-up: WI universe with legacy NTEE code"
)
xwalk_county <- read_crosswalk(req, "county-fips")
xwalk_cbsa   <- read_crosswalk(req, "cbsa")

msa <- bmf |>
  left_join(xwalk_county, by = c("geo_state_abbr", "geo_county" = "geo_county_raw")) |>
  left_join(xwalk_cbsa,   by = c("geo_county_fips" = "county_fips")) |>
  filter(cbsa_code == "33340")

# --- NTEE-resolved crosswalk (recovers codes blank in current BMF) ----------
ntee_uri <- "s3://nccsdata/crosswalks/ntee-resolved/ntee_resolved_crosswalk.parquet"
ntee_res <- open_dataset(ntee_uri) |>
  select(ein, ntee_most_recent) |>
  filter(ein %in% msa$ein) |>
  collect()
record_pin(req, "crosswalk-ntee-resolved", "current", ntee_uri,
           n_rows = nrow(ntee_res), note = "most-recent code, MSA EINs only")

msa <- msa |>
  left_join(ntee_res, by = "ein") |>
  mutate(
    # Placeholder values ("UNDEFINED", "UNKNOWN", bare letters, "Z…") are not
    # real codes — a valid legacy NTEE code is letter + 2 digits (+ optional
    # specialty suffix). Anything else is treated as missing.
    ntee_code = ifelse(grepl("^[A-Z][0-9]{2}", trimws(coalesce(ntee_code_clean, ""))),
                       trimws(ntee_code_clean), NA_character_),
    ntee_most_recent_valid = ifelse(grepl("^[A-Z][0-9]{2}", trimws(coalesce(ntee_most_recent, ""))),
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
                note = sprintf("WPF follow-up, %s %d", form, y)),
      error = function(e) { message(sprintf("skip %s %d: %s", form, y, conditionMessage(e))); NULL })
    if (is.null(df) || nrow(df) == 0) return(NULL)
    keep <- intersect(c("ein", "tax_year", rev_cols), names(df))
    df |>
      select(all_of(keep)) |>
      mutate(across(any_of(rev_cols), as.numeric), tax_year = as.integer(tax_year)) |>
      inner_join(msa, by = "ein") |>
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
cat(sprintf("2023 NTEE coverage: current %d | resolved-only %d | none %d\n",
            sum(pc$tax_year==2023 & pc$ntee_source=="current_bmf"),
            sum(pc$tax_year==2023 & pc$ntee_source=="resolved_crosswalk"),
            sum(pc$tax_year==2023 & pc$ntee_source=="none")))
