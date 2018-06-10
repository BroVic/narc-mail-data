## harmonise.R

## Harmonising various spreadsheets into one database
if (suppressWarnings(!require("NARCcontacts", character.only = TRUE)))
  devtools::install_github("DevSolutionsLtd/NARCcontacts")

if (interactive()) {
  workbooks <-
    readline("Enter path to directory containing spreadsheets: ")
} else {
  args <- commandArgs(trailingOnly = TRUE)
  if (!is.null(args))
    workbooks <- args
}

if (!dir.exists(workbooks))
  stop(sQuote(basename(workbooks)), " does not exist at this location.")

NARCcontacts::harmonise_narc_excel(workbooks)
