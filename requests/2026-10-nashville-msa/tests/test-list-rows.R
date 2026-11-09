# Tests for assign_list_row_ids() in ../list-rows.R. Run from the request
# folder with: Rscript tests/test-list-rows.R (paths are relative to the request folder)

library(testthat)
source("list-rows.R")

test_that("original names keep their ids and additions are numbered after them in sheet order", {
  original <- c("Alpha", "Beta", "Gamma")
  sheet <- c("Alpha", "New one", "Beta", "New two", "Gamma")
  expect_equal(assign_list_row_ids(original, sheet), c(1L, 4L, 2L, 5L, 3L))
})

test_that("surrounding spaces do not break the match", {
  expect_equal(assign_list_row_ids(c("Alpha "), c(" Alpha", "Zed")), c(1L, 2L))
})

test_that("a sheet that drops an original name is refused", {
  expect_error(assign_list_row_ids(c("Alpha", "Beta"), c("Alpha", "New")), "missing")
})

test_that("a sheet that repeats a name is refused", {
  expect_error(assign_list_row_ids(c("Alpha"), c("Alpha", "Alpha")), "repeated")
})
