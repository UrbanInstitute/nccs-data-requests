# Tests for pf_recipient_is_individual() in ../grant-rules.R. Run from the
# request folder with: Rscript tests/test-grant-rules.R

library(testthat)
source("grant-rules.R")

test_that("a status that says individual decides, whatever the names", {
  expect_true(pf_recipient_is_individual("I", "", "Jane Doe"))
  expect_true(pf_recipient_is_individual(" individual ", "Some Org", ""))
})

test_that("an organization status decides for organization even when the name sits in the person field", {
  expect_false(pf_recipient_is_individual("PC", "", "EAST NASHVILLE HOPE EXCHANGE"))
  expect_false(pf_recipient_is_individual("PUBLIC", NA, "Backfield in Motion"))
  expect_false(pf_recipient_is_individual("501(C)3", "", "Oasis Center"))
})

test_that("a status that says nothing counts as individual only when no organization name was filed", {
  expect_true(pf_recipient_is_individual("", "", "Hannah Evans"))
  expect_true(pf_recipient_is_individual("N/A", NA, "Ryan Link"))
  expect_true(pf_recipient_is_individual("NONE", "", ""))
  expect_false(pf_recipient_is_individual("", "Second Harvest Food Bank", ""))
  expect_false(pf_recipient_is_individual(NA, "Alive Hospice", "Buckner"))
})

test_that("it is vectorised and keeps order", {
  out <- pf_recipient_is_individual(c("I", "PC", ""), c("", "", "Org"), c("A", "B", ""))
  expect_equal(out, c(TRUE, FALSE, FALSE))
})


test_that("2022 grants are used only when the funder has no 2023 return at all", {
  expect_equal(grant_year_to_use(c(2022L, 2023L), has_2023_return = TRUE), 2023L)
  expect_equal(grant_year_to_use(2022L, has_2023_return = FALSE), 2022L)
  expect_equal(grant_year_to_use(2022L, has_2023_return = TRUE), NA_integer_)
  expect_equal(grant_year_to_use(integer(0), has_2023_return = FALSE), NA_integer_)
})
