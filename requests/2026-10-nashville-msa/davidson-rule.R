# One rule for "this grant recipient is in Davidson County", used for every
# funder on the requester's list and for the Boedecker Foundation.
#
# The 990 Schedule I gives a recipient EIN; the 990-PF gives only a name
# and address. So the rule is: the EIN's county on the BMF where the EIN is
# known there; otherwise, for a Tennessee address, the ZIP code where it is
# one that belongs to Davidson County; otherwise the city. This is an
# address-based proxy: it says where the recipient is based, not where its
# work reaches.

# City names that lie wholly inside Davidson County (Nashville-Davidson is
# consolidated; these are its neighborhoods and satellite cities), as they
# appear on returns, including common misspellings.
davidson_cities <- c(
  "NASHVILLE", "NASHVILE", "NASHVILLE DAVIDSON", "ANTIOCH", "MADISON",
  "HERMITAGE", "OLD HICKORY", "WHITES CREEK", "JOELTON", "DONELSON",
  "BELLEVUE", "BERRY HILL", "OAK HILL", "FOREST HILLS", "BELLE MEADE",
  "CANE RIDGE", "LAKEWOOD"
)

#' Flag grant recipients located in Davidson County
#'
#' @param recipient_ein9 Character: recipient EIN as nine digits, NA or "" when
#'   the return carries none.
#' @param recipient_state Character: recipient state as filed.
#' @param recipient_city Character: recipient city as filed.
#' @param recipient_zip5 Character: first five digits of the recipient ZIP, NA
#'   or "" when missing.
#' @param bmf_county_by_ein Named character vector: county FIPS for every EIN
#'   on the Tennessee BMF extract, names are nine-digit EINs.
#' @param davidson_zips Character vector of five-digit ZIP codes that belong
#'   to Davidson County.
#' @return A list of two vectors the length of the inputs: `in_davidson`
#'   (logical) and `located_by` ("EIN on the BMF", "Tennessee ZIP code",
#'   "city name", or "outside Tennessee").
#' @details An EIN found on the Tennessee BMF decides on its own, even when
#'   the mailing address says otherwise, because the BMF county is the
#'   definition the rest of this request uses. An EIN not found there falls
#'   through to the address.
recipient_in_davidson <- function(recipient_ein9, recipient_state, recipient_city,
                                  recipient_zip5, bmf_county_by_ein, davidson_zips) {
  ein_clean <- gsub("[^0-9]", "", ifelse(is.na(recipient_ein9), "", recipient_ein9))
  ein_county <- unname(bmf_county_by_ein[ein_clean])
  ein_known <- !is.na(ein_county)

  state_clean <- toupper(trimws(ifelse(is.na(recipient_state), "", recipient_state)))
  city_clean <- toupper(trimws(ifelse(is.na(recipient_city), "", recipient_city)))
  zip_clean <- substr(gsub("[^0-9]", "", ifelse(is.na(recipient_zip5), "", recipient_zip5)), 1, 5)

  in_tennessee <- state_clean == "TN"
  zip_known <- in_tennessee & nchar(zip_clean) == 5

  located_by <- dplyr::case_when(
    ein_known ~ "EIN on the BMF",
    !in_tennessee ~ "outside Tennessee",
    zip_known ~ "Tennessee ZIP code",
    TRUE ~ "city name"
  )
  in_davidson <- dplyr::case_when(
    ein_known ~ ein_county == "47037",
    !in_tennessee ~ FALSE,
    zip_known ~ zip_clean %in% davidson_zips,
    TRUE ~ city_clean %in% davidson_cities
  )
  list(in_davidson = in_davidson, located_by = located_by)
}


#' Build the two lookups the rule needs from the Tennessee BMF extract
#'
#' @param universe_tn Data frame of the Tennessee BMF extract with columns
#'   `ein9`, `geo_county_fips` and `org_addr_zip5`.
#' @return A list: `county_by_ein`, a named character vector of county FIPS
#'   by nine-digit EIN; and `davidson_zips`, the ZIP codes where more than
#'   half of the Tennessee organizations with that ZIP are placed in
#'   Davidson County by the BMF geocoding.
#' @details A few ZIPs straddle the county line (Goodlettsville, Old
#'   Hickory, Joelton); the majority rule assigns each whole ZIP one way,
#'   which is the limit of an address-based proxy.
davidson_lookups <- function(universe_tn) {
  county_by_ein <- stats::setNames(universe_tn$geo_county_fips, universe_tn$ein9)
  county_by_ein <- county_by_ein[!is.na(county_by_ein)]

  zip_shares <- universe_tn |>
    dplyr::filter(!is.na(org_addr_zip5), !is.na(geo_county_fips)) |>
    dplyr::group_by(org_addr_zip5) |>
    dplyr::summarise(davidson_share = mean(geo_county_fips == "47037"), .groups = "drop")
  davidson_zips <- zip_shares$org_addr_zip5[zip_shares$davidson_share > 0.5]

  list(county_by_ein = county_by_ein, davidson_zips = davidson_zips)
}
