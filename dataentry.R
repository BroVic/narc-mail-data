# dataentry.R

## Upon successful exectution, this script will open a data entry form.

if (!requireNamespace("DataEntry")) install.packages("DataEntry")
DataEntry::DataEntry()
