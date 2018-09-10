# locate-media.ps1

# --------------------------------------------
## Locate media files on a specific computer,  
## obtain the metadata and store in a database
# --------------------------------------------

# Install PSSQLite if not already present:
# Install-Module PSSQLite -Scope CurrentUser
# More info: https://github.com/RamblingCookieMonster/PSSQLite/blob/master/README.md 

Import-Module PSSQLite

# Connect to database
# If table does not exist, create new one else continue
# Create Schema
$Database = "../data/NARC_TEST.db"
$dbCreated = Test-Path $Database
if(!$dbCreated) {
    $SQLQuery = "CREATE TABLE messages (
        ID INT PRIMARY KEY,
        title TEXT,
        minister TEXT,
        created DATETIME NOT NULL,
        modified DATETIME NOT NULL,
        accessed DATETIME NOT NULL,
        format TEXT NOT NULL,
        size INT NOT NULL,
        filename TEXT NOT NULL,
        location TEXT NOT NULL,
        computer TEXT NOT NULL,
        user TEXT
        )"

    Invoke-SqliteQuery -Query $SQLQuery -DataSource $Database
}


# Collect a list of file media files 
$pattern = "\.(wav|mp3|mp4|wma|wmv|midi)$"
$fileList = $(Get-ChildItem "..\tests" -Recurse -File) -match $pattern

if ($fileList -eq $null) {
    Write-Error "No media files were discovered"
}


foreach ($file in $fileList.FullName) 
{
    $props = Get-ItemProperty $file
    $SQLQuery = "INSERT INTO messages (
            created,
            modified,
            accessed,
            format,
            size,
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
            @filename,
            @location,
            @computer,
            @user)"   # TODO: Add values for 'ID'
    Invoke-SqliteQuery -DataSource $Database -Query $SQLQuery `
    -SqlParameters @{
        created = $props.CreationTime
        modified = $props.LastWriteTime
        accessed = $props.LastAccessTime
        format = $props.Extension
        size = $props.Length
        filename = $props.FullName
        location = $props.DirectoryName
        computer = $env:COMPUTERNAME
        user = $env:USERNAME
    }
}

# Display the state of the database after operation completes
Invoke-SqliteQuery -DataSource $Database -Query "SELECT * FROM messages LIMIT 6"

