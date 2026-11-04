# Size categories for the requester's organization list.
#
# Three bands, chosen by the requester on 2026-11-04 from the NCCS Sector
# in Brief expense bands: Small is under $1 million, Medium is $1 million
# to under $10 million, Large is $10 million and over. The amount banded
# is total expenses for a nonprofit and grants paid to Davidson County
# recipients for a philanthropic organization; that choice is made by the
# caller, not here.

size_band_cutoffs <- c(Medium = 1e6, Large = 1e7)

#' Put dollar amounts into the requester's three size bands
#'
#' @param amount Numeric vector of dollars; NA stays NA.
#' @return Character vector: "Small", "Medium", "Large", or NA.
#' @details Bands are closed on the left: exactly $1,000,000 is Medium and
#'   exactly $10,000,000 is Large. Negative amounts stop the run because no
#'   expense or grant total should be below zero.
size_band <- function(amount) {
  if (any(amount < 0, na.rm = TRUE)) {
    stop("size_band: negative amount")
  }
  dplyr::case_when(
    is.na(amount) ~ NA_character_,
    amount >= size_band_cutoffs[["Large"]] ~ "Large",
    amount >= size_band_cutoffs[["Medium"]] ~ "Medium",
    TRUE ~ "Small"
  )
}
