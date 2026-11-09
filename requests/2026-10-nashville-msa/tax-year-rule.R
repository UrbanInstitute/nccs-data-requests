# The tax year of a CORE return.
#
# "Tax year" in this request is the IRS form year: the year printed on the
# form, which is the year the accounting period begins. The e-file returns
# carry it. CORE labels a return by the calendar year its period ENDS, so
# CORE returns have to be converted.
#
# Two steps, in this order:
#   1. Where the same return is in the e-file header table (same EIN, form
#      and period end), use the tax year stated on the return.
#   2. Otherwise work it out from the month the period ends: December means
#      the period-end year, any other month means the year before. This is
#      exact for 12-month years and approximate for short periods (a return
#      for January to June 2023 is a 2023 return; this step calls it 2022).
#
# The e-file header table holds the full 990 and the 990-EZ, not the
# 990-PF, so 990-PF returns always use step 2.
# Second-analyst review, 2026-11-09.

#' Read the tax year stated on each e-filed 990 and 990-EZ
#'
#' @param request_dir Path to the request folder (for the cache and the
#'   provenance log).
#' @param tax_years Integer vector of e-file tax years to read.
#' @return A tibble with one row per EIN, form and period end: `ein9`,
#'   `source_form` ("990" or "990ez"), `tax_period` (YYYYMM, the period
#'   end) and `header_tax_year`.
#' @details Needs `read_efile_header()` from R/request_read.R. A key whose
#'   filings disagree on the tax year is dropped, so that it falls back to
#'   the period-month rule.
read_header_tax_years <- function(request_dir, tax_years) {
  header_rows <- read_efile_header(
    request_dir, years = tax_years,
    columns = c("ORG_EIN", "RETURN_TYPE", "TAX_PERIOD_END_DATE", "TAX_YEAR"),
    note = "tax year as stated on the return, to date CORE returns"
  )
  header_rows |>
    dplyr::transmute(
      ein9 = sprintf("%09d", as.integer(ORG_EIN)),
      source_form = tolower(RETURN_TYPE),
      tax_period = format(as.Date(TAX_PERIOD_END_DATE), "%Y%m"),
      header_tax_year = as.integer(TAX_YEAR)
    ) |>
    dplyr::filter(source_form %in% c("990", "990ez"), !is.na(tax_period), !is.na(header_tax_year)) |>
    dplyr::distinct() |>
    dplyr::group_by(ein9, source_form, tax_period) |>
    dplyr::filter(dplyr::n() == 1L) |>
    dplyr::ungroup()
}

#' Add the IRS tax year to CORE returns
#'
#' @param core_rows CORE rows with `ein` and `tax_period` (YYYYMM, the
#'   period end). To use the header years the rows also need `source_form`.
#' @param header_tax_years Output of `read_header_tax_years()`, or NULL to
#'   use the period-month rule alone (990-PF returns).
#' @return `core_rows` with `ein9`, `inferred_tax_year` (period-month
#'   rule), `header_tax_year` (NA where no e-file match) and `irs_tax_year`
#'   (the header year where there is one, else the inferred year).
#' @details Existing columns are kept; `tax_period` is returned as text.
add_irs_tax_year <- function(core_rows, header_tax_years = NULL) {
  dated <- core_rows |>
    dplyr::mutate(
      ein9 = gsub("-", "", ein),
      tax_period = as.character(tax_period),
      period_end_year = as.integer(substr(tax_period, 1, 4)),
      period_end_month = as.integer(substr(tax_period, 5, 6)),
      inferred_tax_year = dplyr::if_else(period_end_month == 12L, period_end_year, period_end_year - 1L)
    ) |>
    dplyr::select(-period_end_year, -period_end_month)
  if (is.null(header_tax_years)) {
    dated <- dated |> dplyr::mutate(header_tax_year = NA_integer_)
  } else {
    dated <- dated |>
      dplyr::left_join(header_tax_years, by = c("ein9", "source_form", "tax_period"))
  }
  dated |>
    dplyr::mutate(irs_tax_year = dplyr::coalesce(header_tax_year, inferred_tax_year))
}
