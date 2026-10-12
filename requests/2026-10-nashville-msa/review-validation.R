# Read-only detector for unstable filing selection and broken coverage checks.
# Run from the repo root: Rscript requests/2026-10-nashville-msa/review-validation.R
# This preserves OBJECTID through the existing build's selection algorithm.
# A nonzero exit indicates that filing identity needs investigation.

connection <- DBI::dbConnect(duckdb::duckdb())
request_data <- here::here("requests", "2026-10-nashville-msa", "data")
raw_data <- here::here("requests", "2026-06-milwaukee-msa", "data")

scan_part <- function(part, table_label) {

  raw_pattern <- file.path(raw_data, paste0("efile-v2_1-", part),
                           sprintf("F9-%s-T00-%s-*.CSV", toupper(part), table_label))
  quoted_pattern <- as.character(DBI::dbQuoteString(connection, raw_pattern))

  DBI::dbExecute(connection, sprintf("
    CREATE TABLE %s AS
    SELECT EIN2, TAX_YEAR, RETURN_TIME_STAMP, OBJECTID,
           RETURN_GROUP_X, RETURN_AMENDED_X
    FROM read_csv(%s, union_by_name=true, all_varchar=true)
    WHERE RETURN_TYPE='990' AND try_cast(TAX_YEAR AS INTEGER) BETWEEN 2012 AND 2023
  ", part, quoted_pattern))

  # Match build-panel.R's two selection stages while retaining filing identity.
  DBI::dbExecute(connection, sprintf("
    CREATE TABLE latest_%s AS
    WITH flagged AS (
      SELECT *, CASE WHEN coalesce(try_cast(RETURN_GROUP_X AS BOOLEAN),false)
                         OR coalesce(try_cast(RETURN_AMENDED_X AS BOOLEAN),false)
        THEN row_number() OVER (
          PARTITION BY EIN2,TAX_YEAR,
            (coalesce(try_cast(RETURN_GROUP_X AS BOOLEAN),false)
             OR coalesce(try_cast(RETURN_AMENDED_X AS BOOLEAN),false))
          ORDER BY RETURN_TIME_STAMP DESC)
        ELSE 1 END flag_rn
      FROM %s)
    SELECT *,row_number() OVER (
      PARTITION BY EIN2,TAX_YEAR ORDER BY RETURN_TIME_STAMP DESC) rn
    FROM flagged WHERE flag_rn=1
  ", part, part))

  DBI::dbGetQuery(connection, sprintf("
    SELECT '%s' part, count(*) tied_latest_keys FROM (
      SELECT EIN2,TAX_YEAR FROM %s
      WHERE (EIN2,TAX_YEAR,RETURN_TIME_STAMP) IN (
        SELECT EIN2,TAX_YEAR,RETURN_TIME_STAMP FROM latest_%s WHERE rn=1)
      GROUP BY 1,2 HAVING count(*)>1)
  ", part, part, part))

}

summary_ties <- scan_part("p01", "SUMMARY")
expense_ties <- scan_part("p09", "EXPENSES")
print(summary_ties)
print(expense_ties)

filing_check <- DBI::dbGetQuery(connection, "
  SELECT count(*) joined,
         count(*) FILTER(WHERE b.EIN2 IS NULL) missing_part9,
         count(*) FILTER(WHERE a.OBJECTID!=b.OBJECTID) mixed_filings
  FROM latest_p01 a LEFT JOIN latest_p09 b
    ON a.EIN2=b.EIN2 AND a.TAX_YEAR=b.TAX_YEAR AND b.rn=1
  WHERE a.rn=1
")
print(filing_check)

# Validate the derived charity panel without changing it or its provenance log.
quoted_panel <- as.character(DBI::dbQuoteString(
  connection, file.path(request_data, "panel_charities.parquet")))
quoted_grants <- as.character(DBI::dbQuoteString(
  connection, file.path(request_data, "government_grants.parquet")))
panel_check <- DBI::dbGetQuery(connection, sprintf("
  SELECT count(*) n_rows,count(distinct(ein2,tax_year)) unique_keys FROM %s
", quoted_panel))
print(panel_check)

# Count joined keys independently of a blank extracted government-grant amount.
coverage_check <- DBI::dbGetQuery(connection, sprintf("
  WITH grants AS (
    SELECT * FROM %s WHERE form_type='990'
    QUALIFY row_number() OVER (
      PARTITION BY ein,tax_year ORDER BY filing_receipt_id DESC)=1)
  SELECT p.tax_year,count(*) panel_rows,
    count(*) FILTER(WHERE g.ein IS NULL) unmatched,
    count(*) FILTER(WHERE g.ein IS NOT NULL AND g.government_grants IS NULL) matched_blank
  FROM %s p LEFT JOIN grants g ON p.ein9=g.ein AND p.tax_year=g.tax_year
  WHERE p.tax_year BETWEEN 2020 AND 2023 GROUP BY 1 ORDER BY 1
", quoted_grants, quoted_panel))
print(coverage_check)
DBI::dbDisconnect(connection, shutdown=TRUE)

stopifnot(panel_check$n_rows == panel_check$unique_keys,
          all(coverage_check$unmatched == 0),
          filing_check$missing_part9 == 0)
if (summary_ties$tied_latest_keys > 0 || expense_ties$tied_latest_keys > 0 ||
    filing_check$mixed_filings > 0) {
  stop("Latest timestamps do not uniquely select shared filings. See REVIEW.md finding 1.")
}
