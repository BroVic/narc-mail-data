# dataentry.R

## Upon successful execution, this script will open a data entry form.

if (!requireNamespace("DataEntry")) {
  dep <- c("RGtk2", "gWidgets2", "gWidgets2RGtk2")
  isMissing <- isFALSE(dep %in% .packages(all.available = TRUE))
  install.packages(c(dep[isMissing], "DataEntry"), repos = "https://cran.rstudio.com")
}

DataEntry::DataEntry()
