# dataentry.R

## Upon successful execution, this script will open a data entry form.

if (!requireNamespace("DataEntry"))
  install.packages(c("RGtk2", "gWidgets2", "gWidgets2RGtk2", "DataEntry"))

DataEntry::DataEntry()
