<#
  Run on any range host (locally, or via iwr + execute) to confirm its
  hostname, MAC, and IP after a rename/reboot. No parameters needed.
#>

Write-Host "=== $(hostname) ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "-- getmac --"
getmac
Write-Host ""
Write-Host "-- ipconfig --"
ipconfig | Select-String "IPv4 Address", "Subnet Mask", "Default Gateway"
