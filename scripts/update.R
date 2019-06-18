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
  deProjFile <- file.choose()
} else {
  if (length(arg) == 1L)
    deProjFile <- arg
  else
    stop("Usage: Rscript <scriptname> <DataEntry project>")
}

if (!file.exists(deProjFile)) {
  stop(sQuote(deProjFile), "does not exist")
}

# Create self-contained space for the incoming data
databox <- new.env()
load(deProjFile, databox, verbose = TRUE)

# ------------------------------------------------------------------------
# Database operations
con <- dbConnect(SQLite(), "data/NARC-mailing-list.db")

try({
  
  oldData <- dbReadTable(con, name = "mail_consolid")
  newData <- databox$Data %>% 
    select(-id)             # remove DataEntry::DataEntry()'s auto-numbering
  
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
  
  cat("Writing new records to local database...")
  dbWriteTable(con,
               name = "mail_consolid",
               value = updatedData,
               overwrite = TRUE)
  cat(sprintf("%d new records added to the database\n", numNewData))
  
  databox$Data <- newData[FALSE, ]
  databox$Data <- databox$Data %>% 
    {
      bind_cols(data.frame(id = integer()), .)  # return id column
    }
  
  # ---- Caching -----------------------------------------------------
  cache <- normalizePath("data/.cache")
  
  if (!dir.exists(cache))
    dir.create(cache)
  
  tmp <- tempfile("cache", cache, ".rds")
  saveRDS(newData, tmp)
  save(list = ls(envir = databox), file = deProjFile, envir = databox)
  
  cat("Data entry file has been reset and backup cached at",
      dirname(tmp),
      fill = TRUE)
  
})

dbDisconnect(conn = con)
#END
