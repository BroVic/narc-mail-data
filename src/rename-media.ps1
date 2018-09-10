# rename-media.ps1

# ------------------------------------------------------------
# Powershell script for reviewing, identifying and relabelling
# audio and video nedia files
# ------------------------------------------------------------

# Load module(s)
Import-Module MusicPlayer
Import-Module PSSQLite

# Open the database
$DB = ".\data\NARC_media.db"

# Fetch a record
Invoke-SqliteQuery -DataSource $DB -Query "SELECT ID, filename FROM messages WHERE title IS NULL"

# Get a file path
# Open the file
# Use the file
  # Play the file
# Close the file
# Edit attribute
bi