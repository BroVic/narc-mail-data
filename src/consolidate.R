## consolidate.R

## Consolidate the database by merging repeated records
## ````````````````````````````````````````````````````


library(RSQLite)
library(tidyverse)
library(rprojroot)


## Some housekeeping...
root <- is_rstudio_project
crit <- has_file("narc-mailing-list.Rproj")
path_to_db <- find_root_file("data", "NARC-mailing-list.db", criterion = crit)
path_to_funs <- find_root_file("src", "funs.R", criterion = crit)
source(path_to_funs)

df <- import_db(path_to_db, "NARC_mail")

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
  select(-serialno) %>% 
  distinct() %>% 
  arrange(name)
print(arr)

cat("\nNext: Attempt to fill in missing values\n")  # use greedy algorithm
pause()

## Find repeated names and associated records
## List unique names
uniq <- unique(arr$name)
cons <- map_dfr(uniq, function(N) {
  merg <- arr %>%
      filter(name %in% N)
  if (nrow(merg) > 1) {
    cat(sprintf("* Merging available records for '%s':\n", N))
    merg <- colnames(merg) %>%
      map_dfc(function(var) {
        U <- unique(merg[[var]])
        
        ## where there is more than one distinct
        ## value, present the user with options
        if (length(U) > 1) {
          pick <-
            menu(
              choices = U,
              title = paste(
                "** Pick a value from the column",
                sQuote(var),
                "to use in the merged record:"
              )
            )
          val <- U[pick]
        }
        else {
          val <- U
        }
        val
      })
  }
})


# TODO: After consolidation, carry out some integrity checks...
