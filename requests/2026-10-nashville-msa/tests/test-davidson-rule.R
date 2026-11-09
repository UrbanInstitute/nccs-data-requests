# Tests for recipient_in_davidson() in ../davidson-rule.R. Run from the
# request folder with: Rscript tests/test-davidson-rule.R

library(testthat)
source("davidson-rule.R")

county <- c("111111111" = "47037", "222222222" = "47149")
zips <- c("37203", "37206")
known <- c("37203", "37206", "37072")

test_that("an EIN on the BMF decides by its county, whatever the address says", {
  r <- recipient_in_davidson(c("11-1111111", "222222222"), c("CO", "TN"), c("BOULDER", "NASHVILLE"), c("80301", "37203"), county, zips, known)
  expect_equal(r$in_davidson, c(TRUE, FALSE))
  expect_equal(r$located_by, c("EIN on the BMF", "EIN on the BMF"))
})

test_that("without a known EIN, a Tennessee ZIP decides", {
  r <- recipient_in_davidson(c(NA, "999999999"), c("TN", "TN"), c("GOODLETTSVILLE", "GOODLETTSVILLE"), c("37206", "37072"), county, zips, known)
  expect_equal(r$in_davidson, c(TRUE, FALSE))
  expect_equal(r$located_by, c("Tennessee ZIP code", "Tennessee ZIP code"))
})

test_that("without a ZIP, the city name decides, and spelling variants count", {
  r <- recipient_in_davidson(c("", NA), c("tn", "TN"), c("Nashvile ", "MURFREESBORO"), c(NA, ""), county, zips, known)
  expect_equal(r$in_davidson, c(TRUE, FALSE))
  expect_equal(r$located_by, c("city name", "city name"))
})

test_that("a Tennessee ZIP the BMF does not know falls back to the city", {
  r <- recipient_in_davidson(c(NA, NA), c("TN", "TN"), c("NASHVILLE", "FRANKLIN"), c("37244", "37244"), county, zips, known)
  expect_equal(r$in_davidson, c(TRUE, FALSE))
  expect_equal(r$located_by, c("city name", "city name"))
})

test_that("an address outside Tennessee is never Davidson", {
  r <- recipient_in_davidson(NA, "KY", "NASHVILLE", "37203", county, zips, known)
  expect_false(r$in_davidson)
  expect_equal(r$located_by, "outside Tennessee")
})
