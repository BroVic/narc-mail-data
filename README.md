NARC Mailing List Project
================

This project originated from early attempts to improve data management processes at Nehemiah Apostolic Resource Centre in Abuja, Nigeria.

The complexity of the issues identified prompted the decision to develop R scripts thereby ensuring transparency and reproducibility, as well as quality control.

Usage
=====

Dependencies
------------

Apart from **[R](http://r-project.org)** itself, any other dependencies are automatically installed as required by the relevant scripts (*internet connection required*).
***NB: This project has only been tested for Windows***

Merging data from Excel files
-----------------------------

We can collect several Excel files and easily merge their data. For this to work optimally, ensure that all the files to be merged are in one single directory. To carry out the merge, run the following line of code:
**In Powershell**

    ./harmonise.ps1 <path/to/dir>

**Inside R**

``` r
source('scripts/harmonise.R')
```

When the operation is completed, all the data from the various spreadsheets will be saved to an *SQLite* located in the **data** directory.

Consolidating the data
----------------------

There are many unwanted repetitions in the database. To fix this, we have written an R script **consolidate.R**, which is also found in the **src** directory. Data consolidation is carried out interactively within an R session like this

``` r
source('scripts/consolidate.R')
```

The user will should study the output carefully and follow the prompts to rectify duplicated/erroneous entries.

Data entry
----------

In the interim, a data entry facility has been included with a view to markedly proper entries. To launch the electronic form, type

``` r
source('scripts/DataEntry.R')
```

For more information on how to use this feature

``` r
help('DataEntry', 'DataEntry')
```

Future plans
============

-   Web-based data entry formats
-   Embedded analytics
-   Dashboard (*Shiny* app)
