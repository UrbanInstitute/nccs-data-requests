# Tests for add_irs_tax_year() in ../tax-year-rule.R. Run from the request
# folder with: Rscript tests/test-tax-year-rule.R

library(testthat)
source("tax-year-rule.R")

core <- dplyr::tibble(
  ein = c("11-1111111", "22-2222222", "33-3333333", "44-4444444"),
  source_form = c("990", "990", "990", "990ez"),
  tax_period = c(202312L, 202306L, 202306L, 202106L)
)
headers <- dplyr::tibble(
  ein9 = c("333333333", "444444444"),
  source_form = c("990", "990ez"),
  tax_period = c("202306", "202106"),
  header_tax_year = c(2023L, 2021L)
)

test_that("a December year end is that year, any other month the year before", {
  r <- add_irs_tax_year(core)
  expect_equal(r$irs_tax_year, c(2023L, 2022L, 2022L, 2020L))
  expect_true(all(is.na(r$header_tax_year)))
})

test_that("the tax year stated on the return wins where the return is e-filed", {
  r <- add_irs_tax_year(core, headers)
  expect_equal(r$irs_tax_year, c(2023L, 2022L, 2023L, 2021L))
  expect_equal(r$inferred_tax_year, c(2023L, 2022L, 2022L, 2020L))
})

test_that("a header for a different form does not match", {
  wrong_form <- headers |> dplyr::mutate(source_form = "990ez")
  r <- add_irs_tax_year(core[3, ], wrong_form)
  expect_equal(r$irs_tax_year, 2022L)
})

test_that("no rows are added or lost", {
  expect_equal(nrow(add_irs_tax_year(core, headers)), nrow(core))
})
