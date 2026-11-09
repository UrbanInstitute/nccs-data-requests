# Row numbering for the requester's organization list.
#
# The hand-checked match decisions are keyed by row id, so an id must never
# change once assigned. The requester sends additions by inserting rows
# into her copy of the sheet, so the sheet order is not the id order.

#' Assign stable row ids to the names on the requester's sheet
#'
#' @param original_names Character vector: the names in the first list the
#'   requester sent, in its order. Their ids are their positions, 1 to n.
#' @param sheet_names Character vector: the names on the sheet she returned,
#'   in its order, with the additions inserted anywhere.
#' @return Integer vector, one id per element of `sheet_names`: the original
#'   id for a name from the first list, and n + 1, n + 2, ... for the
#'   additions in the order they appear on the sheet.
#' @details Names are compared after trimming surrounding spaces. The
#'   function stops if an original name is missing from the sheet or a name
#'   appears twice, because either would silently misattach a decision.
assign_list_row_ids <- function(original_names, sheet_names) {
  original_clean <- trimws(original_names)
  sheet_clean <- trimws(sheet_names)

  missing_names <- setdiff(original_clean, sheet_clean)
  if (length(missing_names) > 0) {
    stop("original names missing from the sheet: ", paste(missing_names, collapse = "; "))
  }
  repeated_names <- unique(sheet_clean[duplicated(sheet_clean)])
  if (length(repeated_names) > 0) {
    stop("names repeated on the sheet: ", paste(repeated_names, collapse = "; "))
  }

  original_id <- match(sheet_clean, original_clean)
  is_added <- is.na(original_id)
  added_id <- length(original_clean) + cumsum(is_added)

  as.integer(ifelse(is_added, added_id, original_id))
}
