# Project Rename Script
# Run this from the PARENT directory of 'Grocery POS'
# e.g. cd d:\GitHub
# .\grocery_pos\scripts\rename_project.ps1

$oldName = "Grocery POS"
$newName = "grocery_pos"
$scriptPath = $MyInvocation.MyCommand.Path
$parentDir = Split-Path (Split-Path $scriptPath -Parent) -Parent

Write-Host "Renaming '$oldName' to '$newName' in $parentDir..."

if (Test-Path "$parentDir\$newName") {
    Write-Error "Target directory '$newName' already exists!"
    exit 1
}

if (-not (Test-Path "$parentDir\$oldName")) {
    Write-Error "Source directory '$oldName' not found!"
    exit 1
}

# Attempt rename
try {
    Rename-Item -Path "$parentDir\$oldName" -NewName $newName -ErrorAction Stop
    Write-Host "Success! Project renamed to '$newName'."
    Write-Host "Please reopen your IDE/Terminal in the new directory."
}
catch {
    Write-Error "Rename failed: $_"
    Write-Host "Ensure no files are open in VS Code or other apps."
}
