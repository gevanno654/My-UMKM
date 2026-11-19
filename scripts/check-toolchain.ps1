# Toolchain check for POS Warung monorepo.
# Usage: powershell -ExecutionPolicy Bypass -File scripts/check-toolchain.ps1
$ErrorActionPreference = "Stop"

$flutterBin = "C:\Users\Gevanno\dev\flutter\bin\flutter.bat"
Write-Host "--- flutter ---"
& $flutterBin --version | Select-Object -First 4
Write-Host "--- node ---"
node --version
Write-Host "--- postgres service ---"
Get-Service postgresql-x64-18 | Select-Object Name, Status
Write-Host "TOOLCHAIN OK"
