# helpers.R

#####################################
##         Base data types         ##
#####################################

## The names of the columns of the new table
columnNames <- c(
    "serialno",
    "name",
    "phone",
    "address",
    "email",
    "bday.day",
    "bday.mth",
    "wedann.day",
    "wedann.mth",
    "occupation",
    "church",
    "pastor",
    "info.source"
)

################################
##         S3 objects         ##
################################

## Constructs S3 objects of class 'excelFile', which contain 
## properties associated with .xls/.xlsx files
excelFile <- function(file) {
    require(readxl)
    
    ## Identify individual spreadsheets
    sheetNames <-  excel_sheets(file)
    sheetList <- lapply(sheetNames, function(sht) {
        read_excel(path = file,
                   sheet = sht,
                   col_types = "text")
    })
    
    prop <- file.info(file)
    exf <- structure(
        list(
            fileName = file,
            fileSize = prop$size,
            created = prop$ctime,
            modified = prop$mtime,
            noOfSheets = length(sheetNames),
            sheets = sheetNames,
            data = sheetList
        ),
        class = "excelFile"
    )
    # TODO: Apply some limits.
}





## S3 method to output information on the object
print.excelFile <- function(xlObj) {
    cat(sprintf(
        ngettext(
            xlObj$noOfSheets,
            "Filename: %s with %s spreadsheet.\n",
            "Filename: %s with %s spreadsheets.\n"
        ),
        xlObj$fileName,
        xlObj$noOfSheets
    ))
    cat("Data: \n")
    print(xlObj$data)
}







## S3 method to provide a summary of the object
summary.excelFile <- function(xlobj) {
    cat(paste0(
        "File: ",
        sQuote(xlObj$fileName),
        ". Size:",
        xlObj$fileSize,
        "B\n"
    ))
    cat("Spreadsheet(s):\n")
    for (i in 1:xlObj$noOfSheets) {
        cat(paste0(i, ". ", sQuote(xlObj$sheets), "\n"))
    }
}









## S3 Object for regular expressions
##  It establishes the patterns for entries that have:
##   => two numbers separated by a forward slash e.g. 10/6
##   => two day-month combos separated by a fwd slash e.g. May 6/June 12
##   => a "DD Month" e.g. 15 Oct
##   => an Excel date numeral e.g. "43322" equiv. to 12 Aug 2018
##   => entries that have three date fields e.g. 13/03/2001, 13th March 2001
regexPatterns <- function() {
    day_first <- "([0-3]*[0-9])(\\s+)([[:alpha:]]{3,})"
    mth_first <- "([[:alpha:]]{3,})(\\s+)([0-3]*[0-9])"
    beg <- "^"
    end <- "$"
    slash <- "(\\s*/\\s*)"
    structure(
        list(
            date_numeral = "^[1-9][0-9]{4}$",
            num_slash_num = 
                paste0(beg, "([0-3]*[0-9])", slash, "([0-3][0-9])", end),
            single_day_first = paste0(beg, day_first, end),
            single_mth_first = paste0(beg, mth_first, end),
            double_day_first =
                paste0(beg, day_first, slash, day_first, end),
            double_mth_first =
                paste0(beg, mth_first, slash, mth_first, end)
        ),
        class = "regexPatterns"
    )
}












## S3 object for determinating which indices match any of the patterns
## in the 'regexPattern' object, within a particular date-related column
## @note Objects of this class must not be created until all pure 'numerical'
## date entries have been converted to character DD-MM or MM-DD values.
regexIndices <- function(rules, col) {
    ls <- lapply(rules, function(x) grep(x, col, ignore.case = TRUE))
    
    allIndices <- c(ls$numeral,
                    ls$twoNum,
                    ls$single_day_f,
                    ls$single_mth_f,
                    ls$double_day_f,
                    ls$double_mth_f)
    
    if (anyDuplicated(allIndices)) {
        dups <- duplicated(allIndices)
        stop(
            "A pattern-matching conflict occurred, with duplications at pos ",
             sQuote(which(dups))
            )
    }
    
    if (any(grepl("^\\d+$", col)))
        stop("Numbers-only values must be converted
             before creating objects of this class.")
    
    attr(ls, "class") <-  "regexIndices"
    invisible(ls)
}

###################################################################
##         Custom functions created for 'narc-dfmerge.R'         ##
###################################################################


## Loads the packages needed to work with the project, and where any is
## missing, downloads it from CRAN and installs for loading.
load_packages <- function(pkgs) {
    isLoaded <-
        suppressPackageStartupMessages(sapply(
            pkgs,
            require,
            character.only = TRUE,
            quietly = TRUE
        ))
    missingPkgs <- pkgs[!isLoaded]
    if (length(missingPkgs)) {
        install.packages(as.character(missingPkgs),
                         repos = "https://cran.rstudio.com")
        suppressPackageStartupMessages(
            lapply(missingPkgs, library, character.only = TRUE)
            )
    }
    
    if (any(!pkgs %in% (.packages())))
        stop("Required packages are not installed or loaded.")
}








## Finds all existing Excel files within a given directory

find_excel_files <- function(path = ".") {
    # TODO: There are situations when a file's extension
    # may not be specified and thus there may be need to
    # test such files to know whether they are of the format.
    xlFiles <-
        list.files(path, pattern = ".xlsx$|.xls$", full.names = TRUE) %>%
        subset(!grepl("^~", .))    # remove any backup files (Windows)
    
    numFiles <- length(xlFiles)
    if (!numFiles) {
        stop("There are no Excel files in this directory.")
    } else {
        cat(sprintf(
            ngettext(
                numFiles,
                "\t%d Excel file was found in %s:\n",
                "\t%d Excel files were found in %s:\n"
            ),
            numFiles, sQuote(path.expand(path))
        ))
        
        ## List the files
        sapply(xlFiles, function(x) {
            cat(sprintf("\t  * %s\n", basename(x)))
        })
    }
    
    invisible(xlFiles)
}






## Extracts spreadsheets from an excelFile object.
## Note that this function cannot retrieve spreadsheets
## directly from an unprocessed .xls/.xlsx file
extract_spreadsheets <- function(fileObj) {
    if (inherits(fileObj, "excelFile")) {
        lapply(fileObj$data, function(dat) return(dat))
    }
    else {
        stop("'fileObj' is not an 'excelFile' object.")
    }
}










## Finds the row that likely contains the actual header and
## returns an S3 object that is a marker to the row it occupies
locate_header <- function(df, hdr, quietly = TRUE) {
    if (!is.data.frame(df))
        stop("'df' is not a valid data frame")
    if (!is.character(hdr))
        stop("'hdr' is not a character vector")
    
    ## Iterate row-wise
    val <- NULL
    for (i in 1:nrow(df)) {
        ## Check whether we hit something that looks like column names
        ## and when we do, stop looking.
        if (any(hdr %in% tolower(df[i, ]))) {
            if (!quietly) {
                cat(
                    paste0(
                        "\tA header candidate was found on row ",
                        i,
                        ":\n\t"
                    ),
                    sQuote(df[i, ]),
                    "\n"
                )
            }
            hdr <- as.character(df[i,])
            val <- structure(list(
                header = hdr,
                rownum = i,
                nextrow = i + 1
            ),
            class = "header-locator")
            break
        }
    }
    invisible(val)
}










## Updates old column names of the data frame with the new
## ones that are to be used in the harmonised version
update_header <- function(df, newCol) {
    if (!is.data.frame(df))
        stop("'df' is not a valid data frame")
    
    stopifnot(length(newCol) == 13)
    
    if (!is.character(newCol))
        stop("'newCol' is not a character vector")
    
    initialHdr <- colnames(df)
    modifiedHdr <- sapply(initialHdr, function(thisCol) {
        ## These are the values we're picking from 'newCol':
        ### [1]  "serialno"     [2]  "name"        [3]  "phone"
        ### [4]  "address"      [5]  "email"       [6]  "bday.day"
        ### [7]  "bday.mth"     [8]  "wedann.day"  [9]  "wedann.mth"
        ### [10] "occupation"   [11] "church"      [12] "pastor"
        ### [13] "info.source"
        if (identical(thisCol, "S/N"))
            thisCol <- newCol[1]
        else if (grepl("name", tolower(thisCol)))
            thisCol <- newCol[2]
        else if (grepl("number|phone", tolower(thisCol)))
            thisCol <- newCol[3]
        else if (grepl("ress$", tolower(thisCol))
                 & !newCol[4] %in% tolower(thisCol))
            thisCol <- newCol[4]
        else if (newCol[5] %in% tolower(thisCol))
            thisCol <- newCol[5]
        else if ("bday.day" %in% thisCol)
            thisCol <- newCol[6]
        else if ("bday.mth" %in% thisCol)
            thisCol <- newCol[7]
        else if ("wedann.day" %in% thisCol)
            thisCol <- newCol[8]
        else if ("wedann.mth" %in% thisCol)
            thisCol <- newCol[9]
        else if (grepl("occupation", thisCol, ignore.case = TRUE))
            thisCol <- newCol[10]
        else if (grepl("church", tolower(thisCol)))
            thisCol <- newCol[11]
        else if (grepl("pastor$", tolower(thisCol)))
            thisCol <- newCol[12]
        else if (grepl("know", thisCol, ignore.case = TRUE))
            thisCol <- newCol[13]
        
        ## Note: [6] - [9] have been taken care of in an earlier step.
    })
    colnames(df) <- modifiedHdr
    invisible(df)
}








## Rearranges the columns of data frames to suit the prescribed
## format. Columns without values are assigned NA.
rearrange_df <- function(df, hdr) {
    if (!is.data.frame(df))
        stop("'df' is not a valid data frame.")
    if (!is.character(hdr))
        stop("'hdr' ought to be a character vector.")
    
    height <- nrow(df)
    oldHeader <- colnames(df)
    newDf <- data.frame(seq_along(height))
    
    for (i in 2:length(hdr)) {
        x <- hdr[i]
        
        if (x %in% oldHeader) {
            index <- match(x, oldHeader)
            newCol <- df[, index]
        } else {
            newCol <- rep(NA, height)
        }
        
        newDf <- cbind(newDf, newCol)
    }
    
    colnames(newDf) <- hdr
    newDf
}







## Combines all the data frames in the list into one master data frame
combine_dfs <- function(dfs) {
    final <- dfs[[1]]
    for (i in 2:length(dfs)) {
        singleton <- dfs[[i]]
        final <- bind_rows(final, singleton)
    }
    final
}








## Sets the columns to the appropriate data types
set_datatypes <- function(df) {
    df$serialno <- seq_along(df$serialno)
    
    df$phone <- .fix_phone_numbers(df$phone)
    
    ## TODO: Undo hard coding
    for (i in c(2, 4:5))
        df[[i]] <- as.character(df[[i]])
    
    for (i in c(7, 9:13))
        df[[i]] <- as.factor(df[[i]])
    
    for (i in c(6, 8))
        df[[i]] <- as.integer(df[[i]])
    
    invisible(df)
}









## Fixes up mobile numbers to a uniform text format
.fix_phone_numbers <- function(column) {
    # Remove entries that are beyond redemption i.e. too long or too short
    column <- column %>%
        ifelse(nchar(.) > 11 | nchar(.) < 10, NA_character_, .)
    
    # Add a leading '0' if there are 10 digits
    column <- column %>%
        as.character() %>%
        gsub("(^[0-9]{10}$)", "0\\1", .)
    
    # Remove those that still don't look like local mobile numbers (NG)
    column <- column %>%
        ifelse(grepl("^0[7-9][0-1][0-9]{8}$", .), ., NA_character_)
}










## Corrects the various kinds of date entries found in the dataset by
## creating new columns that contain only day and month values
fix_date_entries <- function(df) {
    ## Identify by name columns in the original data frame
    ## that are likely to contain the awkard entries
    awkward <- c(
        "BDAY/WED ANN",
        "BIRTHDAY AND WEDDING ANN",
        "WED ANN",
        "BIRTHDAY",
        "BDAY",
        "BIRTHDAY AND WED ANN"
    )
    
    fields <- colnames(df)
    
    indexAwk <- match(awkward, fields) %>%
        na.exclude() %>%
        sort()
    
    if (length(indexAwk)) {
        awkColHdr <- fields[indexAwk]
        tempdf <- .process_date_entries(df, awkColHdr)
        df <- bind_cols(df, tempdf)
        
        df <- df[, -indexAwk]
    }
    df
}










## Moves down a column with date entries to carry out
## necessary processing. Principally these 3 actions take place:
## 1. Cleaning up of entries
## 2. Conversion of 'pure' numbers to day/month (in words)
## 3. Assignment of day and month values to new distinct columns
## 4. Changing of all abbreviated month names to full version
## @return a four-column data frame with days and months of
## birthdays and wedding anniversaries, respectively
.process_date_entries <- function(df, columnNames) {
    stopifnot(is.character(columnNames)) # TODO: Rather pattern compatibility?
    newColHdr <- c("bday.day", "bday.mth", "wedann.day", "wedann.mth")
    temp.df <-
        data.frame(
            matrix("", nrow = nrow(df), ncol = length(newColHdr)),
            stringsAsFactors = FALSE)
    lapply(columnNames, function(name) {
        column <- df[[name]] %>%
            .cleanup_date_entries()
        
        column <- sapply(column, .convert_num_date_to_char, USE.NAMES = FALSE)

        temp.df <<- .distribute_date_vals(temp.df, column)
    })
    colnames(temp.df) <- newColHdr
    temp.df <- .change_to_full_mth_names(temp.df)
}










## Converts entries that consist of two numbers separated by a forward
## slash into a leading numeral for days and fully spelt out month
.convert_dbl_digit_to_char <- function(entry, thisPat) {
    if (grepl(thisPat, entry)) {
        mnthString <-
            entry %>%
            gsub(thisPat, "\\3", .) %>%
            str_trim() %>%
            as.numeric() %>%
            month.name[.]
    }
    else {
        return(entry)
    }
    
    updatedStr <- paste(str_trim(gsub(thisPat, "\\1", entry)), mnthString)
}












## Takes all abbreviated momth names and changes them to the full thing
.change_to_full_mth_names <- function(tempDF) {
    monthColumns <- which(endsWith(colnames(tempDF), "mth"))
    for (col in monthColumns) {
        months <- unlist(tempDF[, col])
        tempDF[, col] <- .fix_mth_entries(months)
    }
    invisible(tempDF)
}    









## Removes characters that are not required for date entries
## - 'months' that have no 'day' specified,
## - 'year' entries,
## - ordinal qualifiers, 
## - dots, commas and hyphens, and
## - whitespace
.cleanup_date_entries <- function(entries) {
    entries %>%
        str_replace(
            "(^\\s*[[:digit:]]{1,2}\\s+[[:alpha:]]+)/[[:alpha:]]+\\s*$",
                    replacement = "\\1"
            ) %>%
        str_replace(
            "^\\s*[[:alpha:]]{3,}/[[:alpha:]]{3,}\\s*[[:digit:]]{1,2}\\s*$",
            replacement = ""
        ) %>%
        str_replace("(/|\\s)([[:alnum:]]{2,})(/|\\s)([[:digit:]]{4}$)",
                    replacement = "\\1\\2") %>%
        str_replace("nd|rd|st|th", replacement = "") %>%
        str_replace_all("[,|.|-]", replacement = " ") %>%
        str_trim()
}








## Works on the Excel 'Date' numeric values
## Note that we have set aside a correction of 2:
## - one for the origin, which Excel includes unlike
##   the POSIX standard that we are using in R, and
## - the 1900 that EXcel erroneously identifies as a leap year.
.convert_num_date_to_char <- function(str) {
    number <- suppressWarnings(as.numeric(str))
    
    if (is.na(number)) return(str)
    
    # TODO:
    ## 1. Add condition for case where full date is counted
    ## and the year is not the present year (use min reasonable value)
    ## 2. Also do not accept dates that are in the future

    correct <- 2L
    invisible(
        format(as.Date(number - correct, origin = "1900-01-01"), "%d %B")
        )
}









## Apportions a component of an entered date to an appropriate new column
.distribute_date_vals <- function(tempDF, column) {
    stopifnot(identical(nrow(tempDF), length(column)))
    rules <- regexPatterns()  # object with patterns
    
    ## Before setting the indices for the patterns, we have to convert
    ## those entries with the numerical (D)D/MM format character-based
    ## month values e.g. 13 June
    column <- sapply(X = column,
                     FUN = .convert_dbl_digit_to_char, rules$num_slash_num,
                     USE.NAMES = FALSE)
    indices <- regexIndices(rules, column) # object with indices
    
    for (i in 1:ncol(tempDF)) {
        if (any(grepl(rules$single_day_first, column))) {
            beacon <- c("\\1", "\\3", "", "")
            ind <- indices$single_day_first
            vals <- .extract_date_values(column,
                                         rules$single_day_first,
                                         ind,
                                         beacon[i])
            tempDF[[i]] <- replace(tempDF[[i]], ind, vals)
        }
        if (any(grepl(rules$single_mth_first, column))) {
            beacon <- c("\\3", "\\1", "", "")
            ind <- indices$single_mth_first
            vals <- .extract_date_values(column,
                                         rules$single_mth_first,
                                         ind,
                                         beacon[i])
            tempDF[[i]] <- replace(tempDF[[i]], ind, vals)
        }
        if (any(grepl(rules$double_day_first, column))) {
            beacon <- c("\\1", "\\3", "\\5", "\\7")
            ind <- indices$double_day_first
            vals <- .extract_date_values(column,
                                         rules$double_day_first,
                                         ind,
                                         beacon[i])
            tempDF[[i]] <- replace(tempDF[[i]], ind, vals)
        }
        if (any(grepl(rules$double_mth_first, column))) {
            beacon <- c("\\3", "\\1", "\\7", "\\5")
            ind <- indices$double_mth_first
            vals <- .extract_date_values(column,
                                         rules$double_mth_first,
                                         ind,
                                         beacon[i])
            tempDF[[i]] <- replace(tempDF[[i]], ind, vals)
        }
    }
    invisible(tempDF)
}












## Extracts day and month as the case may be.
## @param rules a regular expression
## @param beacon a backreference used for substition of grouped patterns
## @details whitespace trimming is also carried out
.extract_date_values <- function(column, rules, index, beacon) {
    column <- column[index] %>%
        gsub(rules, beacon, .) %>%
        str_trim()
}
   








## Corrects abbreviated or badly entered 'month' values.
## Should accept only alphabetical characters.
.fix_mth_entries <- function(mth.col) {
    stopifnot(is.vector(mth.col))
    
    isInvalid <- grepl("[[:punct:]]|[[:digit:]]", mth.col)
    if (any(isInvalid)) {
        pos <- which(isInvalid)
        stop(sprintf("An invalid character was found at position %d.", pos))
    }
    
    sapply(mth.col, function(string) {
        string %>%
            str_trim() %>%
            gsub(
                "^(Ja|F|Mar|Ap|May|Jun|Jul|Au|S|O|N|D)[[:alpha:]]*$",
                "\\1",
                .,
                ignore.case = TRUE
            ) %>%
            str_to_title() %>%
            pmatch(month.name) %>%
            month.name[.]
    }) %>% as_tibble()
}












## Prints signpost
notice <- function() {
    cat("Copyright (c) DevSolutions 2018. All rights reserved.\n")
    cat("  NOTICE: This software is provided without any warranty.\n\n")
}
