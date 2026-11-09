# Tests for count_filing_gap() in ../exit-rule.R. Run from the request
# folder with: Rscript tests/test-exit-rule.R

library(testthat)
source("exit-rule.R")

# Five organizations that all filed for 2015:
#   A files every year                      -> never a gap
#   B skips 2016, files 2017                -> no two-year gap
#   C skips 2016 and 2017, files 2018       -> two-year gap, files again
#   D skips 2016 to 2018, files 2019        -> two- and three-year gap, files again
#   E never files again                     -> every gap, never files again
filed_years <- dplyr::bind_rows(
  dplyr::tibble(ein9 = "A", form_year = 2015:2020),
  dplyr::tibble(ein9 = "B", form_year = c(2015L, 2017:2020)),
  dplyr::tibble(ein9 = "C", form_year = c(2015L, 2018:2020)),
  dplyr::tibble(ein9 = "D", form_year = c(2015L, 2019L, 2020L)),
  dplyr::tibble(ein9 = "E", form_year = 2015L)
)

test_that("a two-year gap counts organizations with no return in the next two years", {
  r <- count_filing_gap(filed_years, last_year = 2015L, gap_years = 2L, final_year = 2020L)
  expect_equal(r$filers, 5L)
  expect_equal(r$with_gap, 3L)
})

test_that("organizations that file after the gap are counted as filing again", {
  r <- count_filing_gap(filed_years, last_year = 2015L, gap_years = 2L, final_year = 2020L)
  expect_equal(r$filed_again, 2L)
  r3 <- count_filing_gap(filed_years, last_year = 2015L, gap_years = 3L, final_year = 2020L)
  expect_equal(r3$with_gap, 2L)
  expect_equal(r3$filed_again, 1L)
})

test_that("a return after the final year is not seen", {
  r <- count_filing_gap(filed_years, last_year = 2015L, gap_years = 2L, final_year = 2018L)
  expect_equal(r$filed_again, 1L)
  expect_equal(r$years_observed_after_gap, 1L)
})

test_that("when the gap ends at the final year, filing again cannot be known", {
  r <- count_filing_gap(filed_years, last_year = 2015L, gap_years = 3L, final_year = 2018L)
  expect_equal(r$with_gap, 2L)
  expect_true(is.na(r$filed_again))
  expect_equal(r$years_observed_after_gap, 0L)
})

test_that("only organizations that filed for the last year are counted", {
  r <- count_filing_gap(filed_years, last_year = 2016L, gap_years = 2L, final_year = 2020L)
  expect_equal(r$filers, 1L)
  expect_equal(r$with_gap, 0L)
})
