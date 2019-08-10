# Send an email from within Powershell using data stored in CSV and SQLite data tables

#####################        IMPORTANT NOTICE!            #######################
##                              09 Aug 2019                                    ##
##                                                                             ##
##    To use this script with Gmail, go to Google Account settings at          ##
##    https://myaccount.google.com/u/1/security and enable "Less Secure Apps". ##
##                                                                             ##                                                                             ##
#################################################################################

# Definition of local function(s)
function Read-ColumnNames
{
    $stub = "Name of column holding recipients' "
    [string]$nameCol = Read-Host -Prompt ($stub + "names")
    [string]$emailCol = Read-Host -Prompt ($stub + "email addresses")
    @($nameCol, $emailCol)
}

###########################

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

# Retrieve data from the datafile
Import-Module $module

[string]$datafile = Read-Host -Prompt "Enter path to the datafile"

[bool]$isCsv = $datafile.EndsWith(".csv")
[bool]$isSqliteDb = $datafile.EndsWith(".db") -or $datafile.EndsWith(".sqlite")  # TODO: Go binary.

$names = $emails = $result = @()

if ($isCsv) {
    $cvsDdata = Import-Csv $datafile
    $cvsDdata | Format-Table
} 
elseif ($isSqliteDb) {
    $conn = New-SQLiteConnection -DataSource $datafile
    function Use-Query
    {
        param([string]$Query)
        Invoke-SqliteQuery -SQLiteConnection $conn -Query $Query
    }

    Write-Host "Tables available in this datafile:"
    $availTbls = Use-Query "PRAGMA STATS"
    $availTbls | Format-Table

    do {
        [string]$table = Read-Host -Prompt "Pick one (Enter name of the table)"
        $tableExists = $availTbls.table.Contains($table)
    } while (-not $tableExists)
    

}

$opt = Read-Host -Prompt "Preview the data table? (Y/N)"
if ($opt -eq 'Y') {
    $dataPreview = @()
    if ($isSqliteDb) {
        $dataPreview = Use-Query "SELECT * FROM $table LIMIT 3;"
    }
    elseif ($isCsv) {
        $dataPreview = $cvsDdata[1..3]
    }

    $dataPreview | Format-Table
}

$result = Read-ColumnNames
$col_name = $result[0]
$col_email = $result[1]

if ($isSqliteDb) {
    $names = Use-Query "SELECT $col_name FROM $table;"
    $emails = Use-Query "SELECT $col_email FROM $table;"
}
elseif ($isCsv) {
    $names = $cvsDdata.$col_name
    $emails = $cvsDdata.$col_email
}
# $conn.Shutdown()

# Prepare and send email message
[string]$Sender = Read-Host "Sender's email address"
[string]$Subject = Read-Host "Subject"

## Body (optional)
[string]$Body = Read-Host "Message (optional - write here or provide path to .TXT file)"
if (-not (Test-Path $Body) -and (-not ($Body.EndsWith(".txt")))) {
    Write-Warning "No message provided"
}
else {
    $Body = Get-Content $Body
}

$SMTPServer = "smtp.gmail.com"
[int]$SMTPPort = 587
$storedCredentials = Get-Credential

for ($i = 0; $i -lt $names.Length; $i++) {
    $nameString = $names[$i].name
    $emailAddress = $emails[$i].email
    $Receiver = "$nameString <$emailAddress>"
    $Body = $Body.Replace("<<Name>>", $nameString)   #TODO: Bug!

    Send-MailMessage -from $Sender -to $Receiver -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -UseSsl -Credential $storedCredentials
}
