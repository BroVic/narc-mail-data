# helpers.R

## Definitions of custom functions created for 'narc-dfmerge.R'


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
            val <- structure(
                list(header = hdr,
                     rownum = i,
                     nextrow = i + 1),
                class = "header-locator"
            )
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
        else if (regexpr("day", tolower(x)) > 0) # review this step?
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

## Setting the columns to the appropriate data types
set_datatypes <- function(df) {
    cat("(NB: Yet to fix date columns!!!) ")
    df$serialno <- as.integer(df$serialno)
    df$phone <- fix_phone_numbers(df$phone)
    for (i in c(2, 4:5))
        df[[i]] <- as.character(df[[i]])
    for (i in c(8:11))
        df[[i]] <- as.factor(df[[i]])
    
    invisible(df)
}

## Fixing up phone number to a uniform text format
fix_phone_numbers <- function(column) {
    invisible(column <- column %>%
                  as.character() %>%
                  gsub("^([1-9])", "0\\1", .))
}

    
notice <- function() {
    cat("Copyright (c) Dev Solutions 2018. All rights reserved.\n")
    cat("  NOTICE: This software is provided without any warranty.\n\n")
}
