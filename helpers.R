# helpers.R

################################
## S3 constructor and methods ##
################################

## Constructs S3 objects of class 'excelFile'
excelFile <- function(file) {
    ## Generate a list of the individual spreadsheets
    sheetList <- list()
    sheets <-  excel_sheets(file)
    num <- length(sheets)
    for (i in 1:num) {
        sheetList[[i]] <- read_excel(file, sheet = i)
        df <- sheetList[[i]]
        class(sheetList[[i]]) <-
            c(class(sheetList[[i]]), "spreadsheet")
    }
    
    ## Use file properties and data to build an object
    prop <- file.info(file)
    exf <- structure(
        list(
            fileName = file,
            fileSize = prop$size,
            created = prop$ctime,
            modified = prop$mtime,
            noOfSheets = num,
            sheets = sheets,
            data = sheetList
        ),
        class = "excelFile"
    )
    invisible(exf)
}



## Provides output information on the object
print.excelFile <- function(xlObj) {
    cat("Filename: ",
        xlObj$fileName,
        "with ",
        xlObj$noOfSheets,
        " spreadsheets.\n")
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
extract <- function(x)
    UseMethod("extract")

extract.excelFile <- function(x) {
    dfs <- list()
    
    for (i in 1:length(x$data)) {
        dfs[[i]] <- x$data[[i]]
    }
    
    invisible(dfs)
}

extract.default <- function(x)
    "Unknown class."




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








## Finds all existing Excel files within

find_excel_files <- function(path = ".") {
    # TODO: There are situations when a file's extension
    # may not be specified and thus there may be need to
    # test such files to know whether they are of the format.
    xlFiles <- list.files(path, pattern = ".xlsx$|.xls$") %>%
        subset(!grepl("^~", .))
    
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
        ### [1] "serialno"     [2] "name"          [3] "phone"
        ### [4] "address"      [5] "email"         [6] "birthday"
        ### [7] "anniversary"  [8] "occupation"    [9] "church"
        ### [10] "pastor"      [11] "info.source"
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
        else if (grepl("day", tolower(x)))
            # review this step?
            x <- newCol[6]
        else if (identical(tolower(x), "wed ann"))
            x <- newCol[7]
        else if (grepl("Occupation", x))
            x <- newCol[8]
        else if (grepl("church", tolower(x)))
            x <- newCol[9]
        else if (grepl("pastor$", tolower(x)))
            x <- newCol[10]
        else if (grepl("know", tolower(x)))
            x <- newCol[11]
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
    for (i in c(8:11))
        df[[i]] <- as.factor(df[[i]])
    
    warning("Yet to fix date columns.")
    invisible(df)
}









## Fixes up phone numbers to a uniform text format
fix_phone_numbers <- function(column) {
    invisible(column <- column %>%
                  as.character() %>%
                  gsub("^([1-9])", "0\\1", .))
}










notice <- function() {
    cat("Copyright (c) Dev Solutions 2018. All rights reserved.\n")
    cat("  NOTICE: This software is provided without any warranty.\n\n")
}
