## consolidate.R

## Consolidate the database by merging repeated records
## ````````````````````````````````````````````````````

pkgs <- c("RSQLite", "dplyr", "purrr", "rprojroot")
lapply(pkgs, function(x)
  suppressPackageStartupMessages(library(x, character.only = TRUE)))

source('src/funs.R')

cat("Start consolidation.\n* Loading dependencies... ")

## Make relevant files discoverable in-project
root <- is_rstudio_project
criterion <- has_file("narc-mailing-list.Rproj")
database <- "NARC-mailing-list.db"
path_to_db <-
  find_root_file("data", database, criterion = criterion)

## Load data
dat <- import_db(path_to_db, "NARC_mail")
cat("* Overview of the data:\n")
as_tibble(dat)
browser()
checkIdVarDuplicates(df)
browser()
df <- aggregateDuplicatedVals(df)
df <- fillMissingVals(df)
storeConsolidatedData(df, path_to_db)
