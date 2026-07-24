# request_read.R — read canonical NCCS artifacts and pin what was read.
#
# Every read appends a provenance row to the request folder's `_pins.csv`
# (timestamp, dataset, vintage, source URI, n_rows, note) so a deliverable
# is reproducible from its folder alone (ADR 0024). Reads go through
# `nccsdata`; geography is composed by joining the published crosswalks
# downstream — do NOT re-derive county/CBSA identity here.
#
# Usage (inside a request.qmd):
#   source(here::here("R", "request_read.R"))
#   req <- "requests/2026-06-ct-pri"        # this request's folder
#   bmf  <- read_bmf_master(req, state = "CT")
#   pri  <- read_core(req, tier = "merged")

# --- provenance log ----------------------------------------------------------

#' Path to a request's pins log.
pins_path <- function(request_dir) file.path(request_dir, "_pins.csv")

#' Append one provenance record to the request's `_pins.csv`.
#' @return `data` unchanged (so calls can be piped/wrapped).
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

#' Rolling geocoded BMF master. Not vintage-pinned — `nccs_read()` reads the
#' rolling master — so the pin records the read date, not a fixed vintage.
#' For a fixed snapshot use `read_bmf_vintage()` instead.
read_bmf_master <- function(request_dir, ..., note = "") {
  stopifnot(requireNamespace("nccsdata", quietly = TRUE))
  out <- nccsdata::nccs_read(...)
  record_pin(request_dir, "bmf-master-geocoded",
             vintage = paste0("rolling@", Sys.Date()),
             source  = "nccsdata::nccs_read (rolling geocoded master)",
             n_rows  = .n_rows(out), note = note, data = out)
}

#' A specific dated BMF snapshot (CSV). `vintage` is `"YYYY_MM"`.
read_bmf_vintage <- function(request_dir, vintage, kind = "data", legacy = FALSE, note = "") {
  stopifnot(requireNamespace("nccsdata", quietly = TRUE),
            requireNamespace("arrow", quietly = TRUE))
  uri <- nccsdata::nccs_vintage_url(vintage, kind = kind, legacy = legacy)
  out <- arrow::read_csv_arrow(uri)
  record_pin(request_dir, paste0("bmf-vintage-", kind),
             vintage = vintage, source = uri,
             n_rows  = .n_rows(out), note = note, data = out)
}

#' Core 990 (one row per filing). `tier` is "merged" | "soi" | "legacy".
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

# Geography: read the crosswalks straight from the flat S3 prefix, then join
# onto raw geo labels (county-fips / cbsa) or coordinates (ct-planning-region,
# Connecticut). Paths per the nccs-contracts crosswalk contracts. Pin what you
# read. The `vintage` is the tiger_year / delineation_year carried in-column
# and in each crosswalk's _manifest.json (currently 2023).
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
