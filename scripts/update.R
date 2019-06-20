# Update the local database using records stored in the .DTE file

source(file.path(here::here(), "scripts", "helpers.R"))
attach_packages()

dataEntryFile <- fetch_entered_data()

selfContainedSpace <- new.env()
load(dataEntryFile, selfContainedSpace, verbose = TRUE)

enteredData <- selfContainedSpace$Data %>% select(-id)

dtFile <- select_db_or_object()

if (!(isDb <- endsWith(dtFile, ".db")) &
    !(isRds <- endsWith(dtFile, ".rds")))
  stop("File format is not supported")

if (isDb)
  work_with_database(dtFile, enteredData) else if (isRds)
    work_with_rds(dtFile, enteredData)

reset_dte_file(dataEntryFile, enteredData, selfContainedSpace)

temp <- cacheData(enteredData)
  
cat("Data entry file has been reset and backup cached at",
    dirname(temp),
    fill = TRUE)
#END
