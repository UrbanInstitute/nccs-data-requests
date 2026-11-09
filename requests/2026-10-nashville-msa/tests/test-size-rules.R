library(testthat)
source(file.path(dirname(getwd()), basename(getwd()), "size-rules.R"))

test_that("the three bands split at one million and ten million dollars", {
  expect_equal(
    size_band(c(0, 999999, 1e6, 9999999, 1e7, 5e8)),
    c("Small", "Small", "Medium", "Medium", "Large", "Large")
  )
})

test_that("a missing amount gives a missing band", {
  expect_equal(size_band(c(NA_real_, 2e6)), c(NA_character_, "Medium"))
})

test_that("a negative amount is refused", {
  expect_error(size_band(-1), "negative")
})
