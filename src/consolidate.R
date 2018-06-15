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

cat("NEXT: Check integrity of the data. (Please review the output!)\n")
pause()

cat("* Type checking... ")
if (identical(sapply(arr, typeof), sapply(cons, typeof))) {
  cat("OK\n")
} else cat("Failed\n")

cat("* Empty fields?... ")
if (any(sapply(cons, function(x) all(is.na(x))))) {
  cat("No\n")
} else cat("NOTE\n")

cat("* Missing names?... ")
if (anyNA(cons$name)) {
  missed <- which(is.na(cons$name))
  cat(
    "Names were missing from",
    ngettext(length(missed), "row", "rows"),
    paste(as.character(missed, collapse = ", ")),
    "\n")
} else cat("No\n")

cat("* Duplicated names?... ")
if (anyDuplicated(cons$name)) {
  cat("Yes\n")
} else cat("No\n")

cat("* Duplicated phone numbers?... ")
if (anyDuplicated(cons$phone)) {
  cat("Yes\n")
} else cat("No\n")

cat("* Duplicated email addresses?... ")
if (anyDuplicated(cons$email)) {
  cat("Yes\n")
} else cat("No\n")

cat("* Empty rows?... ")
len <- ncol(cons)
emptyRows <- apply(cons, 1, function(x) all(is.na(x)))
if (any(emptyRows)) {
  cat("Yes\n")
} else cat("No\n")

cat("* Proportion missing... ")
wb <- dim(cons)
allCells <- wb[1] * wb[2]
allEmpty <- sum(is.na(cons))
perC <- round(allEmpty / allCells * 100)
cat(paste0(allEmpty, "/", allCells, " (approx. ", perC, "%)\n"))


cat("NEXT: Save consolidated data to disk\n")
pause()

nuTbl <- "mail_consolid"
cat(sprintf("* Store data in table '%s'... ", nuTbl))
dbcon <- dbConnect(SQLite(), path_to_db)
if (nuTbl %in% dbListTables(dbcon)) {
  write <- 
    menu(choices = c("Yes", "No"),
         title = "\nYou are about to overwrite an existing table. Continue?")
}

if (identical(write, 1L)) {
  dbWriteTable(dbcon, nuTbl, cons, overwrite = TRUE)
  cat("* The data were saved.\nConsolidation completed.\n")
} else if (identical(write, 2L)) {
  message("The data were not stored on disk.")
}

dbDisconnect(dbcon)

# cat("Checking database integrity... ")
# dbcon <- dbConnect(SQLite(), path_to_db)
# chk <- dbReadTable(dbcon, nuTbl)
# dbDisconnect(dbcon)
