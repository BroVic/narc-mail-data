# harmonise.ps1

## Script to launch harmonisation of spreadsheets
$directory=$args[0]
$numArgs = $args.Length
$srcfile = ".\src\harmonise.R"
$flags = "--vanilla"
$options = "--verbose"

if ($($numArgs -gt 1))
{
  Write-Warning "$numArgs arguments were supplied but only the first was used"
}

if ($directory -ne $null) {
  $isValidPath = Test-Path -Path $directory
} else {
  Write-Host "Usage: harmonise.ps1 <path/to/dir>"
  exit
}


if ($isValidPath)
{
  Rscript $options $flags $srcfile $directory
} else {
  Write-output "Path to directory '$directory' was not found"
  }