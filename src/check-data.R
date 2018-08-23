# check-data.R

# Helper functions for Data Integrity Checks after the consolidation

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




typesUnchanged <- function(tracker, arr, df)
{
  cat("* Type checking... ")
  tracker <- if (identical(sapply(arr, typeof), sapply(df, typeof))) {
    cat("OK\n")
    append(tracker, TRUE)
  }
  else {
    cat("Failed\n")
    append(tracker, FALSE)
  }
}


noEmptyFields <- function(trk, df)
{
  cat("* Empty fields?... ")
  trk <- if (any(sapply(df, function(x) all(is.na(x))))) {
    cat("No\n")
    append(trk, TRUE)
  }
  else {
    cat("NOTE\n")
    append(trk, FALSE)
  }
}


noMissingNames <- function(trk, df)
{
  cat("* Missing names?... ")
  trk <- if (anyNA(df$name)) {
    missed <- which(is.na(df$name))
    cat(
      "Names were missing from",
      ngettext(length(missed), "row", "rows"),
      paste(as.character(missed, collapse = ", ")),
      "\n"
    )
    append(trk, FALSE)
  }
  else {
    cat("No\n")
    append(trk, TRUE)
  }
}


noDuplicatedNames <- function(trk, df)
{
  cat("* Duplicated names?... ")
  trk <- if (anyDuplicated(df$name)) {
    cat("Yes\n")
    append(trk, FALSE)
  }
  else {
    cat("No\n")
    append(trk, TRUE)
  }
}


noDuplicatedPhone <- function(trk, df)
{
  cat("* Duplicated phone numbers?... ")
  trk <- if (anyDuplicated(df$phone)) {
    cat("Yes\n")
    append(trk, FALSE)
  }
  else {
    cat("No\n")
    append(trk, TRUE)
  }
}

noDuplicatedEmail <- function(trk, df)
{
  cat("* Duplicated email addresses?... ")
  trk <- if (anyDuplicated(df$email)) {
    cat("Yes\n")
    append(trk, FALSE)
  }
  else {
    cat("No\n")
    append(trk, TRUE)
  }
}


noEmptyRows <- function(trk, df)
{
  cat("* Empty rows?... ")
  emptyRows <- apply(df, 1, function(x) all(is.na(x)))
  trk <- if (any(emptyRows)) {
    cat("Yes\n")
    append(trk, FALSE)
  }
  else {
    cat("No\n")
    append(trk, TRUE)
  }
}
