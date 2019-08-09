
attach_packages <- function() {
  cat("Attaching required packages... ")
  suppressPackageStartupMessages(
    x <-
      lapply(c("RSQLite", "tidyverse"),
             function(x) {
               invisible(library(x, character.only = TRUE, quietly = TRUE))
             })
    )
  cat("Done.\n")
}





cacheData <- function(data) {
  cache <- normalizePath("data/.cache")
  
  if (!dir.exists(cache))
    dir.create(cache)
  
  tmp <- tempfile("cache", cache, ".rds")
  saveRDS(data, tmp)
  tmp
}



fetch_entered_data <- function() {
  if (interactive()) {
    ff <- file.choose()
  }
  else {
    arg <- commandArgs(trailingOnly = TRUE)
    if (length(arg) == 1L)
      ff <- arg
    else
      stop("Usage: Rscript <scriptname> <DataEntry project>")
  }
  ff
}




select_db_or_object <- function() {
  cat("Select the database or object to be updated\n")
  file.choose()
}







work_with_database <- function(db, newData) {
  
  con <- dbConnect(SQLite(), db)
  on.exit(dbDisconnect(con))
  tblList <- dbListTables(con)
  tableName <- menu(tblList, title = "Select a table") %>% 
    { tblList[.] }
  oldData <-
    dbReadTable(con, name = tableName) # TODO: Fetch table name generically
  updated <- update_local_data(oldData, newData)
  dbWriteTable(con,
               name = tableName,
               value = newData,
               append = TRUE)
  report(newData)
}








work_with_rds <- function(rds, newData) {
  oldData <- readRDS(rds)
  updated <- update_local_data(oldData, newData)
  saveRDS(updated, file = rds)
  report(newData)
}









report <- function(df)
  cat(sprintf("%d new records were added\n", nrow(df)))






update_local_data <- function(oldData, enteredData) {
  # TODO: Undo this hard-coding later
  if (any(grepl(colnames(oldData), "serialno"))) {
    oldData <- oldData %>%
      select(-serialno)
  }
  
  if (!identical(colnames(oldData), colnames(enteredData))) {
    stop("Column mismatch between incoming and existing datasets")
  }
  
  updatedData <- oldData %>%
    bind_rows(enteredData)
  numNewData <- nrow(enteredData)
  
  if ((nrow(oldData) + numNewData) != nrow(updatedData)) {
    warning("The sum of observations from both datasets is incorrect")
    
    opt <- menu(c("Yes", "No"), title = "Continue?")
    
    if (identical(opt, 2L))
      stop("Operation was stopped")
  }
  updatedData
}










reset_dte_file <- function(file, enteredData, envir) {
  envir$Data <- enteredData[FALSE,]
  envir$Data <- envir$Data %>%
    {
      bind_cols(data.frame(id = integer()), .)  # id column
    }
  
  save(
    list = ls(envir = envir),
    file = file,
    envir = envir
  )
}
















