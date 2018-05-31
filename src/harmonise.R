## harmonise.R

## Harmonising various spreadsheets into one database
if (!require(NARCcontacts))
  devtools::install_github("DevSolutionsLtd/NARCcontacts")
if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  if (!is.null(args))
    workbooks <- args
}
workbooks <-
  readline("Enter the path to the directory containing spreadsheets: ")
if (!dir.exists(workbooks))
  stop(sQuote(basename(workbooks)), " does not exist at this location.")

NARCcontacts::harmonise_narc_excel(workbooks)
