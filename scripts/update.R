# Update the local database using records stored in the .DTE file

cat("Attaching required packages... ")
suppressPackageStartupMessages(
  x <- lapply(c("RSQLite", "tidyverse"), 
         function(x) {
           invisible(library(x, character.only = TRUE, quietly = TRUE))
         }
  )
)
cat("Done.\n")

arg <- commandArgs(trailingOnly = TRUE)

if (interactive()) {
  dataEntryFile <- file.choose()
} else {
  if (length(arg) == 1L)
    dataEntryFile <- arg
  else
    stop("Usage: Rscript <scriptname> <DataEntry project>")
}


# Create self-contained space for the incoming data
databox <- new.env()
load(dataEntryFile, databox, verbose = TRUE)


# ------------------------------------------------------------------------
# Database operations


newData <- databox$Data %>% 
  select(-id)             # remove DataEntry::DataEntry()'s auto-numbering

cat("Select the database to be updated\n")
databaseFile <- file.choose()

con <- dbConnect(SQLite(), databaseFile)


try ({
  
  tableName <- "NARC_consolidated"
  
  if (isDbFile <- endsWith(databaseFile, ".db")) {
    oldData <-
      dbReadTable(con, name = ) # TODO: Fetch table name generically
    
  } else if (endsWith(databaseFile, ".rds")) {
    oldData <- readRDS(databaseFile)
    
  }
  
  # TODO: Undo this hard-coding later
  oldData <- oldData %>% 
    select(-serialno)
  
  if (!identical(colnames(oldData), colnames(newData))) {
    stop("Column mismatch between incoming and existing datasets")
  }
  
  updatedData <- oldData %>%
    bind_rows(newData)
  
  numNewData <- nrow(newData)
  if ((nrow(oldData) + numNewData) != nrow(updatedData)) {
    warning("The sum of observations from both datasets is incorrect")
    
    opt <- menu(c("Yes", "No"), title = "Continue?")
    
    if (identical(opt, 2L))
      stop("Operation was stopped")
  }
  
  if (isDbFile) {
    cat("Writing new records to local database...")
    dbWriteTable(con,
                 name = tableName,
                 value = updatedData,
                 overwrite = TRUE)
    cat(sprintf("%d new records added to the database\n", numNewData))
  } 
  else {
    saveRDS(updatedData, file = databaseFile)
  }
  
  # Reset the data entry project file
  databox$Data <- newData[FALSE, ]
  databox$Data <- databox$Data %>% 
  {
    bind_cols(data.frame(id = integer()), .)  # return id column
  }
  save(list = ls(envir = databox), file = dataEntryFile, envir = databox)
  
  # ---- Caching -----------------------------------------------------
  cache <- normalizePath("data/.cache")
  
  if (!dir.exists(cache))
    dir.create(cache)
  
  tmp <- tempfile("cache", cache, ".rds")
  saveRDS(newData, tmp)
  
  cat("Data entry file has been reset and backup cached at",
      dirname(tmp),
      fill = TRUE)
})

dbDisconnect(conn = con)

#END
