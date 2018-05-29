## consolidate.R

## Consolidate the database by merging repeated records
## ````````````````````````````````````````````````````


library(RSQLite)
library(tidyverse)
library(rprojroot)

## Some housekeeping...
root <- is_rstudio_project
path_to_db <-
  find_root_file("harmonised-data",
                 "NARC-mailing-list.db",
                 criterion = has_file("narc-mailing-list.Rproj"))

## Utility function
pause <- function() {
  if (interactive()) {
    readline("Press ENTER to continue...")
  }
}

## Import data
# TODO: Examine this path
if (!exists("dbcon")) {
    dbcon <- dbConnect(SQLite(), path_to_db)
    tabl <- grep("NARC_mail", dbListTables(dbcon), value = TRUE)
    df <- dbReadTable(dbcon, tabl)
    dbDisconnect(dbcon)
    rm(dbcon)
}

cat("\nOverview of the data:\n")
glimpse(df)

cat("\nNext: Check identifier variables for duplications\n")
pause()
invisible(df %>%
              select(name, phone, email) %>%
              {
                  cat("* Level of duplication:\n")
                  sapply(colnames(.), function(x) {
                      cat("** Column",
                          sQuote(x),
                          "has",
                          sum(duplicated(.[[x]]), na.rm = TRUE),
                          "duplications\n")
                  })
              }
          )
cat("\nNext: Aggregate the duplicated values\n")
pause()

cat("* Summary of data grouped by 'name':\n")
df %>%
    group_by(name) %>%
    summarise_all(first) %>% 
    print()
