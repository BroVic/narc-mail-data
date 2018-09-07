# locate-msg.R

library(RSQLite)

if (interactive()) {
  root <- choose.dir()
  if (is.na(root))
    stop("No folder was selected")
} else {
  root <- commandArgs(trailingOnly = TRUE)
  if (length(root) > 1) {
    root <- root[1]
    warning("Only", sQuote(root), "was used; other arguments were ignored")
  }
}

## Locate media files on a specific computer,  
## obtain the metadata and store in a database
cat("Looking for media files in",
    sQuote(root),
    "and its subfolders... ")

pat <- ".wav$|.mp3$|.mp4$|.wma$|.wmv$|.midi$"
fileList <- list.files(
  path = root,
  pattern = pat,
  recursive = TRUE,
  ignore.case = TRUE,
  full.names = TRUE,
  all.files = TRUE,
  include.dirs = FALSE
)

if (is.null(fileList) | !length(fileList)) {
  cat("Failed\n")
  message("No media files were discovered in ", sQuote(root))
} else {
  cat("Done\n")
  
  myComp <- Sys.info()
  df <- purrr::map_dfr(fileList, function(media) {
    ## Extract the metadata of each file so listed
    details <- file.info(media)
    
    ## Capitalised file format as part of record
    abbr <-
      toupper(substr(
        media,
        regexpr(pat, media, ignore.case = TRUE) + 1,
        nchar(media)))
    
    data.frame(
      title = NA_character_,
      minister = NA_character_,
      created = details$ctime,
      modified = details$mtime,
      accessed = details$atime,
      media.format = abbr,
      file.size = details$size,
      filename = basename(media),
      location = dirname(media),
      computer = myComp["nodename"],
      user = myComp["user"],
      stringsAsFactors = FALSE
    )
  })
  
  ## Store the data frame in a database
  dbcon <- dbConnect(SQLite(), "data/NARC_media.db")
  try({
    cat("Writing the file listing to the database")
    dbWriteTable(dbcon, "message_list", df, append = TRUE)
  })
  dbDisconnect(dbcon)
}

