# rename-media.ps1
# Companion script to 'locate-media.ps1'

# Copyright (c) 2018 DevSolutions Ltd. All rights reserved.
# See LICENSE for details.

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

# Create an SQLite connection
$Conn = New-SQLiteConnection -DataSource ".\data\media.db"

# Fetch a record of files without titles
$query = "SELECT filepath FROM messages WHERE title IS NULL"
[array]$arrFiles = Invoke-SqliteQuery -SQLiteConnection $Conn -Query $query

Add-Type -AssemblyName presentationCore
$mediaPlayer = New-Object System.Windows.Media.MediaPlayer

# Review the files in the given folder
foreach ($file in $arrFiles.filepath)
{    
    # Get the unique identifier of this particular file
    $query = "SELECT ID FROM messages WHERE filepath = '$file'"
    [long]$ID = $(Invoke-SqliteQuery -SQLiteConnection $Conn -Query $query).ID

    $filename = Split-Path $file -Leaf
    [string]$ans = Read-Host -Prompt "`nYou are about to play this file: '$filename'.`nContinue? (Y/N)"
    if ($ans -eq 'Y')
    {
        $mediaPlayer.Open("$file")
        $mediaPlayer.Play()
        $ans = Read-Host -Prompt "Now Playing - '$filename'.`nTo stop playback, type 'q'"
        if ($ans -eq 'q')
        {
            $mediaPlayer.Stop()
            $ans = Read-Host -Prompt "Record a new title for this media file? (Y/N)"
            if ($ans -eq 'Y') 
            {
                # Edit file attribute
                [string]$newTitle = Read-Host -Prompt "Enter a new 'title' field for this file (without quotes)"
                $query = "UPDATE messages SET title = '$newTitle' WHERE ID = $ID"
                Invoke-SqliteQuery -SQLiteConnection $Conn -Query $query

                ## TODO: Add option for updating record for 'minister'

                # View some selected current attributes
                Write-Host "Status:`n" -ForegroundColor Yellow
                $query = "SELECT title, minister, filename, location FROM messages WHERE ID = $ID"
                Invoke-SqliteQuery -SQLiteConnection $Conn -Query $query
            }
            $ans = Read-Host -Prompt "Listen to another file? (Y/N)"
            if ($ans -eq 'N') {
                $mediaPlayer.Close()
                break
            }
        }
        $mediaPlayer.Close()
    }
    
}


# References: 
# 1. http://eddiejackson.net/wp/?p=9268
# 2. http://ramblingcookiemonster.github.io/SQLite-and-PowerShell/
