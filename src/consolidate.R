## consolidate.R

## Consolidate the database by merging repeated records
## ````````````````````````````````````````````````````

cat("Loading dependencies...\n ")
pkgs <- c("tidyverse", "RSQLite", "rprojroot")
lapply(pkgs, require, character.only = TRUE)
found <- pkgs %in% .packages()
if (all(found)) {
  cat("All required packages were successfully attached\n")
}

## Some housekeeping...
root <- is_rstudio_project
criterion <- has_file("narc-mailing-list.Rproj")
path_to_db <-
  find_root_file("data", "NARC-mailing-list.db", criterion = criterion)
path_to_funs <-
  find_root_file("src", "funs.R", criterion = criterion)

source(path_to_funs)
df <- import_db(path_to_db, "NARC_mail")

cat("Overview of the data:\n")
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
cons <- map_dfr(uniq, function(N) {
  
  ## Extract a data frame of a given name
  one_name <- arr %>%
    filter(name %in% N)
  
  if (nrow(one_name) > 1) {
    cat(sprintf("* Merging available records for '%s':\n", N))
    one_name <- colnames(one_name) %>%
      map_dfc(function(var) {
        val <- unique(one_name[[var]])
        
        ## where there is more than one distinct
        ## value, present the user with options
        if (length(val) > 1) {
          pick <-
            menu(
              choices = val,
              title = paste(
                "** Pick a value from the column",
                sQuote(var),
                "to use in the merged record:"
              )
            )
          val[pick]
        }
        else {
          val
        }
      })
  }
  else one_name
})


# TODO: After consolidation, carry out some integrity checks...
