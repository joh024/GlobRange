library(testthat)
source("globRange.R")

expect_identical(
  dateRangeGlob(
    startDate = "2020-03-24",
    endDate = "2020-03-29"
  ),
  "2020032[4-9]*.csv.gz"
)

expect_identical(
  dateRangeGlob(
    startDate = "2020-03-24",
    endDate = "2020-04-10"
  ),
  "20200{32[4-9],3[3-9],40,410}*.csv.gz"
)

expect_identical(
  dateRangeGlob(
    startDate = "2020-03-24",
    endDate = "2020-04-15"
  ),
  "20200{32[4-9],3[3-9],40,41[0-5]}*.csv.gz"
)

expect_identical(
  dateRangeGlob(
    startDate = "2020-03-24",
    endDate = "2020-08-01"
  ),
  "20200{32[4-9],3[3-9],[4-7],80[0-1]}*.csv.gz"
)

expect_identical(
  dateRangeGlob(
    startDate = "2020-03-24",
    endDate = "2020-12-31"
  ),
  "2020{032[4-9],03[3-9],0[4-9],1[0-1],12[0-2],123[0-1]}*.csv.gz"
)
