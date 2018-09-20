﻿<# 
      locate-media.ps1

  Copyright (c) 2018 DevSolutions Ltd. All rights reserved.
  See LICENSE for details.

  --------------------------------------------
   Locate media files on a specific computer,  
   obtain the metadata and store in a database
  --------------------------------------------

  - Install PSSQLite if not already present, run 
       'Install-Module PSSQLite -Scope CurrentUser'

  - More info: 
  https://github.com/RamblingCookieMonster/PSSQLite/blob/master/README.md 
#>


# Collect a list of media files
[string]$srchRoot = Read-Host -Prompt "Enter search path"
if (-not $(Test-Path $srchRoot)) { 
    Write-Error "Path does not exist" 
}

$fileList = Get-ChildItem $srchRoot -Recurse -File
$fileList = $fileList -match "\.(wav|mp3|mp4|wma|wmv|midi|m4a)$"
$numFiles = $fileList.Count

if ($fileList -eq $null) {
    Write-Error "No media files were discovered"
}
else {
    Write-Output "Search completed. $numFiles files were found."
}

# Connect to database
# If table does not exist, create new one
Import-Module PSSQLite

[string]$Database = Read-Host -Prompt "Provide path to database"
$SQLQuery = "CREATE TABLE IF NOT EXISTS messages (
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
    Invoke-SqliteQuery -DataSource $Database -Query "PRAGMA table_info(messages)"
}

foreach ($file in $fileList.FullName) 
{
    if ($file.Contains("'")) {
        $newName = $file.Replace("'", "")
        Rename-Item -Path $file -NewName $newName -Force 
        $file = $newName
    }
    $props = Get-ItemProperty $file
    $SQLQuery = "INSERT INTO messages (
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
Invoke-SqliteQuery -DataSource $Database -Query "SELECT * FROM messages LIMIT 6"
