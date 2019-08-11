<#
.SYNOPSIS
Send an email from within Powershell using data stored in CSV and SQLite data tables.
.DESCRIPTION
A dataset containing individuals' names and email addresses is accessed, providing
options for selecting appropriate tables (for SQLite databases) and then columns.
General email inputs are requested, including authentication credentials - Gmail is 
the supported service.

NB: To use this script with Gmail, go to Google Account settings at
https://myaccount.google.com/u/1/security and enable "Less Secure Apps". 
(09 Aug 2019)
.PARAMETER Attachments
An array of paths and filename for files to be attached to the email.
.NOTES
Author: Victor A. Ordu
Copyright: DevSolutions Ltd.
Version: 0.0.0.9003
Last Edit: 2019-08-11
.INPUTS
None
.OUTPUTS
None
.LINK
https://github.com/DevSolutionsLtd/narc-mail-data/scripts/PS/email.ps1
#>

param(
    [Parameter(Mandatory = $false)]
    [string[]]$Attachments
)

###################################################
# Definition for local function(s)
###################################################
function Read-SpecifiedValues
{
    param(
        [string]$Value
    )
    $stub = "Name of column holding recipients' {0}"
    Read-Host -Prompt ($stub -f $Value)
}
function Read-ColumnNames
{
    [string[]]$columnNames = @()
    $values = "names", "email addresses"
    foreach ($value in $values) {
        $columnNames += Read-SpecifiedValues $value
    }
    
    @{columnName=$columnNames}
}

#######################################################
# Dependencies
#######################################################

# Install PSSQLite Module, if necessary
$module = "PSSQLite"
if (-not (Get-InstalledModule).Name.Contains($module)) {
    $PowerShellVersion = $PSVersionTable.PSVersion.Major
    if (($PowerShellVersion -lt 5) -and ($PowerShellVersion -ge 3)) {
        Add-Type -AssemblyName System.IO.Compression.Filesystem -ErrorAction Stop

        # Download the archive
        $url = 'https://github.com/RamblingCookieMonster/PSSQLite/zipball/master'
        $dwnDir = "$home/Downloads"
        if (-not (Test-Path $dwnDir)) {
            New-Item -ItemType Directory $dwnDir
        }
        $sqlZip = Join-Path -Path $dwnDir -ChildPath "PSSQLite.zip"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Verbose "Downloading the $module Module... "
        Invoke-WebRequest -Uri $url -OutFile $sqlZip | Write-Progress
                
        # Unzip it to user's Module directory
        $userModPath = $env:PSModulePath.split(';') | Where-Object { $_.Contains("Documents") }
        if (-not (Test-Path $userModPath)) {
            New-Item -ItemType Directory $userModPath
        }
        $Overwrite = $true
        $files = [IO.Compression.Filesystem]::OpenRead($sqlZip).Entries
        $files | ForEach-Object -Process {
                $filepath = Join-Path -Path $userModPath -ChildPath $_
                [IO.Compression.ZipFileExtensions]::ExtractToFile($_, $filepath, $Overwrite)
            }
    }
    elseif ($PowerShellVersion -ge 5) {
        Install-Module $module -Scope CurrentUser
    }
    else {
        Write-Error "Automated installation not enabled for versions lower than 3.0"
    }
}

Import-Module $module

###############################################
# Data retrieval
###############################################
do {
    [string]$datafile = Read-Host -Prompt "Enter path to the datafile"
} while (-not (Test-Path $datafile))

[bool]$isCsv = $datafile.EndsWith(".csv")
[bool]$isSqliteDb = $datafile.EndsWith(".db") -or $datafile.EndsWith(".sqlite")  # TODO: Go binary.

$names = $emails = @()

if ($isCsv) {
    $csvData = Import-Csv $datafile
    $dataPreview = $csvData[1..3]
} 
elseif ($isSqliteDb) {
    $conn = New-SQLiteConnection -DataSource $datafile
    function Use-Query
    {
        param([string]$Query)
        Invoke-SqliteQuery -SQLiteConnection $conn -Query $Query
    }

    Write-Host "Tables in this database:"
    $availTbls = Use-Query "PRAGMA STATS"
    $availTbls | Format-Table

    do {
        [string]$table = Read-Host -Prompt "Pick one (Enter name of the table)"
        $tableExists = $availTbls.table.Contains($table)
    } while (-not $tableExists)
    $dataPreview = Use-Query "SELECT * FROM $table LIMIT 3;"
}

$opt = Read-Host -Prompt "Preview the data table? (Y/N)"
if ($opt -eq 'Y') {
    $dataPreview | Format-Table
}

$result = Read-ColumnNames
$col_name = $result.columnName[0]
$col_email = $result.columnName[1]

if ($isSqliteDb) {
    $names = Use-Query "SELECT $col_name FROM $table;"
    $emails = Use-Query "SELECT $col_email FROM $table;"
    $conn.Shutdown()   # We're done with DB
}
elseif ($isCsv) {
    $names = $csvData.$col_name
    $emails = $csvData.$col_email
}

########################################################
# Prepare and send email message
########################################################
[string]$Subject = Read-Host "Subject (required)"

[string]$msg = Read-Host "Message (optional or path to .TXT file)"
$msg = $msg.Trim()
if ($msg.Length -eq 0) {
    $msg = " "
    Write-Warning "No message provided"
}

if ((Test-Path $msg) -and ($msg.CompareTo(" ") -ne 0)) {
    if ($msg.EndsWith(".txt")) {
        $msg = Get-Content $msg
    }
    else {
        Write-Error "Reading of this type of file is not supported."
    }
}

$storedCredentials = Get-Credential
[string]$Sender = $storedCredentials.UserName

$SMTPServer = "smtp.gmail.com"
[int]$SMTPPort = 587

if ((Read-Host "Sending message(s). Continue? (Y/N)") -eq 'Y') {
    for ($i = 0; $i -lt $names.Length; $i++) {
        if ($isSqliteDb) {
            $nameString = $names[$i].name
            $emailAddress = $emails[$i].email
        }
        elseif ($isCsv) {
            $nameString = $names[$i]
            $emailAddress = $emails[$i]
        }

        $Receiver = "$nameString <$emailAddress>"

        $placeholder = "<<Name>>"
        $body = $msg
        if ($msg.Contains($placeholder)) {
            $body = $msg.Replace($placeholder, $nameString)
        }

        if ($Attachments.Length -ne 0 -and (Test-Path $Attachments)) {
            Send-MailMessage -from $Sender -to $Receiver -Subject $Subject -Body $body -Attachments $Attachments -SmtpServer $SMTPServer -port $SMTPPort -UseSsl -Credential $storedCredentials
        }
        else {
            Send-MailMessage -from $Sender -to $Receiver -Subject $Subject -Body $body -SmtpServer $SMTPServer -port $SMTPPort -UseSsl -Credential $storedCredentials
        }
        
        Write-Progress "Sending email" -PercentComplete ($i/$names.Length*100)
    }
}
else {
    Write-Output "Nothing to be done"
}