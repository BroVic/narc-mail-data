# narc-dfmerge.R

## Copyright (c) 2018 Dev Solutions

source("helpers.R")
notice()

## Ensure the availability and attachment of needed R extensions
cat("Loading required packages... ")
load_packages(pkgs = c("DBI", "RSQLite", "dplyr", "lubridate", "readxl"))
cat("Done\n")

cat("Checking for Excel files in the directory..,\n")
filepaths <- find_excel_files()

cat("Creating a header for the new data frame... ")
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
## Alternatively, replace birthday and anniversary with two additional columns
## each as follows:
## "bday.day", "bday.month", "anniv.day", "anniv.month"
## see helpers.R for the logic.

## Otherwise totally fix at point of data collection by asking for 
## D.O.B. and date of marriage
cat("Done\n")

cat("Importing the data from Excel into R... ")
excelList <- lapply(filepaths, excelFile)

df.ls <- extract(excelList[[1]])
len <- length(excelList)
if (len > 1) {
    for (i in 2:len) {
        tmp <- extract(excelList[[i]])
        df.ls <- append(df.ls, tmp)
    }
    zeroes <- sapply(df.ls, nrow)
    df.ls <- df.ls[which(zeroes != 0)]
}
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
dbTable <- "NARC_mail_ext"

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
