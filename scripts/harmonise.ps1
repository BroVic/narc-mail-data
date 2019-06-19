# harmonise.ps1

## PowerShell script to launch harmonisation of spreadsheets

$numArgs = $args.Length
if ($($numArgs -gt 1))
{
  Write-Warning "$numArgs arguments were supplied but only the first was used"
}

$directory=$args[0]
if ($directory -ne $null) {
  $isValidPath = Test-Path -Path $directory
} else {
  Write-Host "Usage: ./harmonise.ps1 <path/to/dir>"
  exit
}

$srcfile = ".\scripts\harmonise.R"
$Rflags = "--vanilla"
$options = "--verbose"
if ($isValidPath)
{
  Rscript $options $Rflags $srcfile $directory
} else {
  Write-output "Path to directory '$directory' was not found"
  }
