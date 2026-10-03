# Original to this range (no direct CyberHawks source file — the same
# "plaintext creds on an open SMB share" idea CyberHawks' own
# smb_file_dump/build_file_dump.ps1 and ad_misc_findings/netlogon_script.ps1
# use elsewhere, adapted here as a small dc1-local finding). See
# ../../../UPSTREAM.md.
$ErrorActionPreference = "Stop"

$shareName = $env:LEAK_SHARE_NAME
$sharePath = $env:LEAK_SHARE_PATH
$leakUsername = $env:LEAK_USERNAME
$leakPassword = $env:LEAK_PASSWORD
if (-not $shareName -or -not $sharePath -or -not $leakUsername -or -not $leakPassword) {
    throw "LEAK_SHARE_NAME/LEAK_SHARE_PATH/LEAK_USERNAME/LEAK_PASSWORD environment variables not set"
}

if (-not (Test-Path $sharePath)) {
    New-Item -Path $sharePath -ItemType Directory -Force | Out-Null
}

# A handful of benign filler files so the real leak isn't the only thing on
# the share (same "don't make it too obvious" idea as the file-dump shares).
$fillerNames = @("HelpdeskProcedures.docx", "OnCallRoster.xlsx", "TicketQueue_Export.csv")
foreach ($name in $fillerNames) {
    $path = Join-Path $sharePath $name
    if (-not (Test-Path $path)) { Set-Content -Path $path -Value "" -NoNewline }
}

$leakFile = Join-Path $sharePath "ResetLog_2026.txt"
$desiredContent = @"
IT Password Reset Log

Date: 2026-03-14
User: $leakUsername
Reason: forgot password, verified over phone
Temp password set: $leakPassword
Ticket: IT-4471
"@
if (-not (Test-Path $leakFile) -or (Get-Content $leakFile -Raw).Trim() -ne $desiredContent.Trim()) {
    Set-Content -Path $leakFile -Value $desiredContent
    Write-Output "Created/updated the leaked credential file"
} else {
    Write-Output "Leaked credential file already up to date"
}

if (-not (Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name $shareName -Path $sharePath -FullAccess "Everyone" | Out-Null
    Write-Output "Created SMB share \\$env:COMPUTERNAME\$shareName"
} else {
    Write-Output "SMB share $shareName already exists"
}

Write-Output "DONE"
