# Update the local database using records stored in the .DTE file

cat("Attaching required packages... ")
suppressPackageStartupMessages(
  x <- lapply(c("here", "NARCcontacts", "RSQLite", "tidyverse"), 
         function(x) {
           invisible(library(x, character.only = TRUE, quietly = TRUE))
         }
  )
)
cat("Done.\n")

arg <- commandArgs(trailingOnly = TRUE)

if (interactive() && identical(getwd(), here())) {
  deProjFile <- "data/dataentry-sample.dte"
} else if (length(args) != 1) {
  stop("Usage: Rscript <scriptname> <DataEntry project>")
}

deProjFile <- arg
if (!file.exists(deProjFile)) {
  stop(sQuote(deProjFile), " does not exist")
}

# Create self-contained space for the incoming data
databox <- new.env()
load(deProjFile, databox, verbose = TRUE)

newData <- databox$Data %>% 
  select(-id)             # remove DataEntry::DataEntry()'s auto-numbering


# ------------------------------------------------------------------------
# Database operations
con <- dbConnect(SQLite(), "data/NARC-mailing-list.db")

try({
  
  oldData <- dbReadTable(con, name = "mail_consolid")

  if (!identical(colnames(oldData), colnames(newData))) {
    stop("Column mismatch between incoming and existing datasets")
  }
  
  updatedData <- oldData %>%
    bind_rows(newData)
  
  numNewData <- nrow(newData)
  if (nrow(oldData) + numNewData != nrow(updatedData)) {
    
    warning("The sum of observations from both datasets is incorrect")
    
    opt <- menu(c("Yes", "No"), title = "Continue?")
    
    if (identical(opt, 2L))
      stop()
  }
  
  cat("Writing new records to local database...")
  dbWriteTable(con,
               name = "mail_consolid",
               value = updatedData,
               overwrite = TRUE)
  cat(sprintf("%d new records added to the database\n", numNewData))
  
})
dbDisconnect(conn = con)
# ------------------------------------------------------------------------


cat("Caching... \n")
tmp <- tempfile()
saveRDS(newData, tmp)
cat(
  sprintf("Cache witn %d records stored in .RDS format at %s", numNewData, tmp),
  file = "log.txt",
  fill = TRUE
)


cat("Resetting the records in the data entry project file.\n")
databox$Data <- newData[FALSE, ]
databox$Data <- databox$Data %>% 
  {
    bind_cols(data.frame(id = integer()), .)  # return id column
  }
save(list = ls(envir = databox), file = deProjFile, envir = databox)
# DONE
