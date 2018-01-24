# narc-dfmerge.R

## Copyright (c) 2018 Dev Solutions

library(readxl)
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(dplyr))
library(RSQLite)

source("helpers.R")

notice()

cat("Checking for Excel files in the directory..,\n")
excelfiles <- list.files(pattern = ".xlsx$|.xls$")
numFiles <- length(excelfiles)
if (!numFiles) {
    cat("Not Found")
    stop("There are no Excel files in this directory")
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
    invisible(sapply(excelfiles, function(x) {
        cat(sprintf("\t  * %s\n", x))
    }))
}

cat("Creating a header for the new data frame... ")
columnNames <- c(
    "serialno",
    "name",
    "phone",
    "address",
    "email",
    "birthday",
    "anniversary",
    "occupation",
    "church",
    "pastor",
    "info.source"
)
cat("Done\n")

cat("Importing the data from Excel into R... ")
df.ls <- sapply(excelfiles, read_excel, na = "NA")
cat("Done\n")

cat("Identifying and afixing original headers... ")
df.ls <- lapply(df.ls, function(df) {
    val <- locate_header(df, hdr = columnNames)
    df <- df %>%
        slice(val$nextrow:n())
    
    if (!identical(ncol(df), length(val$header)))
        stop("Mismatched dimensions of existing and updated headers.")
    colnames(df) <- val$header
    df
})
cat("Done\n")

cat("Updating original headers... ")
df.ls <- lapply(df.ls, update_header, newCol = columnNames)
cat("Done\n")

cat("Rearranging columns to suit the prescribed format... ")
df.ls <- lapply(df.ls, rearrange_df, columnNames)
cat("Done\n")

cat("Merging data frames... ")
master <- combine_dfs(df.ls)
cat("Done\n")

cat("Setting types... ")
master <- set_datatypes(master)
cat("Done\n")

cat("Creating output directory... ")
folder <- "harmonised-data"
if (!dir.exists(folder))
    dir.create(folder)
cat("Done\n")

cat("Writing to database... ")
dbFile <- "NARC-mailing-list.db"
dbTable <- "NARC_mail"

con <- dbConnect(SQLite(), file.path(folder, dbFile))
if (!dbIsValid(con))
    stop("Connection to database failed.")

dbWriteTable(conn = con, dbTable, master, append = TRUE)

## Deal with wholesale replications
tmp <- dbReadTable(con, dbTable) %>% distinct()
dbWriteTable(con, dbTable, tmp, overwrite = TRUE)
dbDisconnect(con)
if (dbIsValid(con))
    warning("The database is not properly disconnected from the R session.")
cat("Done\n")

cat("\nThat's all.\n")
