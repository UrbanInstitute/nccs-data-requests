# Entry point: rebuilds every derived file and output from the inputs in
# INPUTS.md. Run from the repo root: Rscript requests/2026-10-nashville-msa/run-all.R
# Starts a fresh _pins.csv so the log matches this run exactly.
req <- here::here("requests", "2026-10-nashville-msa")
pins <- file.path(req, "_pins.csv")
if (file.exists(pins)) file.rename(pins, file.path(req, "data", paste0("_pins-", format(Sys.time(), "%Y%m%d%H%M%S"), ".csv")))
dir.create(file.path(req, "output"), showWarnings = FALSE)
scripts <- c("build.R", "analysis-round1.R", "profile-charts.R", "profile-list.R",
             "profile-funders.R", "validate-build.R")
for (s in scripts) {
  out <- file.path(req, "output", sub("\\.R$", ".txt", s))
  cat("==", s, "==\n")
  status <- system2("Rscript", file.path(req, s), stdout = out, stderr = out)
  if (status != 0) stop("failed: ", s, " (see ", out, ")")
}
cat("done\n")
