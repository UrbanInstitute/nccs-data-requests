# request_read.R: the helper functions every request uses to read NCCS data.
#
# What they do: each helper reads one dataset from the NCCS files on S3 and
# at the same time writes one line to the request folder's `_pins.csv`
# saying what was read, when, and how many rows came back. That line is the
# record of which data a deliverable was built from. Read data only through
# these helpers so that record is complete.
#
# What they do not do: they do not change the data. Filtering, joining and
# counting happen in your own script after the read.
#
# How to use them (from a script inside a request folder):
#
#   source(here::here("R", "request_read.R"))
#   req <- here::here("requests", "2026-10-southeast-michigan")   # this request's folder
#
#   bmf  <- read_bmf_master(req, state = "MI",
#                           columns = c("ein", "org_name_display", "subsection_code"))
#   core <- read_core(req, tier = "soi", tax_year = 2023, form = "990combined",
#                     columns = c("ein", "tax_period", "total_revenue"))
#   xw   <- read_crosswalk(req, "county-fips")
#
# Each helper's arguments are listed in the comment block above it. Where a
# helper passes arguments through to the `nccsdata` package, the comment
# names the most useful ones and tells you where the full list is.

# --- provenance log ----------------------------------------------------------

#' Path to a request's provenance file
#'
#' @param request_dir The request folder (for example from `here::here("requests", "...")`).
#' @return The path to `_pins.csv` inside that folder. The file is created on the first read.
pins_path <- function(request_dir) file.path(request_dir, "_pins.csv")

#' Add one line to the request's provenance file
#'
#' Called by every read helper; you will not normally call it yourself.
#'
#' @param request_dir The request folder.
#' @param dataset Short name of what was read, for example "bmf-master-geocoded".
#' @param vintage Which version of the data: a date, a tax year, or a tier name.
#' @param source Where it was read from (a URL or S3 path).
#' @param n_rows How many rows came back.
#' @param note Optional free text, for example why this read was needed.
#' @param data The data that was read. Returned unchanged so the helpers can
#'   hand it straight back to you.
#' @return `data`, unchanged.
record_pin <- function(request_dir, dataset, vintage, source, n_rows = NA_integer_,
                       note = "", data = NULL) {
  row <- data.frame(
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    dataset   = dataset,
    vintage   = vintage,
    source    = source,
    n_rows    = n_rows,
    note      = note,
    stringsAsFactors = FALSE
  )
  p <- pins_path(request_dir)
  utils::write.table(
    row, p, sep = ",", row.names = FALSE,
    col.names = !file.exists(p), append = file.exists(p), qmethod = "double"
  )
  message(sprintf("pinned: %s [%s] (%s rows)", dataset, vintage, n_rows))
  invisible(data)
}

.n_rows <- function(x) tryCatch(nrow(x), error = function(e) NA_integer_)

# --- canonical reads (thin wrappers over nccsdata) ---------------------------

#' Read the current Business Master File (one row per organization)
#'
#' Reads the geocoded "master" BMF: every organization the IRS has ever listed,
#' with the month it was last seen in `last_vintage_ym`. To work with the
#' current registry only, filter on the latest `last_vintage_ym` after reading.
#' The file is updated monthly, so the provenance line records the date read.
#' For a fixed monthly snapshot use `read_bmf_vintage()` instead.
#'
#' @param request_dir The request folder.
#' @param ... Filters and options passed to `nccsdata::nccs_read()`. The
#'   useful ones:
#'   * `state`: two-letter state code or codes, for example `"MI"`.
#'   * `county`: county name or names.
#'   * `columns`: which columns to return. Leave out for all of them (slow);
#'     naming the columns you need is much faster.
#'   * `org_type`: `"501c3"`, `"public_charity"`, `"private_foundation"`, or
#'     `"all"` (the default).
#'   * `ntee_subsector`, `ntee_major_group`, `ntee_code`: subject filters.
#'   The full list is in R under `?nccsdata::nccs_read`.
#' @param note Optional text written to the provenance file.
#' @return A data frame with one row per organization.
#' @examples
#' bmf <- read_bmf_master(req, state = "MI",
#'                        columns = c("ein", "subsection_code", "foundation_code",
#'                                    "geo_county", "last_vintage_ym"))
read_bmf_master <- function(request_dir, ..., note = "") {
  stopifnot(requireNamespace("nccsdata", quietly = TRUE))
  out <- nccsdata::nccs_read(...)
  record_pin(request_dir, "bmf-master-geocoded",
             vintage = paste0("rolling@", Sys.Date()),
             source  = "nccsdata::nccs_read (rolling geocoded master)",
             n_rows  = .n_rows(out), note = note, data = out)
}

#' Read one monthly snapshot of the Business Master File
#'
#' Use this instead of `read_bmf_master()` when the deliverable must be tied to
#' a fixed month.
#'
#' @param request_dir The request folder.
#' @param vintage The month, written as `"YYYY_MM"`, for example `"2026_07"`.
#' @param kind `"data"` (default) for the organizations, or `"dictionary"` for
#'   the file describing the columns.
#' @param legacy `FALSE` (default) for the current monthly files; `TRUE` for
#'   the older yearly files.
#' @param note Optional text written to the provenance file.
#' @return A data frame with one row per organization in that month's file.
read_bmf_vintage <- function(request_dir, vintage, kind = "data", legacy = FALSE, note = "") {
  stopifnot(requireNamespace("nccsdata", quietly = TRUE),
            requireNamespace("arrow", quietly = TRUE))
  uri <- nccsdata::nccs_vintage_url(vintage, kind = kind, legacy = legacy)
  out <- arrow::read_csv_arrow(uri)
  record_pin(request_dir, paste0("bmf-vintage-", kind),
             vintage = vintage, source = uri,
             n_rows  = .n_rows(out), note = note, data = out)
}

#' Read the CORE financial files (one row per Form 990 filing)
#'
#' @param request_dir The request folder.
#' @param tier Which set of CORE files:
#'   * `"soi"`: the files built from the IRS Statistics of Income extracts,
#'     tax year 2012 onward. Use this for a single recent tax year.
#'   * `"merged"` (default): the same, joined with the older NCCS files so
#'     the series runs from 1989. Use this for long time series.
#'   * `"legacy"`: the older NCCS files only (before 2012).
#' @param ... Passed to `nccsdata::nccs_read_core()`. Required:
#'   * `tax_year`: one tax year, for example `2023`, or several, `2019:2023`.
#'   * `form`: which filers. `"990"` (full Form 990 only; has employee counts),
#'     `"990ez"` (short form only), `"990combined"` (990 and 990-EZ stacked,
#'     with a `source_form` column saying which), or `"990pf"` (private
#'     foundations).
#'   Optional:
#'   * `columns`: which columns to return. Column names are listed in the
#'     dictionary file next to each data file on S3; the first line of the
#'     CSV at `nccsdata::nccs_core_url(tier, tax_year, form, format = "csv")`
#'     is the quickest way to see them.
#' @param note Optional text written to the provenance file.
#' @return A data frame with one row per filing. An organization can have
#'   more than one filing in a tax year; keep the latest `tax_period` if you
#'   need one row per organization.
#' @examples
#' fin <- read_core(req, tier = "soi", tax_year = 2023, form = "990combined",
#'                  columns = c("ein", "tax_period", "source_form",
#'                              "total_revenue", "total_expenses"))
read_core <- function(request_dir, tier = c("merged", "soi", "legacy"), ..., note = "") {
  stopifnot(requireNamespace("nccsdata", quietly = TRUE))
  tier <- match.arg(tier)
  out <- nccsdata::nccs_read_core(tier = tier, ...)
  src <- tryCatch(nccsdata::nccs_core_url(tier = tier), error = function(e) paste0("core:", tier))
  record_pin(request_dir, paste0("core-", tier),
             vintage = tier, source = src,
             n_rows  = .n_rows(out), note = note, data = out)
}

#' E-file v2.1 Form 990 header table (`s3://nccs-efile/public/efile_v2_1/`),
#' one file per tax year. Anonymous HTTPS read, no credentials. Each raw CSV
#' (~30-390 MB/year) is cached as a slim parquet of just `columns` in the
#' request's gitignored `data/` dir, so only the first render downloads.
#' Adds a `file_year` column so callers can verify the in-column `TAX_YEAR`
#' against the file partition — analyses must filter on the `TAX_YEAR` and
#' `RETURN_TYPE` columns, never trust the file-name year alone.
#' NOTE: this reads the legacy NODC/`nccs-efile` researcher catalog, which is
#' slated for supersession by `nccsdata/processed/efile/relational/` (ADR 0028
#' in `nccs-contracts`). On a second use, promote this helper into `nccsdata`
#' and re-point it at the contracted surface when that lands.
read_efile_header <- function(request_dir, years, columns, note = "") {
  stopifnot(requireNamespace("arrow", quietly = TRUE))
  base  <- "https://nccs-efile.s3.amazonaws.com/public/efile_v2_1"
  cache <- file.path(request_dir, "data", "efile_v2_1-cache")
  dir.create(cache, recursive = TRUE, showWarnings = FALSE)
  # The header CSVs run 30-390 MB; R's default 60s download timeout is too
  # short for them on ordinary connections.
  old_timeout <- options(timeout = max(3600, getOption("timeout")))
  on.exit(options(old_timeout), add = TRUE)
  slims <- lapply(years, function(y) {
    slim <- file.path(cache, sprintf("F9-P00-T00-HEADER-%s-slim.parquet", y))
    if (!file.exists(slim)) {
      raw <- file.path(cache, sprintf("F9-P00-T00-HEADER-%s.CSV", y))
      on.exit(unlink(raw), add = TRUE)
      utils::download.file(sprintf("%s/F9-P00-T00-HEADER-%s.CSV", base, y),
                           raw, mode = "wb", quiet = TRUE)
      d <- arrow::read_csv_arrow(raw, col_select = dplyr::all_of(columns))
      d$file_year <- y
      arrow::write_parquet(d, slim)
    }
    d <- arrow::read_parquet(slim)
    if (!setequal(setdiff(names(d), "file_year"), columns)) {
      stop(sprintf("cache %s was built with different columns; delete it to refresh", slim))
    }
    d
  })
  out <- dplyr::bind_rows(slims)
  record_pin(request_dir, "efile-v2_1-f9-header",
             vintage = sprintf("efile_v2_1@%s-%s", min(years), max(years)),
             source  = paste0(base, "/F9-P00-T00-HEADER-{year}.CSV"),
             n_rows  = .n_rows(out), note = note, data = out)
}

#' Read a geography lookup table
#'
#' The BMF carries county names as free text. These tables turn them into
#' standard codes, which you join onto the BMF in your script.
#'
#' @param request_dir The request folder.
#' @param which Which table:
#'   * `"county-fips"`: county name and state to the five-digit county FIPS
#'     code. Join on `geo_state_abbr` and `geo_county` = `geo_county_raw`;
#'     gives `geo_county_fips` and a clean `county_name`.
#'   * `"cbsa"`: county FIPS to metropolitan area. Join on
#'     `geo_county_fips` = `county_fips`.
#'   * `"ct-planning-region"`: Connecticut's planning regions, joined on
#'     coordinates (Connecticut only).
#' @param note Optional text written to the provenance file.
#' @return A data frame with one row per county (or region). Based on the
#'   2023 Census geography.
read_crosswalk <- function(request_dir, which = c("county-fips", "cbsa", "ct-planning-region"),
                           note = "") {
  stopifnot(requireNamespace("arrow", quietly = TRUE))
  which <- match.arg(which)
  file <- c(
    "county-fips"        = "county_fips_crosswalk.parquet",
    "cbsa"               = "cbsa_crosswalk.parquet",
    "ct-planning-region" = "ct_planning_region_crosswalk.parquet"
  )[[which]]
  uri <- sprintf("s3://nccsdata/crosswalks/%s/%s", which, file)
  out <- arrow::read_parquet(uri)
  record_pin(request_dir, paste0("crosswalk-", which),
             vintage = "tiger-2023", source = uri,
             n_rows  = .n_rows(out), note = note, data = out)
}
