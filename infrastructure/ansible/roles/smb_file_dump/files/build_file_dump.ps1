# Adapted from CyberHawks `cyber-range` roles/smb_file_dump/files/
# build_file_dump.ps1 (98307cc), owner permission 2026-10-03 — see
# ../../../UPSTREAM.md. Changes: share name/path templated via env vars
# (runs against web AND workstation here, not just one sql host); the
# credential-leak file is now optional (INCLUDE_CRED_LEAK) since, in this
# range's Stage 2 map, the SMB-credential-exposure finding applies to
# dc1+workstation, while plain SMB share enumeration/dumps applies to
# web+workstation — workstation gets both, web gets the dump only.
$ErrorActionPreference = "Stop"

$shareName = $env:DUMP_SHARE_NAME
$root = $env:DUMP_SHARE_PATH
$includeCredLeak = $env:INCLUDE_CRED_LEAK -eq "true"
if (-not $shareName -or -not $root) { throw "DUMP_SHARE_NAME/DUMP_SHARE_PATH environment variables not set" }
if ($includeCredLeak -and (-not $env:LEAK_USERNAME -or -not $env:LEAK_PASSWORD)) {
    throw "INCLUDE_CRED_LEAK=true but LEAK_USERNAME/LEAK_PASSWORD not set"
}

# --- Folder tree ---
$topFolders = @{
    "HR"          = @("Onboarding", "Policies", "Reviews", "Payroll")
    "IT"          = @("PasswordResets", "Tickets", "Inventory", "Backups", "Scripts")
    "Finance"     = @("Invoices", "Budgets", "Audits", "Expenses")
    "GuestServices" = @("Tickets", "Feedback", "Reports")
    "Maintenance" = @("WorkOrders", "Inspections", "Vendors")
    "Scans"       = @()
    "Archive"     = @("Old Stuff", "2019 Backup", "Misc", "Do Not Delete")
}
$userNames = @("r.coaster", "g.usher", "c.churro", "w.wrench", "a.finance", "i.tanaka",
    "jsmith", "mjohnson", "rwilliams", "abrown", "kjones", "tgarcia", "lmiller")

$allFolders = New-Object System.Collections.Generic.List[string]
foreach ($top in $topFolders.Keys) {
    $allFolders.Add($top)
    foreach ($sub in $topFolders[$top]) {
        $allFolders.Add("$top\$sub")
    }
}
foreach ($u in $userNames) {
    $allFolders.Add("Users\$u")
}

foreach ($f in $allFolders) {
    $path = Join-Path $root $f
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}
Write-Output "Created $($allFolders.Count) folders"

# --- Filler files: realistic names, mostly-empty content ---
$fileTypePrefixes = @{
    ".docx" = @("Memo", "Letter", "Report", "Minutes", "Summary", "Proposal", "Policy")
    ".xlsx" = @("Budget", "Tracker", "Inventory", "Timesheet", "Expenses", "Forecast")
    ".pdf"  = @("Invoice", "Scan", "Signed_Form", "Contract", "Receipt", "Statement")
    ".txt"  = @("notes", "readme", "todo", "log", "export")
    ".pptx" = @("Presentation", "Overview", "Training", "Kickoff")
}
$years = @("2022", "2023", "2024", "2025", "2026")

$rng = New-Object System.Random
$totalFiles = 0
foreach ($f in $allFolders) {
    $path = Join-Path $root $f
    $count = $rng.Next(3, 9)
    for ($i = 0; $i -lt $count; $i++) {
        $ext = (Get-Random -InputObject $fileTypePrefixes.Keys)
        $prefix = Get-Random -InputObject $fileTypePrefixes[$ext]
        $year = Get-Random -InputObject $years
        $num = $rng.Next(100, 999)
        $fileName = "${prefix}_${year}_${num}${ext}"
        $filePath = Join-Path $path $fileName
        if (-not (Test-Path $filePath)) {
            Set-Content -Path $filePath -Value "" -NoNewline
            $totalFiles++
        }
    }
}
Write-Output "Created $totalFiles filler files"

# --- Optional: a plaintext password buried in IT\PasswordResets ---
if ($includeCredLeak) {
    $leakFile = Join-Path $root "IT\PasswordResets\ResetLog_2026.txt"
    $desiredContent = @"
IT Password Reset Log

Date: 2026-03-14
User: $env:LEAK_USERNAME
Reason: forgot password, verified over phone
Temp password set: $env:LEAK_PASSWORD
Ticket: IT-4471
"@
    if (-not (Test-Path $leakFile) -or (Get-Content $leakFile -Raw).Trim() -ne $desiredContent.Trim()) {
        Set-Content -Path $leakFile -Value $desiredContent
        Write-Output "Created the leaked credential file"
    }
}

# --- Share it ---
if (-not (Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue)) {
    New-SmbShare -Name $shareName -Path $root -FullAccess "Everyone" | Out-Null
    Write-Output "Created SMB share \\$env:COMPUTERNAME\$shareName"
} else {
    Write-Output "SMB share $shareName already exists"
}

Write-Output "DONE"
