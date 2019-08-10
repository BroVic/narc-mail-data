# install-pssqlite.ps1

# Copyright (c) 2018 DevSolutions Ltd. All rights reserved.
# See LICENSE for details.

Write-Verbose "Checking for avaiablity of PSSQLite Module"

# Check if SQLite is (properly) installed
if(-not $ENV:Path.Contains('sqlite')) {
    Write-Error "'sqlite3' does not exist or is not on system PATH."
} 

# Install PSSQLite Module (if necessary)
if (-not (Get-Module -ListAvailable | Where-Object { $_.Name -eq "PSSQLite" } )) {
    $ver = $PSVersionTable.PSVersion.Major
    if (($ver -lt 5) -and ($ver -ge 3)) {
        Add-Type -AssemblyName System.IO.Compression.Filesystem -ErrorAction Stop

        # Download the archive
        $url = 'https://github.com/RamblingCookieMonster/PSSQLite/zipball/master'
        $dwnDir = "$home/Downloads"
        if (-not (Test-Path $dwnDir)) {
            New-Item -ItemType Directory $dwnDir
        }
        $sqlZip = Join-Path -Path $dwnDir -ChildPath "PSSQLite.zip"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Verbose "Downloading the PSSQLite Module... "
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
    elseif ($ver -ge 5) {
        Install-Module PSSQLite -Scope CurrentUser
    }
    else {
        Write-Output "Automated installation not enabled for versions lower than 3.0"
    }
}