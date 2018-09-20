# rename-media.ps1
# Companion script to 'locate-media.ps1'

# Copyright (c) 2018 DevSolutions Ltd. All rights reserved.
# See LICENSE for details.

# ------------------------------------------------------------
# Powershell script for reviewing, identifying and 
# relabelling audio and video nedia files in a database
# ------------------------------------------------------------

# Installation of PSSQLite Module (when necessary)
$modLoc = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
if (-not ($(Get-Childitem $modLoc).Name.Contains("PSSQLite"))) {
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $url = 'https://github.com/RamblingCookieMonster/PSSQLite.git'
        # Invoke-Expression $(New-Object System.Net.WebClient).DownloadString($url)
    }
    else {
        Install-Module PSSQLite -Scope CurrentUser
    }
}
Import-Module PSSQLite

# Custom function for editing records in the database
function Edit-Record
{
    param(
        [string]$Field,
        [int]$UniqueId,
        $Connection
        )
    $prompt = "Enter a new '$Field' field for this file or type '-j' to skip"
    [string]$newField = Read-Host -Prompt $prompt
    if ($newField -ne '-j') {
        $stmnt = "UPDATE messages SET title = '$newField' WHERE ID = $ID"
        Invoke-SqliteQuery -SQLiteConnection $Connection -Query $stmnt
    }
    else { Write-Host "'$Field' was skipped`n" }
}

# Create an SQLite connection
$Conn = New-SQLiteConnection -DataSource ".\data\media.db"

# Fetch a record of files without titles
$query = "SELECT filepath FROM messages WHERE title IS NULL"

[array]$arrFiles = Invoke-SqliteQuery -SQLiteConnection $Conn -Query $query
$numFiles = $arrFiles.Count
Read-Host -Prompt "`n$numFiles records are avaiable for editing. Press ENTER to continue"

Add-Type -AssemblyName presentationCore
$mediaPlayer = New-Object System.Windows.Media.MediaPlayer

# Loop through the list of files, playing them one after the other
# and making any relevant edits to the records in the database
foreach ($file in $arrFiles.filepath)
{    
    # Get the unique identifier of this particular file
    $query = "SELECT ID FROM messages WHERE filepath = '$file'"
    [long]$ID = $(Invoke-SqliteQuery -SQLiteConnection $Conn -Query $query).ID

    $mediaPlayer.Open("$file")
    $mediaPlayer.Play()

    $filename = Split-Path $file -Leaf
    [string]$ans = Read-Host -Prompt "`nNow Playing - '$filename'.`nTo stop playback, type 'q'"
    if ($ans -eq 'q')
    {
        $mediaPlayer.Stop()
        $ans = Read-Host -Prompt "Edit the record for this media file? (Y/N)"
        if ($ans -eq 'Y') 
        {
            Edit-Record -Field "title" -UniqueId $ID -Connection $Conn
            Edit-Record -Field "minister" -UniqueId $ID -Connection $Conn

            # View selected fields
            Write-Host "Status:`n" -ForegroundColor Yellow
            $query = "SELECT title, minister, filename FROM messages WHERE ID = $ID"
            Invoke-SqliteQuery -SQLiteConnection $Conn -Query $query
        }
        $ans = Read-Host -Prompt "Listen to another file? (Y/N)"
        if ($ans -eq 'N') { break}
    }
 }
$mediaPlayer.Close()

# References: 
# 1. http://eddiejackson.net/wp/?p=9268
# 2. http://ramblingcookiemonster.github.io/SQLite-and-PowerShell/
