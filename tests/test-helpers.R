# test.R

suppressPackageStartupMessages(library(testthat))
suppressPackageStartupMessages(library(dplyr))
library(readxl)
library(stringr)

source(file.path(getwd(), "src/helpers.R"))

############################################
context("Importation of Excel files into R")

samplFile1 <- excelFile(file.path(getwd(), 'tests/test-file-1.xls'))
samplFile2 <- excelFile(file.path(getwd(), "tests/test-file-2.xlsx"))

test_that("Objects are properly instantiated", {
    expect_is(samplFile1, "excelFile")
    expect_is(samplFile2, "excelFile")
    expect_s3_class(samplFile1, "excelFile")
    expect_s3_class(samplFile2, "excelFile")
    expect_type(samplFile1$fileName, "character")
    expect_type(samplFile1$fileSize, "double")
    expect_type(samplFile1$created, "double")
    expect_type(samplFile1$modified, "double")
    expect_type(samplFile1$noOfSheets, "integer")
    expect_type(samplFile1$sheets, "character")
    expect_type(samplFile2$data, "list")
    expect_type(samplFile2$fileName, "character")
    expect_type(samplFile2$fileSize, "double")
    expect_type(samplFile2$created, "double")
    expect_type(samplFile2$modified, "double")
    expect_type(samplFile2$noOfSheets, "integer")
    expect_type(samplFile2$sheets, "character")
    expect_type(samplFile2$data, "list")
})


################################################
context("Integrity of individual spreadsheets")

header <- c("serialno", "name", "phone", "address", "email", "bday.day",
            "bday.mth", "wedann.day", "wedann.mth", "occupation", "church",
            "pastor", "info.source")

singleWrkSht1 <- extract_spreadsheets(samplFile1) %>% .[[1]]
singleWrkSht2 <- extract_spreadsheets(samplFile2) %>% .[[1]]

SheetsList <- lapply(list(singleWrkSht1, singleWrkSht2), function(dfr) {
    beacon <- locate_header(dfr, hdr = header)
    dfr <- dfr %>%
        slice(beacon$nextrow:n())
    colnames(dfr) <- beacon$header
    dfr
})

singleWrkSht1 <- SheetsList[[1]]
singleWrkSht2 <- SheetsList[[2]]

test_that("Spreadsheets are properly extracted", {
    expect_is(singleWrkSht1, "tbl_df")
    expect_is(singleWrkSht1, "tbl")
    expect_is(singleWrkSht1, "data.frame")
    expect_false(inherits(singleWrkSht1, "excelFile"))
    expect_is(singleWrkSht2, "tbl_df")
    expect_is(singleWrkSht2, "tbl")
    expect_is(singleWrkSht2, "data.frame")
    expect_false(inherits(singleWrkSht2, "excelFile"))
})


###################################
context("Regex pattern matching")

test_that("Object class with regex patterns is properly instantiated", {
    column <-
        c("24 Feb/7 Sept",
          "43322",
          "17 January",
          "15 Oct",
          NA,
          "May 5/Jun 12",
          "6/04")
    
    ## To be continued... 
})



###################################
context("Ensuring data integrity.")

test_that("Wrong mobile numbers are repaired or removed.", {
    numbers <-
        as.data.frame(
            c(
                "123456789",
                "0123456789",
                "8000000001",
                "9012345678",
                "07098765432",
                "08123456789",
                "09064321987",
                "O8055577889",
                "070456789011"
            )
        )
    numbers <- .fix_phone_numbers(numbers)
    
    # Tests proper
    expect_type(numbers, "character")
    expect_true(is.na(numbers[1]))
    expect_true(all(nchar(na.omit(numbers)) == 11))
})


##################################################
context("Structural modification of data frames")

test_that("'Month' values are corrected.", {
    mths <- 
        c("Apl", "oct ", "September", "Jul", "january", "aug", "decc", "  March")
    mths <- .fix_mth_entries(mths)
    failed <- c("May/Jun 12", "24 Feb/Sept")
    
    expect_equal(mths[[1]][1], "April")
    expect_equal(mths[[1]][2], "October")
    expect_equal(mths[[1]][3], "September")
    expect_equal(mths[[1]][4], "July")
    expect_equal(mths[[1]][5], "January")
    expect_equal(mths[[1]][6], "August")
    expect_equal(mths[[1]][7], "December")
    expect_equal(mths[[1]][8], "March")
    expect_error(.fix_mth_entries("Mar."),
                 "An invalid character was found at position 1.")
    expect_error(.fix_mth_entries(failed), "An invalid character")
})

test_that("Date entries are fixed", {
    mail1 <- data.frame(Name = c("Abe McDonald", "Max Horst", "Ada Obi"),
                        EMAIL = c("abo@mail.com", NA, "adaobi@hot.com"),
                        BIRTHDAY = c("12-oct", "13/06/1985", "Mar.18"),
                        stringsAsFactors = FALSE)
    mail2 <- data.frame(
        NAME = c("Heather Rowe", "Zainab Umar", "Tinuke"),
        `BIRTHDAY AND WED ANN` = c("12 June 1982", "Apl. 23", "23rd Dec"),
        `WED ANN` = c("", "10/4", "January 5th"),
        stringsAsFactors = FALSE, check.names = FALSE)
    
    newDates1 <- fix_funny_date_entries(mail1)
    newDates2 <- fix_funny_date_entries(mail2)

    # Add a test for cases when there are no funny looking columns
    expect_is(newDates1, "data.frame")
    expect_is(newDates2, "data.frame")
    expect_false(identical(ncol(mail1), ncol(newDates1)))
    expect_false(identical(ncol(mail2), ncol(newDates2)))
    expect_false(ncol(mail1) == ncol(newDates1))
    expect_false(ncol(mail2) == ncol(newDates2))
    expect_equal(newDates1$bday.day[1], "12")
    expect_equal(newDates1$bday.mth[1], "October")
    expect_equal(newDates1$bday.day[2], "13")
    expect_equal(newDates1$bday.mth[2], "June")
    expect_equal(newDates1$bday.day[3], "18")
    expect_equal(newDates1$bday.mth[3], "March")
    expect_equal(newDates2$bday.day[1], "12")
    expect_equal(newDates2$bday.mth[1], "June")
    expect_equal(newDates2$bday.day[2], "23")
    expect_equal(newDates2$bday.mth[2], "April")
    expect_equal(newDates2$bday.day[3], "23")
    expect_equal(newDates2$bday.mth[3], "December")
})

test_that("Numeric Excel date entries are converted to text format.", {
    result <- .convert_num_date_to_char(c("41235", "43322"))
    
    expect_equal(result[1], "22 November")
    expect_equal(result[2], "10 August")
})


test_that("Unwanted characters/entries are removed entirely", {
    
    smpl <- c("24 Feb/Sept",
              "Mar/Jun 10",
              "April. 4",
              "Aug, 6",
              "12/05/1989",
              "31 Oct/6 July")
    smpl <- .preprocess_date_entry(smpl)
    
    expect_equal(smpl[1], "24 Feb")
    expect_equal(smpl[2], "")
    expect_equal(smpl[3], "April  4")
    expect_equal(smpl[4], "Aug  6")
    expect_equal(smpl[5], "12/05")
    expect_equal(smpl[6], "31 Oct/6 July")  # unchanged
})
