# locate-msg.R

## Locate media files on a specific computer, obtain the metadata and store in
## a database
library(RSQLite)


## Search for files that have a given file extension
myComp <- Sys.info()
root <- choose.dir()
cat("Looking for media files in ", root, " and its subfolders:\n")
pat <- ".wav$|.mp3$|.mp4$|.wma$|.wmv$|.midi$"

list <- list.files(
  path = root,
  pattern = pat,
  recursive = TRUE,
  ignore.case = TRUE,
  full.names = TRUE,
  all.files = TRUE,
  include.dirs = FALSE
)
df <- purrr::map_dfr(list, function(media) {
  ## Extract the metadata of each file so listed
  details <- file.info(media)
  
  ## Build a data frame of the metadata
  abbr <-
    toupper(
      substr(media, regexpr(pat, media, ignore.case = TRUE) + 1, nchar(media))
    )
  dat <- data.frame(
    title = NA_character_,
    minister = NA_character_,
    filename = basename(media),
    media.format = abbr,
    file.size = details$size,
    created = details$ctime,
    modified = details$mtime,
    accessed = details$atime,
    location = dirname(media),
    computer = myComp["nodename"],
    user = myComp["user"],
    stringsAsFactors = FALSE
  )
  dat
})

## Store the data frame in a database
dbcon <- dbConnect(SQLite(), "NARC_media.db")
try({
  cat("Writing the file listing to the database")
  dbWriteTable(dbcon, "message_list", df, append = TRUE)
})
dbDisconnect(dbcon)
