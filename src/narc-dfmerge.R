# narc-dfmerge.R

## Copyright (c) 2018 DevSolutions

default <- "workbooks"
if (!interactive()) {
    path <- commandArgs(trailingOnly = TRUE)
} else {
    if (identical(.Platform$OS.type, "windows")) {
        opt <- menu(choices = c("Select a folder", "Use default"),
                    graphics = TRUE)
        if (identical(opt, 1L)) {
            path <- choose.dir()
        }
        else if (identical(opt, 2L)) {
            cat("Using default folder", sQuote(default))
            path <- default
        }
        else stop("No folder was selected")
    }
}

source(file.path(getwd(), "src/helpers.R"))
notice()

## Ensure the availability and attachment of needed R extensions
cat("Loading required packages... ")
load_packages(pkgs = c("DBI",
                       "RSQLite",
                       "dplyr",
                       "readxl",
                       "stringr"))
cat("Done\n")

cat("Checking for Excel files in the directory...\n")
filepaths <- find_excel_files(path)

cat("Importing details of Excel file(s) into R... ")
excelList <- lapply(filepaths, excelFile)
rm(filepaths)

# In case there's more than one spreadsheet
df.ls <- extract_spreadsheets(excelList[[1]])
len <- length(excelList)
if (len > 1) {
    for (i in 2:len) {
        tmp <- extract_spreadsheets(excelList[[i]])
        df.ls <- append(df.ls, tmp)
    }
    df_row_num <- sapply(df.ls, nrow)
    df.ls <- df.ls[which(df_row_num != 0)]
}

rm(excelList)
cat("Done\n")

cat("Identifying and afixing original headers... ")

df.ls <- lapply(df.ls, function(df) {
    val <- locate_header(df, hdr = columnNames)
    if (!is.null(val)) {
        df <- df %>%
            slice(val$nextrow:n())
        if (!identical(ncol(df), length(val$header)))
            stop("Mismatched dimensions of existing and updated headers.")
        colnames(df) <- val$header
        df
    }
    else {
        df <- data.frame(0)
    }
})
cat("Done\n")

cat("Working on date-related columns... ")
df.ls <- lapply(df.ls, fix_date_entries)
cat("Done\n")

cat("Updating original headers... ")
df.ls <- lapply(df.ls, update_header, newCol = columnNames)
cat("Done\n")

cat("Rearranging columns to suit the prescribed format... ")
df.ls <- lapply(df.ls, rearrange_df, columnNames)
cat("Done\n")

cat("Merging data frames... ")
master <- combine_dfs(df.ls)
rm(df.ls)
cat("Done\n")

cat("Setting the data types... ")
master <- set_datatypes(master)
cat("Done\n")

cat("Creating output directory... ")
folder <- file.path(path, "harmonised-data")
if (!dir.exists(folder))
    dir.create(folder)
cat("Done\n")

cat("Writing to database... ")

con <-
    dbConnect(SQLite(), file.path(folder, "NARC-mailing-list.db"))
if (!dbIsValid(con))
    stop("Connection to database failed.")

dbTable <- "NARC_mail"
dbWriteTable(conn = con, dbTable, master, append = TRUE)

## Deal with wholesale replications and empty records
master <- dbReadTable(con, dbTable) %>%
    distinct()
all_empty <- apply(master, 1, function(x) all(is.na(x)))
master <- master[!all_empty, ]
master$serialno <- seq_along(length(master$serialno))
dbWriteTable(con, dbTable, master, overwrite = TRUE)

## Close shop...
dbDisconnect(con)
if (dbIsValid(con)) {
    warning("The database connection was not properly closed.")
} else {
    rm(con)
    cat("Done\n")
}

rm(list = ls())
cat("\nThat's all.\n")
