# funs.R

## Imports a table from a database
## @param db An SQLite database
## @param table The table to be imported
## @return Returns an object of class \code{data.frame}
import_db <- function(db, table) {
  require(RSQLite, quietly = TRUE)
  
  if (!endsWith(db, ".db"))
    stop("Unsupported file format")
  dbcon <- dbConnect(SQLite(), db)
  if (!dbIsValid(dbcon))
    stop("There was a problem making the database connection")
  
  if (table %in% dbListTables(dbcon))
    df <- dbReadTable(dbcon, table)
  else
    message("No table called ", sQuote(table), "in ", sQuote(basename(db)))
  dbDisconnect(dbcon)
  df
}


## Utility function to enhance interaction with user
pause <- function() {
  if (interactive()) {
    readline("Press ENTER to continue...")
  }
}


## Allows user to interactively fix multiple entries (by variable)
fix_multip <- function(dataframe) {
  uniq <- unique(dataframe$name)
  lapply(uniq, function(N) {
    ## Extract a data frame of a given name
    one_name <- filter(dataframe, name == N)
    
    if (nrow(one_name) > 1) {
      cat(sprintf("* Merging available records for '%s'\n", N))
      one_name <- colnames(one_name) %>%
        sapply(
          simplify = FALSE,
          FUN = function(var) {
            val <- unique(one_name[[var]])
            
            ## Don't present NAs as options
            if(!all(is.na(val))) {
              val <- val[!is.na(val)]
            }
            
            ## where there is more than one distinct
            ## value, present the user with options
            if (length(val) > 1) {
              pick <-
                menu(
                  choices = val,
                  title = sprintf("** Pick a value from the column '%s':", var)
                )
              val[pick]
            }
            else
              val
          }
        )
    }
    else {
      one_name
    }
  }) %>%
    lapply(as_tibble) %>%
    bind_rows()
}
