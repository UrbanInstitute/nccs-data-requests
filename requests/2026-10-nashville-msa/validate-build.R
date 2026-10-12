# Active check of the fixed build (RESPONSE-REVIEW.md item 5). Run from the
# repo root after build-panel.R: Rscript requests/2026-10-nashville-msa/validate-build.R
# Asserts, on the written panel and the raw Part I files:
#   (a) one row per EIN2 x tax year and one per filing id;
#   (b) the deterministic rule (latest RETURN_TIME_STAMP, then OBJECTID desc)
#       applied afresh to raw Part I selects exactly the panel's filing ids;
#   (c) every panel filing id has a Part IX row with the same EIN2 and tax year.
library(DBI)
con <- dbConnect(duckdb::duckdb())
req <- here::here("requests", "2026-10-nashville-msa")
raw <- here::here("requests", "2026-06-milwaukee-msa", "data")
q <- function(x) as.character(dbQuoteString(con, x))
panel <- q(file.path(req, "data", "panel_990_national.parquet"))
p01 <- q(file.path(raw, "efile-v2_1-p01", "F9-P01-T00-SUMMARY-*.CSV"))
p09 <- q(file.path(raw, "efile-v2_1-p09", "F9-P09-T00-EXPENSES-*.CSV"))

a <- dbGetQuery(con, sprintf("SELECT count(*) n, count(DISTINCT (ein2, tax_year)) keys, count(DISTINCT filing_id) filings FROM %s", panel))
print(a); stopifnot(a$n == a$keys, a$n == a$filings)

dbExecute(con, sprintf("CREATE TABLE sel AS
  SELECT OBJECTID, EIN2, TAX_YEAR FROM (
    SELECT OBJECTID, EIN2, TAX_YEAR, row_number() OVER (PARTITION BY EIN2, TAX_YEAR ORDER BY RETURN_TIME_STAMP DESC, OBJECTID DESC) rn
    FROM read_csv(%s, union_by_name = true, all_varchar = true)
    WHERE RETURN_TYPE = '990' AND try_cast(TAX_YEAR AS INTEGER) BETWEEN 2012 AND 2023) WHERE rn = 1", p01))
b <- dbGetQuery(con, sprintf("SELECT
  (SELECT count(*) FROM sel) selected,
  (SELECT count(*) FROM sel s LEFT JOIN %s p ON p.filing_id = s.OBJECTID WHERE p.filing_id IS NULL) not_in_panel,
  (SELECT count(*) FROM %s p LEFT JOIN sel s ON p.filing_id = s.OBJECTID WHERE s.OBJECTID IS NULL) panel_not_selected", panel, panel))
print(b); stopifnot(b$not_in_panel == 0, b$panel_not_selected == 0)

c <- dbGetQuery(con, sprintf("SELECT
  count(*) FILTER (WHERE x.OBJECTID IS NULL) missing_part9,
  count(*) FILTER (WHERE x.OBJECTID IS NOT NULL AND (x.EIN2 <> p.ein2 OR try_cast(x.TAX_YEAR AS INTEGER) <> p.tax_year)) identity_mismatch
  FROM %s p LEFT JOIN (SELECT DISTINCT OBJECTID, EIN2, TAX_YEAR FROM read_csv(%s, union_by_name = true, all_varchar = true) WHERE RETURN_TYPE = '990') x
  ON x.OBJECTID = p.filing_id", panel, p09))
print(c); stopifnot(c$missing_part9 == 0, c$identity_mismatch == 0)
dbDisconnect(con, shutdown = TRUE)
cat("validate-build: all checks passed\n")
