# funs.R


checkIdVarDuplicates <- function(dframe)
{
  cat("NEXT: Check identifier variables for duplications\n")
  pause()
  invisible(dframe %>%
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
}


aggregateDuplicatedVals <- function(x)
{
  cat("NEXT: Aggregate the duplicated values\n")
  pause()
  cat("* Sort the data frame by 'name':\n")
  arr <- x %>%
    as_tibble() %>% 
    select(-serialno) %>%
    distinct() %>%
    arrange(name)
  print(arr)
  arr
}







fillMissingVals <- function(d, skip = FALSE)
{
  if (skip)
    return(d)
  
  ## Find repeated names and associated records
  cons <- .fixMultipleValues(d)
  if(exists("cons")) {
    cat("* Merge completed.\n\n* View the data:\n")
    print(cons)
  }
  cons
}







checkDataIntegrity <- function(df_r, df_p, skip = FALSE)
{
  if (skip)
    return(NULL)
  cat("NEXT: Check integrity of the data. (Please review the output!)\n")
  pause()
  testsPassed <- NULL %>% 
    typesUnchanged(df_r, df_p) %>% 
    noEmptyFields(df_p) %>% 
    noMissingNames(df_p) %>% 
    noDuplicatedNames(df_p) %>% 
    noDuplicatedPhone(df_p) %>% 
    noDuplicatedEmail(df_p) %>%
    noEmptyRows(df_p)
  
  if (!all(testsPassed)) {
    message("Some data integrity checks failed. Kindly review the output.")
  }
  
  cat("* Proportion of cells with missing values... ")
  htWidth <- dim(df)
  allCells <- htWidth[1] * htWidth[2]
  allEmpty <- sum(is.na(df))
  perC <- round(allEmpty / allCells * 100)
  cat(paste0(allEmpty, "/", allCells, " (approx. ", perC, "%)\n"))
  invisible(0)
}








storeConsolidatedData <- function(df, db)
{
  cat("NEXT: Save consolidated data to disk\n")
  pause()
  nuTbl <- "mail_consolid"
  cat(sprintf("* Store data in table '%s'... ", nuTbl))
  dbcon <- dbConnect(SQLite(), db)
  on.exit(dbDisconnect(dbcon))
  if (nuTbl %in% dbListTables(dbcon)) {
    write <- 
      menu(choices = c("Yes", "No"),
           title = "\nYou are about to overwrite an existing table. Continue?")
  }
  if (identical(write, 1L)) {
    dbWriteTable(dbcon, nuTbl, df, overwrite = TRUE)
    cat("* The data were saved.\nConsolidation completed.\n")
  } else if (identical(write, 2L)) {
    message("The data were not stored on disk.")
  }
}









## Imports a table from a database
## @param db An SQLite database
## @param table The table to be imported
## @return Returns an object of class \code{data.frame}
importDataFromDb <- function(db, table) {
  stopifnot(is.character(db), is.character(table))
  stopifnot(file.exists(db))
  bin <- readBin(db, what = 'raw', n = 16L)
  if (!identical(rawToChar(bin), "SQLite format 3"))
    stop("'db' is not a supported file format")
  dbcon <- dbConnect(SQLite(), db)
  on.exit(dbDisconnect(dbcon))
  if (!dbIsValid(dbcon))
    stop("There was a problem making the database connection")
  
  if (table %in% dbListTables(dbcon))
    df <- dbReadTable(dbcon, table)
  else {
    message("No table called ", sQuote(table), "in ", sQuote(basename(db)))
    return(NULL)
  }
}






## Utility function to enhance interaction with user
pause <- function() {
  if (interactive()) {
    readline("Press ENTER to continue...")
  }
}








## Allows user to interactively fix multiple entries (by variable)
.fixMultipleValues <- function(dataframe) {
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
