# dataentry.R

## Upon successful exectution, this script will open a data entry form.

if (!requireNamespace("DataEntry")) {
  # Install DataEntry dependencies
  install.packages(c("gWidgets2", "RGtk2", "gWidgets2RGtk2"))
  
  install.packages("DataEntry")
}

DataEntry::DataEntry()
