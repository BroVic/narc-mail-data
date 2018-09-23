<#
.SYNOPSIS   
Locate media files on a specific computer, 
obtain the metadata and store in a database
.DESCRIPTION
Will search a given directory tree for media files - both audio
and video. The file formats that are searched for include 
wav, mp3, mp4, wma, wmv, midi and m4a. When found, the list of
files, as well as file attributes are stored in an SQLite 
database (user will be prompted for the path of the database). 
If the database is not pre-existing, then it will be created.
Again, the user is prompted to provide the name of the database
table where the data are stored.
.NOTES
Copyright (c) 2018 DevSolutions Ltd. All rights reserved.
See LICENSE for details.
.LINK
https://github.com/RamblingCookieMonster/PSSQLite/blob/master/README.md 
#>

# TODO: Installation of SQLite
# Check if installed
$progPaths = $env:ProgramData, $env:ProgramFiles, ${env:ProgramFiles(x86), $env:SystemDrive }
$sqliteInstalled = Get-ChildItem $progPaths `
| Where-Object { $_.Name.Contains("sqlite") }
if(-not $sqliteInstalled) {
    # Download binaries
    # Install binaries
    # Confirm
} 

# Installation of PSSQLite Module
# TODO: Review module checking
if (-not (Get-Module -ListAvailable | Where-Object { $_.Name -eq "PSSQLite" } )) {
    $ver = $PSVersionTable.PSVersion.Major
    if (($ver -lt 5) -and ($ver -ge 3)) {
        $url = 'https://github.com/RamblingCookieMonster/PSSQLite/zipball/master'
        $sqlZip = Join-Path -Path $HOME -ChildPath "Downloads/PSSQLite.zip"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $sqlZip -Verbose
        # TODO: Optionally use .NET:
        # (New-Object System.Net.WebClient).DownloadFile($url, $sqlZip)
        
        # Unzip to Module directory
        $userModPath = $env:PSModulePath.split(';') `
        | Where-Object { $_.Contains("Documents") }
        $shell = New-Object -com shell.application
		$zipped = $shell.NameSpace($sqlZip)
		foreach($item in $zipped.items())
		{
			$shell.NameSpace($userModPath).copyhere($item)
		}
    }
    elseif ($ver -ge 5) {
        Install-Module PSSQLite -Scope CurrentUser -Verbose
    }
    else {
        Write-Output "Automated installation of PSSQLite Module not implemented for PS version lower than 3.0"
    }
}
Import-Module PSSQLite -Verbose

# Collect a list of media files
[string]$srchRoot = Read-Host -Prompt "Enter search path of root directory"
if (-not $(Test-Path $srchRoot)) { 
    Write-Error "Path does not exist" 
}

$fileList = Get-ChildItem $srchRoot -Recurse -File
$fileList = $fileList -match "\.(wav|mp3|mp4|wma|wmv|midi|m4a)$" 
if ($null -eq $fileList) {
    Write-Error "No media files were discovered"
}
else {
    Write-Output "Search completed.`n$fileList.Count files were found."
}

# Connect to database
# If table does not exist, create new one
[string]$Database = Read-Host -Prompt "Provide path to new/existing database"
[string]$table = Read-Host -Prompt "Enter the name of the table"
$SQLQuery = "CREATE TABLE IF NOT EXISTS $table (
    ID INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT,
    minister TEXT,
    created DATETIME NOT NULL,
    modified DATETIME NOT NULL,
    accessed DATETIME NOT NULL,
    format TEXT NOT NULL,
    size INTEGER NOT NULL,
    filepath TEXT NOT NULL,
    filename TEXT NOT NULL,
    location TEXT NOT NULL,
    computer TEXT NOT NULL,
    user TEXT
    )"

Invoke-SqliteQuery -Query $SQLQuery -DataSource $Database

function Get-Opt
{
    $opt = Read-Host -Prompt "View the resulting schema? (Y/N)"
    switch ($opt)
    {
        Y { $choice = "Y" }
        N { $choice = "N" }
    }
    return $choice
}

 
if (Get-Opt -eq 'Y') {
    Invoke-SqliteQuery -DataSource $Database -Query "PRAGMA table_info($table)"
}

foreach ($file in $fileList.FullName) 
{
    # Remove apostrophe's from any of the paths
    if ($file.Contains("'")) {
        $newName = $file.Replace("'", "")
        Rename-Item -Path $file -NewName $newName -Force 
        $file = $newName
    }

    $props = Get-ItemProperty $file
    $SQLQuery = "INSERT INTO $table (
                     created,
                     modified,
                     accessed,
                     format,
                     size,
                     filepath,
                     filename,
                     location,
                     computer,
                     user)
                 VALUES (
                     @created,
                     @modified,
                     @accessed,
                     @format,
                     @size,
                     @filepath,
                     @filename,
                     @location,
                     @computer,
                     @user)" 
    Invoke-SqliteQuery -DataSource $Database -Query $SQLQuery `
    -SqlParameters @{
                     created = $props.CreationTime
                     modified = $props.LastWriteTime
                     accessed = $props.LastAccessTime
                     format = $props.Extension
                     size = $props.Length
                     filepath = $props.FullName
                     filename = $props.Name
                     location = $props.DirectoryName
                     computer = $env:COMPUTERNAME
                     user = $env:USERNAME
                    }
}

# Display the state of the database after operation completes
Invoke-SqliteQuery -DataSource $Database -Query "SELECT * FROM $table LIMIT 6"
