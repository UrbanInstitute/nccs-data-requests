# Optional network step for fields omitted from the request universe.
# Run from the reviews/ folder (Rscript review-foundations-fetch-vintage.R)
# before review-foundations.R. Pins go to the request's _pins.csv one level up.
suppressPackageStartupMessages(library(dplyr))
source("../../../R/request_read.R")
source_key <- "geocoding/unified-bmf/v2026_09/bmf_unified_geocoded.parquet"
source_uri <- paste0("s3://nccsdata/", source_key)
manifest <- jsonlite::fromJSON(
  "https://nccsdata.s3.amazonaws.com/geocoding/unified-bmf/v2026_09/_manifest.json")
expected_hash <- "c296860c572822404dc55861af89ea13ce11b48f51030313d97d067f1766a3ad"
stopifnot(manifest$files$bmf_unified_geocoded.parquet$sha256 == expected_hash,
  manifest$git_sha == "1b1f8a9")
cache_path <- "../data/review_foundations_vintage_evidence.parquet"
if (!file.exists(cache_path)) {
  filesystem <- arrow::S3FileSystem$create(anonymous = TRUE, region = "us-east-1")
  input <- filesystem$OpenInputFile(paste0("nccsdata/", source_key))
  # Read only EIN, observed month and status, then retain the TN universe.
  evidence <- arrow::read_parquet(input,
    col_select = c("ein", "last_vintage_ym", "status_code"))
  cat("Maximum observed month nationally:", max(evidence$last_vintage_ym), "\n")
  tennessee <- arrow::read_parquet("../data/universe_tn.parquet")
  evidence <- evidence |> dplyr::filter(ein %in% tennessee$ein)
  arrow::write_parquet(evidence, cache_path)
}
evidence <- arrow::read_parquet(cache_path)
record_pin("..", "bmf-foundations-review-monthly-evidence", "2026_09",
  source_uri, nrow(evidence),
  paste("Versioned manifest matches original pin; git 1b1f8a9; source sha256",
    expected_hash, "; selected ein, last_vintage_ym, status_code; TN EIN subset.",
    "Source full-object sha256 is manifest-reported; not independently rehashed."))
