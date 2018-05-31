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
  df <- as_tibble(df)
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
            })
cat("\nNext: Aggregate the duplicated values\n")
pause()

cat("* Sort the data frame by 'name':\n")
arr <- df %>%
  arrange(name) %>% 
  select(-serialno) %>% 
  print()


cat("\nNext: Attempt to fill in missing values\n")  # use greedy algorithm
pause()

## List unique names
uniq <- unique(arr$name)

## Find repeated names and associated records
cons <- map_dfr(uniq, function(N) {
  index <- which(arr$name == N)
  if (length(index > 1)) {
    sprintf("* Merging available records for '%s':\n", N)
    merg <- arr %>% 
      filter(name %in% N) %>% 
      map_dfc(function(x) {
        U <- unique(x)
        
        ## where there is more than one distinct 
        ## value, we present the user with options
        if (length(U) > 1) {
          picked <- menu(choices = U, title = "Choose one of the following:")
          val <- U[picked]
        }
        else {
          val <- U
        }
        val
      })
  }
})


# TODO: After consolidation, carry out some integrity checks...
