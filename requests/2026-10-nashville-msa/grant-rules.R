# Rules shared by every script that reads the 990-PF grants-paid list.

#' Flag 990-PF grant rows that went to an individual rather than an organization
#'
#' @param status Character: the recipient status field as filed
#'   (PF_15_G_PAID_RECIP_STAT), for example "PC", "PUBLIC", "I", "NONE".
#' @param org_name Character: the organization-name field as filed.
#' @param person_name Character: the person-name field as filed.
#' @return Logical, the length of the inputs: TRUE where the grant went to an
#'   individual.
#' @details Some filers put the organization's name in the person-name field
#'   while giving it an organization status code such as PC or PUBLIC. So the
#'   name fields alone cannot decide. A status that says individual (I, IND,
#'   INDIVIDUAL, INDIVIDUALS) decides for individual. A status that names an
#'   organization type decides for organization, whichever name field holds
#'   the name. Only when the status says nothing (blank, NONE, N/A) does the
#'   row count as an individual, and then only if no organization name was
#'   filed. Compare: the earlier rule flagged every row with a person-name
#'   entry, which dropped $40 million of grants to organizations over
#'   2019-2023 across the Davidson funders.
pf_recipient_is_individual <- function(status, org_name, person_name) {
  status_clean <- toupper(trimws(ifelse(is.na(status), "", status)))
  org_blank <- is.na(org_name) | !nzchar(trimws(org_name))

  says_individual <- grepl("^(I|IND|INDIVIDUAL|INDIVIDUALS)$", status_clean)
  says_nothing <- status_clean %in% c("", "NONE", "N A", "N/A", "NA")

  says_individual | (says_nothing & org_blank)
}


#' Choose which tax year's itemized grants a funder's sheet columns use
#'
#' @param years_with_rows Integer vector: the tax years for which the funder
#'   has itemized grant rows (any order, duplicates allowed).
#' @param has_2023_return TRUE if the funder filed any tax year 2023 return
#'   in the releases, whether or not it itemized grants on it.
#' @return 2023 if the funder has 2023 rows; 2022 only if it has 2022 rows
#'   and no 2023 return at all; otherwise NA.
#' @details A funder that filed for 2023 but listed no grants is reported
#'   as having none for 2023, not carried back to 2022: missing itemized
#'   rows are not missing data. The fallback is for funders whose 2023
#'   return is not in the releases yet (requester's instruction, 2026-11-04).
grant_year_to_use <- function(years_with_rows, has_2023_return) {
  if (2023L %in% years_with_rows) {
    return(2023L)
  }
  if (2022L %in% years_with_rows && !isTRUE(has_2023_return)) {
    return(2022L)
  }
  NA_integer_
}
