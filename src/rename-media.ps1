# rename-media.ps1

# Copyright (c) 2018 DevSolutions Ltd. All rights reserved.

# ------------------------------------------------------------
# Powershell script for reviewing, identifying and 
# relabelling audio and video nedia files in a database
# ------------------------------------------------------------

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


# Fetch a record
$DB = "..\data\NARC_TEST.db"
$query = "SELECT DISTINCT ID, location FROM messages WHERE title IS NULL"
$idBased = Invoke-SqliteQuery -DataSource $DB -Query $query

$query = "SELECT DISTINCT location FROM messages WHERE title IS NULL"
$locBased = Invoke-SqliteQuery -DataSource $DB -Query $query
$mediaFolder = $locBased.location

Add-Type -AssemblyName presentationCore
$mediaPlayer = New-Object System.Windows.Media.MediaPlayer

$query = "SELECT filename FROM messages WHERE location = '$mediaFolder'"
[array]$allFiles = Invoke-SqliteQuery -DataSource $DB -Query $query

# Review the files in the given folder
foreach ($file in $allFiles)
{
    # First get the unique identifier of this particular file
    $file = $file.filename
    $query = "SELECT ID FROM messages WHERE filename = '$file'"
    [long]$ID = $(Invoke-SqliteQuery -DataSource $DB -Query $query).ID
    $mediaPlayer.Open("$file")
    [string]$ans = Read-Host -Prompt "You are about to play the file '$file'. Continue? (Y/N)"
    if ($ans -eq 'Y')
    {
        $mediaPlayer.Play()
        $ans = Read-Host -Prompt "You are currently listening to '$file'. To stop play, type 'q'"
        if ($ans -eq 'q')
        {
            $mediaPlayer.Stop()
            $ans = Read-Host -Prompt "Record a new title for this media file? (Y/N)"
            if ($ans -eq 'Y') 
            {
                # Edit file attribute
                [string]$newTitle = Read-Host -Prompt "Enter a new 'title' for this file (without quotes)"
                $query = "UPDATE messages SET title = '$newTitle' WHERE ID = $ID"
                Invoke-SqliteQuery -DataSource $DB -Query $query
                $(Invoke-SqliteQuery -DataSource $DB -Query "SELECT * FROM messages WHERE ID = $ID")[0]
               
            }
            if ($(Read-Host -Prompt "Listen to another file? (Y/N)") -eq 'N') { break }
        }
    }
}


# References: 
# 1. http://eddiejackson.net/wp/?p=9268
# 2. http://ramblingcookiemonster.github.io/SQLite-and-PowerShell/
