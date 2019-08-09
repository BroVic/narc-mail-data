# Send an email from within Powershell

#####################        IMPORTANT NOTICE!            #######################
##                              09 Aug 2019                                    ##
##                                                                             ##
##    To use this script with Gmail, go to Google Account settings at          ##
##    https://myaccount.google.com/u/1/security and enable "Less Secure Apps". ##
##                                                                             ##                                                                             ##
#################################################################################

# Retrieve data from the database
Import-Module PSSQLite

[string]$Database = Read-Host -Prompt "Enter path to the database"
$conn = New-SQLiteConnection -DataSource $Database

Write-Host "Tables available in this database"
Invoke-SqliteQuery -SQLiteConnection $conn -Query "PRAGMA STATS"

[string]$table = Read-Host -Prompt "Pick one (Enter name of the table)"
[string]$nameCol = Read-Host -Prompt "Column with recipients' names"
[string]$emailCol = Read-Host -Prompt "Column with recipients' email addresses"
[array]$names = Invoke-SqliteQuery -SQLiteConnection $conn -Query "SELECT name FROM $table;"
[array]$emails = Invoke-SqliteQuery -SQLiteConnection $conn -Query "SELECT email FROM $table;"

# $conn.Shutdown()

# Email proper
$Sender = "Victor Ordu <victorordu@gmail.com>"
$Subject = "Test Email from Powershell"
$SMTPServer = "smtp.gmail.com"
[int]$SMTPPort = 587

$storedCredentials = Get-Credential

for ($i = 0; $i -lt $names.Length; $i++) {

    $nameString = $names[$i].name
    $emailAddress = $emails[$i].email
    $Receiver = "$nameString <$emailAddress>"
    $Body = "This mail is addressed to $nameString"

    Send-MailMessage -from $Sender -to $Receiver -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -UseSsl -Credential $storedCredentials
}
