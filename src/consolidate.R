## consolidate.R

## Consolidate the contacts database 
## `````````````````````````````````

## Make database discoverable
criterion <- rprojroot::has_file("narc-mailing-list.Rproj")
path_to_db <-
  rprojroot::find_root_file("data", "NARC-mailing-list.db", criterion = criterion)

NARCcontacts::consolidate_narc_mail(path_to_db)
