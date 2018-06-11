## consolidate.R

## Consolidate the database by merging repeated records
## ````````````````````````````````````````````````````

cat("Loading dependencies... ")
pkgs <- c("RSQLite", "dplyr", "purrr", "rprojroot")
lapply(pkgs, function(x)
  suppressPackageStartupMessages(require(x, character.only = TRUE))
)
found <- pkgs %in% .packages()
if (all(found)) {
  cat("Done\n")
}

## Some housekeeping...
root <- is_rstudio_project
criterion <- has_file("narc-mailing-list.Rproj")
database <- "NARC-mailing-list.db"
path_to_db <-
  find_root_file("data", database, criterion = criterion)
path_to_funs <-
  find_root_file("src", "funs.R", criterion = criterion)

source(path_to_funs)
df <- import_db(path_to_db, "NARC_mail")

cat("* Overview of the data:\n\n")
glimpse(df)

cat("Next: Check identifier variables for duplications\n")
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
cat("Next: Aggregate the duplicated values\n")
pause()

cat("* Sort the data frame by 'name':\n")
arr <- df %>%
  as_tibble() %>% 
  select(-serialno) %>%
  distinct() %>%
  arrange(name)
print(arr)

cat("Next: Attempt to fill in missing values\n")  # use greedy algorithm
pause()

## Find repeated names and associated records
## List unique names
uniq <- unique(arr$name)
cons <- lapply(uniq, function(N) {
  
  ## Extract a data frame of a given name
  one_name <- filter(arr, name == N)
  
  if (nrow(one_name) > 1) {
    cat(sprintf("* Merging available records for '%s':\n", N))
    one_name <- colnames(one_name) %>%
      lapply(function(var) {
        val <- unique(one_name[[var]])
        
        ## where there is more than one distinct
        ## value, present the user with options
        if (length(val) > 1) {
          pick <-
            menu(
              choices = val,
              title = paste("** Pick a value from the column", sQuote(var))
            )
          val[pick]
        }
        else val
      }) %>% 
      as_tibble()
  }
  else {
    one_name %>% as_tibble()
  }
}) %>%
  bind_rows()

if(exists("cons"))
  cat("* Done merging.\n")

# TODO: After consolidation, carry out some integrity checks...

# Store to a different table in the database
nuTabl <- "mail_consolid"
cat(sprintf("* Store data in table '%s'... ", nuTabl))
dbcon <- dbConnect(SQLite(), path_to_db)
dbWriteTable(dbcon, nuTabl, cons, overwrite = TRUE)
dbDisconnect(dbcon)
cat("Done\n")
