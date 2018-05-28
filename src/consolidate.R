## consolidate.R

## Consolidate the database by merging repeated records
library(RSQLite)
suppressPackageStartupMessages(library(dplyr))

dbcon <- dbConnect(SQLite(), "workbooks/harmonised-data/NARC-mailing-list.db")
tabl <- grep("NARC_mail", dbListTables(dbcon), value = TRUE)
df <- dbReadTable(dbcon, tabl)
dbDisconnect(dbcon)

glimpse(df)

df %>% 
    group_by(name, email, phone) %>% 
    summarise_all(funs(first))
