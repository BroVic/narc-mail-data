# helpers.R

################################
## S3 constructor and methods ##
################################

## Constructs S3 objects of class 'excelFile'
excelFile <- function(file) {
    ## Get individual spreadsheets
    sheetNames <-  readxl::excel_sheets(file)
    
    sheetList <- lapply(sheetNames, function(sht) {
        read_excel(path = file,
                   sheet = sht,
                   col_types = "text")
    })
    
    ## Use file properties and data to build an object
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
    invisible(exf)
}


## Provides output information on the object
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


## Provides a summary of the object
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


## Define generic and default method for extracting spreadsheets
extract_spreadsheets <-
    function(x)
        UseMethod("extract_spreadsheets")

extract_spreadsheets.excelFile <- function(fileObj)
    lapply(fileObj$data, function(dat)
        dat)

extract_spreadsheets.default <- function(x)
    "Unknown class."



#######################
##  Base data types  ##
#######################

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


## Regular expressions:
## We establish the pattern for entries that have:
## => two numbers separated by a forward slash e.g. 10/6
## => two day-month combos separated by a fwd slash e.g. May 6/June 12
## => a "DD Month" e.g. 15 Oct
## => an Excel date numeral e.g. "43322" equiv. to 12 Aug 2018
## => entries that have three date fields e.g. 13/03/2001, 13th March 2001

regexPatterns <- list(
    slash_with_two_nums = "(^[[:digit:]]{1,2})(/)([[:digit:]]{1,2}$)",
    slash_day_and_mth = "(^[[:print:]]{5,})(/)([[:print:]]{5,}$)",
    single_day_first = "(^[[:digit:]]{1,2})(\\s)+([[:alpha:]]{3,}$)",
    single_mth_first = "(^[[:alpha:]]{3,})(\\s)+([[:digit:]]{1,2})",
    date_numeral = "[0-9]{5}"
)





## Derive the indices of entries within our awkward column
## that match the patterns, respectively
regexIndices <- function(regexPatterns, column) {
    twoNum <- grep(regexPatterns$slash_with_two_nums, column)
    eitherMth <- grep(regexPatterns$slash_day_and_mth, column)
    single_day_f <- grep(regexPatterns$single_day_first, column)
    single_mth_f <- grep(regexPatterns$single_mth_first, column)
    numeral <- grep(regexPatterns$date_numeral, column)
    
    if (anyDuplicated(c(twoNum, eitherMth, single, numeral)))
        stop("There was a pattern-matching conflict for the date columns.")
    
    structure(
        list(
            twoNum = twoNum,
            eitherMth = eitherMth,
            single_day_f = single_day_f,
            single_mth_f = single_mth_f,
            numeral = numeral,
            class = "regexIndices"
        )
    )
}


####################################################################
##  Definitions of custom functions created for 'narc-dfmerge.R'  ##
####################################################################


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
        suppressPackageStartupMessages(lapply(missingPkgs, library, character.only = TRUE))
    }
    
    if (any(!pkgs %in% (.packages())))
        stop("Required packages are not installed or loaded.")
}








## Finds all existing Excel files within a given directory

find_excel_files <- function(path = ".") {
    # TODO: There are situations when a file's extension
    # may not be specified and thus there may be need to
    # test such files to know whether they are of the format.
    xlFiles <- list.files(path, pattern = ".xlsx$|.xls$") %>%
        subset(!grepl("^~", .))    # remove any backup files (Windows)
    
    numFiles <- length(xlFiles)
    if (!numFiles) {
        stop("There are no Excel files in this directory.")
    } else {
        cat(sprintf(
            ngettext(
                numFiles,
                "\t%d Excel file was found:\n",
                "\t%d Excel files were found:\n"
            ),
            numFiles
        ))
        
        ## List the files
        sapply(xlFiles, function(x) {
            cat(sprintf("\t  * %s\n", x))
        })
    }
    
    invisible(xlFiles)
}










## Finds the row that likely contains the actual header and
## returns an S3 object that is a marker to the row it occupies
locate_header <- function(df, hdr, quietly = TRUE) {
    if (!is.data.frame(df))
        stop("'df' is not a valid data frame")
    if (!is.character(hdr))
        stop("'hdr' is not a character vector")
    
    ## Iterate row-wise
    val <- list()
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










fix_funny_date_entries <- function(df, verbose = FALSE) {
    ## Temporary data frame based on the new columns
    focusCol <-
        c("bday.day", "bday.mth", "wedann.day", "wedann.mth")
    
    tmpDf <- "" %>%
        matrix(nrow = nrow(df), ncol = length(focusCol)) %>%
        as_tibble()
    
    colnames(tmpDf) <- focusCol
    
    ## Identify the columns in the original data frame
    ## that are likely to contain the awkard entries
    fields <- colnames(df)
    awkward <- c(
        "BDAY/WED ANN",
        "BIRTHDAY AND WEDDING ANN",
        "WED ANN",
        "BIRTHDAY",
        "BDAY",
        "BIRTHDAY AND WED ANN"
    )
    
    ## Processing for the columns of interest
    if (any(awkward %in% fields)) {
        indexAwkward <- match(awkward, fields) %>%
            na.exclude() %>%
            sort()
        
        tmpDf <-  .process_awkward_cols(df, tmpDf, indexAwkward)
        
        df <- bind_cols(df, tmpDf)
        df <- df[,-indexAwkward]
    }
    
    invisible(df)
}










.process_awkward_cols <- function(main.df, temp.df, awkColIndex) {
    ## Loop through the target columns in the data frame
    for (topIndex in awkColIndex) {
        nameCurrCol <- colnames(main.df)[topIndex]
        main.df[[topIndex]] <-
            sapply(main.df[[topIndex]], .preprocess_date_entry)
        
        ## Instantiate an object of class regexIndices
        index <-
            regexIndices(regexPatterns, main.df[[topIndex]])
        
        ## We start with conditional branches to be followed depending on
        ## whether a columns starts with a 'B' or a 'W'.
        if (grepl("^B[[:graph:]]+", nameCurrCol)) {
            ## Note that at the beginning we do not use a loop. This is
            ## because we can conveniently vectorize without losing data.
            temp.df$bday.day[index$twoNum] <-
                main.df[[topIndex]][index$twoNum]
            temp.df$bday.day <- temp.df$bday.day %>%
                str_replace(regexPatterns$slash_with_two_nums, "\\1") %>%
                str_trim()
            
            temp.df$bday.mth[index$twoNum] <-
                main.df[[topIndex]][index$twoNum]
            temp.df$bday.mth <-
                sapply(temp.df$bday.mth, function(x) {
                    str_replace(x, regexPatterns$slash_with_two_nums, "\\3") %>%
                        str_trim()
                }) %>%
                as.numeric() %>%
                month.name[.]
            
            ## Now we loop...
            for (a_single in index$single_day_f) {
                # if (grepl("^[[:digit:]]", main.df[[topIndex]][a_single])) {
                temp.df$bday.day[a_single] <-
                    .distr_date_elems(main.df,
                                      topIndex,
                                      a_single,
                                      regexPatterns$single_day_first,
                                      "\\1")
                
                temp.df$bday.mth[a_single] <-
                    .distr_date_elems(main.df,
                                      topIndex,
                                      a_single,
                                      regexPatterns$single_day_first,
                                      "\\3")
            }
            # } else if (grepl("^[[:alpha:]]", main.df[[topIndex]][a_single])) {
            for (a_single in index$single_mth_f) {
                temp.df$bday.day[a_single] <-
                    .distr_date_elems(main.df,
                                      topIndex,
                                      a_single,
                                      regexPatterns$single_mth_first,
                                      "\\3")
                
                temp.df$bday.mth[a_single] <-
                    .distr_date_elems(main.df,
                                      topIndex,
                                      a_single,
                                      regexPatterns$single_mth_first,
                                      "\\1")
            }
            
            for (dateIndex in index$numeral) {
                ## Numerical date values
                dateNumToChar <-
                    .convert_num_date_to_char(main.df[[topIndex]][dateIndex])
                
                temp.df$bday.day[dateIndex] <-
                    dateNumToChar %>%
                    str_replace(regexPatterns$single_day_first, "\\1") %>%
                    str_trim()
                
                temp.df$bday.mth[dateIndex] <-
                    dateNumToChar %>%
                    str_replace(regexPatterns$single_day_first, "\\3") %>%
                    str_trim()
            }
        } else if (grepl("^W[[:graph:]]+", nameCurrCol)) {
            temp.df$wedann.day[index$twoNum] <-
                main.df[[topIndex]][index$twoNum]
            temp.df$wedann.day <- temp.df$wedann.day %>%
                str_replace(regexPatterns$slash_with_two_nums, "\\1") %>%
                str_trim()
            
            temp.df$wedann.mth[index$twoNum] <-
                main.df[[topIndex]][index$twoNum]
            temp.df$wedann.mth <-
                sapply(temp.df$wedann.mth, function(x) {
                    str_replace(x, regexPatterns$slash_with_two_nums, "\\3") %>%
                        str_trim()
                }) %>%
                as.numeric() %>%
                month.name[.]
            
            ## Now we loop...
            for (a_single in index$single_day_f) {
                temp.df$wedann.day[a_single] <-
                    .distr_date_elems(main.df,
                                      topIndex,
                                      a_single,
                                      regexPatterns$single_day_first,
                                      "\\1")
                
                temp.df$wedann.mth[a_single] <-
                    .distr_date_elems(main.df,
                                      topIndex,
                                      a_single,
                                      regexPatterns$single_day_first,
                                      "\\3")
            }
            for (a_single in index$single_mth_f) {
                temp.df$wedann.day[a_single] <-
                    .distr_date_elems(main.df,
                                      topIndex,
                                      a_single,
                                      regexPatterns$single_mth_first,
                                      "\\3")
                
                temp.df$wedann.mth[a_single] <-
                    .distr_date_elems(main.df,
                                      topIndex,
                                      a_single,
                                      regexPatterns$single_mth_first,
                                      "\\1")
            }
            
            ## Numerical date values
            for (dateIndex in index$numeral) {
                ## Reformat into a Date string with Day and Month
                dateNumToChar <-
                    .convert_num_date_to_char(main.df[[topIndex]][dateIndex])
                
                temp.df$wedann.day[dateIndex] <-
                    dateNumToChar %>%
                    str_replace(regexPatterns$single_day_first, "\\1") %>%
                    str_trim()
                
                temp.df$wedann.mth[dateIndex] <-
                    dateNumToChar %>%
                    str_replace(regexPatterns$single_day_first, "\\3") %>%
                    str_trim()
            }
        }  # end of block conditioning on whether name starts with B or W
        
        
        ## Here there are two date entries per cell so we distribute
        ## string fragments to the appropriate cell in 'temp.df'
        for (an_eitherMth in index$eitherMth) {
            temp.df$bday.day[an_eitherMth] <-
                .distr_date_elems(
                    main.df,
                    topIndex,
                    an_eitherMth,
                    regexPatterns$slash_day_and_mth,
                    "\\1",
                    "[[:alpha:]]+"
                )
            
            temp.df$bday.mth[an_eitherMth] <-
                .distr_date_elems(
                    main.df,
                    topIndex,
                    an_eitherMth,
                    regexPatterns$slash_day_and_mth,
                    "\\1",
                    "[[:digit:]]+"
                )
            
            temp.df$wedann.day[an_eitherMth] <-
                .distr_date_elems(
                    main.df,
                    topIndex,
                    an_eitherMth,
                    regexPatterns$slash_day_and_mth,
                    "\\3",
                    "[[:alpha:]]+"
                )
            
            
            temp.df$wedann.mth[an_eitherMth] <-
                .distr_date_elems(
                    main.df,
                    topIndex,
                    an_eitherMth,
                    regexPatterns$slash_day_and_mth,
                    "\\1",
                    "[[:digit:]]+"
                )
        }
        
    }  # end of outermost loop
    
    ## Correct abbreviated month entries to full month names
    indexMonthColumns <-
        which(endsWith(colnames(temp.df), "mth"))
    
    
    
    for (col in indexMonthColumns)
        temp.df[, col] <- .fix_mth_entries(temp.df[, col])
    
    print(temp.df)
}










## Picks out irregular entries, breaking them into bits. Numerals
## (for days) and words (for months) are sent to appropriate columns.
.distr_date_elems <- function(mainData,
                              mainLoop,
                              innerLoop,
                              pattern,
                              replacement,
                              drop = "") {
    mainData[[mainLoop]][innerLoop] %>%
        str_replace(pattern, replacement) %>%
        gsub(drop, "", .) %>%
        str_trim()
}





## Works on the Excel 'Date' numeric values
## Note that we have set aside a correction of 2:
## - one for the origin, which Excel includes unlike
##   the POSIX standard that we are using in R, and
## - the 1900 that EXcel erroneously identifies as a leap year.
.convert_num_date_to_char <- function(number) {
    if (is.character(number))
        number <- as.numeric(number)
    ## TODO: Add condition for case where full date is counted
    ## and the year is not the present year (use min reasonable value)
    
    correction <- 2
    dateString <-
        format(as.Date(number - correction, origin = "1900-01-01"), "%d %B")
    dateString
}







## Removes characters that are not required in the date entries
## Get rid of ordinal qualifiers, and then remove dots,
## commas and hyphens from all entries, and trim whitespace
.preprocess_date_entry <- function(entry) {
    entry %>%
        str_replace("(^\\s*[[:digit:]]{1,2}\\s+[[:alpha:]]+)/[[:alpha:]]+\\s*$",
                    replacement = "\\1") %>%
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









## Corrects abbreviated or badly entered 'month' values
.fix_mth_entries <- function(mth.col = character()) {
    mth.col <- mth.col[, 1]
    if (any(grepl("[[:punct:]]", unlist(mth.col))))
        stop("Cannot correct month entries with punctuation characters.")
    
    sapply(mth.col, function(string) {
        string %>%
            str_trim() %>%
            gsub("^(Ja|F|Mar|Ap|May|Jun|Jul|Au|S|O|N|D)\\w*$",
                 "\\1",
                 .,
                 ignore.case = TRUE) %>%
            str_to_title() %>%
            pmatch(month.name) %>%
            month.name[.]
    }) %>%
        as_tibble()
}








notice <- function() {
    cat("Copyright (c) Dev Solutions 2018. All rights reserved.\n")
    cat("  NOTICE: This software is provided without any warranty.\n\n")
}
