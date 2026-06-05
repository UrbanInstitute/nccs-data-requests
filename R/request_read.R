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
