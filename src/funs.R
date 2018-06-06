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
