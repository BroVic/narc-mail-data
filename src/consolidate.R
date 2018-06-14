## consolidate.R

## Consolidate the database by merging repeated records
## ````````````````````````````````````````````````````

cat("Start consolidation.\n* Loading dependencies... ")
pkgs <- c("RSQLite", "dplyr", "purrr", "rprojroot")
lapply(pkgs, function(x)
  suppressPackageStartupMessages(require(x, character.only = TRUE))
)

if (all(pkgs %in% .packages())) {
  rm(pkgs)
  cat("Done\n")
}

## Make relevant files discoverable in-project
root <- is_rstudio_project
criterion <- has_file("narc-mailing-list.Rproj")
database <- "NARC-mailing-list.db"
path_to_db <-
  find_root_file("data", database, criterion = criterion)
path_to_funs <-
  find_root_file("src", "funs.R", criterion = criterion)

# Load custom functions from funs.R
source(path_to_funs)

df <- import_db(path_to_db, "NARC_mail")

cat("* Overview of the data:\n")
print(as_tibble(df))

cat("NEXT: Check identifier variables for duplications\n")
pause()
invisible(df %>%
            select(name, phone, email) %>%
            {
              cat("* Number of duplications:\n")
              sapply(colnames(.), function(x) {
                cat("** Column",
                    sQuote(x),
                    "has",
                    sum(duplicated(.[[x]]), na.rm = TRUE),
                    "duplications\n")
              })
            })
cat("NEXT: Aggregate the duplicated values\n")
pause()

cat("* Sort the data frame by 'name':\n")
arr <- df %>%
  as_tibble() %>% 
  select(-serialno) %>%
  distinct() %>%
  arrange(name)
print(arr)

cat("NEXT: Attempt to fill in missing values\n")  # use greedy algorithm
pause()

## Find repeated names and associated records
cons <- fix_multip(arr)

if(exists("cons")) {
  cat("* Merge completed.\n\n* View the data:\n")
  print(cons)
}

cat("NEXT: Save consolidated data to disk\n")
pause()

nuTbl <- "mail_consolid"
cat(sprintf("* Store data in table '%s'... ", nuTbl))
dbcon <- dbConnect(SQLite(), path_to_db)
dbWriteTable(dbcon, nuTbl, cons, overwrite = TRUE)
dbDisconnect(dbcon)
cat("Done\n")

# cat("Conducting integrity checks... ")
# dbcon <- dbConnect(SQLite(), path_to_db)
# chk <- dbReadTable(dbcon, nuTbl)
# dbDisconnect(dbcon)


cat("Finished successfully.\n")
