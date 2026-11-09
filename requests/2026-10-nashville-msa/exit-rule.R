# Counting filing gaps and exits.
#
# The IRS does not record when an organization closes, so an exit has to be
# read from its filing record. The rule follows Harrison and Oxley (2025,
# Nonprofit Management and Leadership 36:57-69): an organization has exited
# after its last return if it files nothing for the next three form years
# and does not file again in the data. Shorter gaps overstate exits because
# many organizations skip years and then file again.
#
# count_filing_gap() does the counting for one last-return year and one gap
# length. The caller chooses which years and gap lengths to ask for.

#' Count filers whose filing gap lasts a given number of years
#'
#' @param filed_years Data frame with one row per organization and form year
#'   filed (columns `ein9`, `form_year`).
#' @param last_year Integer. The form year the organization filed for.
#' @param gap_years Integer. Number of following form years with no return.
#' @param final_year Integer. Last form year with complete returns.
#' @return A one-row tibble: the filers in `last_year`, how many filed
#'   nothing in the next `gap_years` years, and how many of those filed
#'   again between the end of the gap and `final_year`.
#' @details Returns `NA` counts for "filed again" when the gap ends at
#'   `final_year`, because no later year can be observed.
count_filing_gap <- function(filed_years, last_year, gap_years, final_year) {
  filed_in_last_year <- filed_years |>
    dplyr::filter(form_year == last_year) |>
    dplyr::pull(ein9)
  gap_window <- (last_year + 1L):(last_year + gap_years)
  filed_in_gap <- filed_years |>
    dplyr::filter(form_year %in% gap_window) |>
    dplyr::pull(ein9)
  organizations_with_gap <- setdiff(filed_in_last_year, filed_in_gap)
  first_year_after_gap <- last_year + gap_years + 1L
  can_observe_return <- first_year_after_gap <= final_year
  filed_after_gap <- filed_years |>
    dplyr::filter(form_year >= first_year_after_gap, form_year <= final_year) |>
    dplyr::pull(ein9)
  dplyr::tibble(
    last_form_year = last_year,
    gap_years = gap_years,
    filers = length(filed_in_last_year),
    with_gap = length(organizations_with_gap),
    years_observed_after_gap = max(final_year - first_year_after_gap + 1L, 0L),
    filed_again = if (can_observe_return) sum(organizations_with_gap %in% filed_after_gap) else NA_integer_
  )
}
