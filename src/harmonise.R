## harmonise.R

## Harmonising Various Spreadsheets into one Database
if (!require(NARCcontacts))
    devtools::install_github("DevSolutionsLtd/NARCcontacts")
NARCcontacts::harmonise_narc_excel("workbooks/")
