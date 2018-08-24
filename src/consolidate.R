## consolidate.R

## Consolidate the database by merging repeated records
## ````````````````````````````````````````````````````
library(NARCcontacts)
library(rprojroot)
## Make relevant files discoverable in-project
root <- is_rstudio_project
criterion <- has_file("narc-mailing-list.Rproj")
database <- "NARC-mailing-list.db"
path_to_db <-
  find_root_file("data", database, criterion = criterion)

## Start main operation
consolidate_narc_mail(path_to_db)
