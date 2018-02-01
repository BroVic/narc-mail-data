# helpers.R

################################
## S3 constructor and methods ##
################################

## Constructs S3 objects of class 'excelFile'
excelFile <- function(file) {
    
    ## Get individual spreadsheets
    sheetNames <-  readxl::excel_sheets(file)
    
    sheetList <- lapply(sheetNames, function(sht) {
        read_excel(path = file, sheet = sht, col_types = "text")
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
        ngettext(xlObj$noOfSheets,
                 "Filename: %s with %s spreadsheet.\n",
                 "Filename: %s with %s spreadsheets.\n"),
        xlObj$fileName, xlObj$noOfSheets))
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
extract_spreadsheets <- function(x) UseMethod("extract_spreadsheets")

extract_spreadsheets.excelFile <- function(fileObj)
    lapply(fileObj$data, function(dat) dat)

extract_spreadsheets.default <- function(x) "Unknown class."



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
        suppressPackageStartupMessages(lapply(
            missingPkgs, library, character.only = TRUE))
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
        if (any(hdr %in% tolower(df[i,]))) {
            if (!quietly) {
                cat(
                    paste0(
                        "\tA header candidate was found on row ",
                        i,
                        ":\n\t"
                    ),
                    sQuote(df[i,]),
                    "\n"
                )
            }
            hdr <- as.character(df[i, ])
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
    if (!is.character(newCol))
        stop("'newCol' is not a character vector")
    
    initialHdr <- colnames(df)
    modifiedHdr <- sapply(initialHdr, function(x) {
        ## These are the values we're picking from 'newCol':
        ### [1]  "serialno"     [2]  "name"       [3]  "phone"
        ### [4]  "address"      [5]  "email"      [6]  "bday.day"
        ### [7]  "bday.mth"     [8]  "wedann.day"  [9]  "wedann.mth" 
        ### [10] "occupation"   [11] "church"     [12] "pastor"
        ### [13] "info.source"  
        if (identical(x, "S/N"))
            x <- newCol[1]
        else if (grepl("name", tolower(x)))
            x <- newCol[2]
        else if (grepl("number|phone", tolower(x)))
            x <- newCol[3]
        else if (grepl("ress$", tolower(x)))
            x <- newCol[4]
        else if (identical(tolower(x), newCol[5]))
            x <- newCol[5]
        else if (grepl("Occupation", x))
            x <- newCol[10]
        else if (grepl("church", tolower(x)))
            x <- newCol[11]
        else if (grepl("pastor$", tolower(x)))
            x <- newCol[12]
        else if (grepl("know", tolower(x)))
            x <- newCol[13]
        
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
    df$phone <- fix_phone_numbers(df$phone)
    
    ## TODO: Undo hard coding
    for (i in c(2, 4:5))
        df[[i]] <- as.character(df[[i]])
    for (i in c(7, 9:11))
        df[[i]] <- as.factor(df[[i]])
    for (i in c(6, 8)) 
        df[[i]] <- as.numeric(df[[i]])
    
    invisible(df)
}









## Fixes up phone numbers to a uniform text format
fix_phone_numbers <- function(column) {
    column <-
        ifelse(nchar(column) > 11 | nchar(column) < 10, NA_character_, column)
    
    ## TODO: Check for invalid numbers with normal lengths
    invisible(column %>%
                  as.character() %>%
                  gsub("^([1-9])", "0\\1", .))
}










fix_funny_date_entries <-
    function(df,
             focusCol = c("bday.day", "bday.mth", "wedann.day", "wedann.mth")) {
        ## WARNING: This function is lengthy due to the extensive
        ## string manipulation required to get the desired result.
        
        ## Identify funny column and if non-existent exit unchanged, that is
        ## spreadsheets that do not have any of these columns are skipped
        stopifnot(length(focusCol) == 4)
        
        fields <- colnames(df)
        awkward <- c("BDAY/WED ANN",
                     "BIRTHDAY AND WEDDING ANN",
                     "WED ANN",
                     "BIRTHDAY")
        if (!any(awkward %in% fields))
            return(df)
        
        ## Make a temporary data frame based on the new columns
        tmpDf <- "" %>%
            matrix(nrow = nrow(df), ncol = length(focusCol)) %>%
            as_tibble()
        colnames(tmpDf) <- focusCol
        
        ## Using regular expressions, establish pattern for entries that have:
        ## => 2 numbers separated by a forward slash e.g. 10/6
        ## => 2 day-month combos separated by a fwd slash e.g. May 6/June 12
        ## => a "DD Month" e.g. 15 Oct
        ## => an Excel date numeral e.g. "43322" equiv. to 12 Aug 2018
        regex_slash_with_two_nums <-
            "([[:digit:]]{1,2})(\\/)([[:digit:]]{1,2})"
        regex_slash_day_and_mth <-
            "(^[[:alnum:]]+\\s*[[:alnum:]]+)\\s*(/)\\s*([[:alnum:]]+\\s*[[:alnum:]]+$)"
        regex_single_regular <- "(^[0-9]{1,2})(\\s+)([a-zA-Z]{3,}$)"
        regex_date_numeral <- "[0-9]{5}"
        regex_triple_entry <- "([0-9]+\\s+[[:alnum:]]{2,})(\\s+[0-9]{2,})"
        
        ## Loop through the awkward columns in the data frame
        awkColIndex <- na.exclude(match(awkward, fields))
        for (topIndex in awkColIndex) {
            ## Get column name; for data frames with more than 1 funny column
            nameCurrCol <- colnames(df)[topIndex]
            
            ## Get rid of ordinal qualifiers, and then remove dots,
            ## commas and hyphens from all entries, and trim whitespace
            df[[topIndex]] <- sapply(df[[topIndex]], function(entry) {
                entry %>%
                    str_replace("(/|-)([[:alnum:]]+)(/|-)[[:digit:]]{2,}$",
                            replacement = "\\1\\2") %>%
                    str_replace("nd|rd|st|th", replacement = "") %>%
                    str_replace("[,|.|-]", replacement = " ") %>%
                    str_trim()
            })
            
            ## Derive the indices of entries within our awkward column
            ## that match the patterns, respectively
            index_twoNum <- grep(regex_slash_with_two_nums, df[[topIndex]])
            index_eitherMth <-
                grep(regex_slash_day_and_mth, df[[topIndex]])
            index_single <- grep(regex_single_regular, df[[topIndex]])
            index_numeral <- grep(regex_date_numeral, df[[topIndex]])
            index_triples <- grep(regex_triple_entry, df[[topIndex]])
            
            ## From here on, irregular entries are picked out from the offending
            ## column and broken into bits. Numerals (for days) and words (for
            ## months) are sent to the appropriate columns.
            
            ## Also note that we work on the Excel 'Date' numeric values
            ## We have set aside a correction of 2:
            ## - one for the origin, which Excel includes unlike the 
            ##   POSIX standard that we are using in R, and
            ## - the 1900 that EXcel erroneously identifies as a leap year.
            
            ## We start with conditional branches to be followed depending on
            ## whether a columns starts with a 'B' or a 'W'.
            ## Note that at the beginning we do not use a loop. This is
            ## because we can conveniently vectorize without losing data.
            if (grepl("^B[[:graph:]]+", nameCurrCol)) {
                
                tmpDf$bday.day[index_twoNum] <- df[[topIndex]][index_twoNum]
                tmpDf$bday.day <- tmpDf$bday.day %>%
                    str_replace(regex_slash_with_two_nums, "\\1") %>%
                    str_trim()
                
                tmpDf$bday.mth[index_twoNum] <-
                    df[[topIndex]][index_twoNum]
                tmpDf$bday.mth <- sapply(tmpDf$bday.mth, function(x) {
                    str_replace(x, regex_slash_with_two_nums, "\\3") %>%
                        str_trim()
                }) %>%
                    as.numeric() %>%
                    month.name[.]
                
                ## Now we loop...
                for (a_single in index_single) {
                    tmpDf$bday.day[a_single] <-
                        df[[topIndex]][a_single] %>%
                        str_replace(regex_single_regular, "\\1") %>%
                        str_trim()
                    
                    tmpDf$bday.mth[a_single] <-
                        df[[topIndex]][a_single] %>%
                        str_replace(regex_single_regular, "\\3") %>%
                        str_trim()
                }
                
                
                ## Numerical date values
                correction <- 2
                for (dateIndex in index_numeral) {
                    ## Reformat into a Date string with Day and Month
                    dateNumToChar <- format(as.Date(
                        as.numeric(df[[topIndex]][dateIndex]) - correction,
                        origin = "1900-01-01"),
                        "%d %B")
                    
                    tmpDf$bday.day[dateIndex] <- dateNumToChar %>%
                        str_replace(regex_single_regular, "\\1") %>%
                        str_trim()
                    
                    tmpDf$bday.mth[dateIndex] <- dateNumToChar %>%
                        str_replace(regex_single_regular, "\\3") %>%
                        str_trim()
                }
                
            } else if (grepl("^W[[:graph:]]+", nameCurrCol)) {
                
                tmpDf$wedann.day[index_twoNum] <- df[[topIndex]][index_twoNum]
                tmpDf$wedann.day <- tmpDf$wedann.day %>%
                    str_replace(regex_slash_with_two_nums, "\\1") %>%
                    str_trim()
                
                tmpDf$wedann.mth[index_twoNum] <-
                    df[[topIndex]][index_twoNum]
                tmpDf$wedann.mth <- sapply(tmpDf$wedann.mth, function(x) {
                    str_replace(x, regex_slash_with_two_nums, "\\3") %>%
                        str_trim()
                }) %>%
                    as.numeric() %>%
                    month.name[.]
                
                ## Now we loop...
                for (a_single in index_single) {
                    tmpDf$wedann.day[a_single] <-
                        df[[topIndex]][a_single] %>%
                        str_replace(regex_single_regular, "\\1") %>%
                        str_trim()
                    
                    tmpDf$wedann.mth[a_single] <-
                        df[[topIndex]][a_single] %>%
                        str_replace(regex_single_regular, "\\3") %>%
                        str_trim()
                }
                
                ## Numerical date values
                correction <- 2
                for (dateIndex in index_numeral) {
                    ## Reformat into a Date string with Day and Month
                    dateNumToChar <- format(as.Date(
                        as.numeric(df[[topIndex]][dateIndex]) - correction,
                        origin = "1900-01-01"),
                        "%d %B")
                    
                    tmpDf$wedann.day[dateIndex] <- dateNumToChar %>%
                        str_replace(regex_single_regular, "\\1") %>%
                        str_trim()
                    
                    tmpDf$wedann.mth[dateIndex] <- dateNumToChar %>%
                        str_replace(regex_single_regular, "\\3") %>%
                        str_trim()
                }
                
            }  # end of if-else block
            
            
            ## Here there are two date entries per cell so we distribute
            ## string fragments to the appropriate cell in 'tmpDf'
            for (an_eitherMth in index_eitherMth) {
                tmpDf$bday.day[an_eitherMth] <- 
                    df[[topIndex]][an_eitherMth] %>%
                    str_replace(regex_slash_day_and_mth, "\\1") %>%
                    str_replace("[[:alpha:]]+", "") %>%
                    str_trim()
                
                tmpDf$bday.mth[an_eitherMth] <- 
                    df[[topIndex]][an_eitherMth] %>%
                    str_replace(regex_slash_day_and_mth, "\\1") %>%
                    str_replace("[[:digit:]]+", "") %>%
                    str_trim()
                # TODO: partial matching of month names??
                
                tmpDf$wedann.day[an_eitherMth] <-
                    df[[topIndex]][an_eitherMth] %>%
                    str_replace(regex_slash_day_and_mth, "\\3") %>%
                    str_replace("[[:alpha:]]+", "") %>%
                    str_trim()
                
                tmpDf$wedann.mth[an_eitherMth] <-
                    df[[topIndex]][an_eitherMth] %>%
                    str_replace(regex_slash_day_and_mth, "\\3") %>%
                    str_replace("[[:digit:]]+", "") %>%
                    str_trim()
            }
            
        }  # end of outermost loop
        
        ## Phew... return the modified data frame
        df <- df %>% bind_cols(tmpDf)
        df <- df[, -awkColIndex]
        invisible(df)
    }









notice <- function() {
    cat("Copyright (c) Dev Solutions 2018. All rights reserved.\n")
    cat("  NOTICE: This software is provided without any warranty.\n\n")
}
