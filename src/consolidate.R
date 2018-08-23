## consolidate.R

## Consolidate the database by merging repeated records
## ````````````````````````````````````````````````````

pkgs <- c("RSQLite", "dplyr", "purrr", "rprojroot")
lapply(pkgs, function(x)
  suppressPackageStartupMessages(library(x, character.only = TRUE)))

source('src/funs.R')
source('src/check-data.R')

## Make relevant files discoverable in-project
root <- is_rstudio_project
criterion <- has_file("narc-mailing-list.Rproj")
database <- "NARC-mailing-list.db"
path_to_db <-
  find_root_file("data", database, criterion = criterion)

## Load the data
cat("* Overview of the data:\n")
dat <- importDataFromDb(path_to_db, "NARC_mail") %>% 
  as_tibble() %>% 
  print()

checkIdVarDuplicates(dat)

df_pre <- aggregateDuplicatedVals(dat)
skip <-
  menu(c('Yes', 'No'), t = "NEXT: Fill in missing values. Continue?") %>%
  {
    isTRUE(. == 2)
  }
if (!skip)
  pause()
df_post <- fillMissingVals(df_pre, skip = skip)
checkDataIntegrity(df_pre, df_post, skip = skip)
storeConsolidatedData(df_post, path_to_db)
