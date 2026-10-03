$ErrorActionPreference = "Stop"

# Adapted (trimmed to 1 template) from CyberHawks cyber-range
# roles/adcs_esc_templates/files/publish_templates.ps1 (98307cc), owner
# permission 2026-10-03 -- see ../../../UPSTREAM.md.
#
# certutil -CATemplates / -SetCATemplates talk live to the running CertSvc
# process via RPC (ICertAdmin2), unlike -setreg which just writes the
# registry directly. That RPC call can fail under an NTLM-authenticated
# WinRM session with ERROR_NOT_AUTHENTICATED (0x800704dc) -- same double-hop
# workaround as the rest of this build: run via a scheduled task under real
# password auth.

$adminPassword = $env:ADMIN_PASSWORD
$templateName = $env:ESC1_TEMPLATE_NAME
if (-not $adminPassword) { throw "ADMIN_PASSWORD environment variable not set" }
if (-not $templateName) { throw "ESC1_TEMPLATE_NAME environment variable not set" }

$innerScript = @"
`$ErrorActionPreference = "Stop"
`$resultPath = "C:\Windows\Temp\adcs_publish_result.txt"
try {
    `$currentRaw = certutil -CATemplates
    if (`$LASTEXITCODE -ne 0) { throw "certutil -CATemplates failed with exit code `$LASTEXITCODE : `$currentRaw" }
    `$current = (`$currentRaw | Where-Object { `$_ -match ':' } | ForEach-Object { (`$_ -split ':')[0].Trim() })
    if (`$current -contains "$templateName") {
        "$templateName already published" | Out-File -FilePath `$resultPath
    } else {
        certutil -SetCATemplates "+$templateName" | Out-Null
        if (`$LASTEXITCODE -ne 0) { throw "certutil -SetCATemplates +$templateName failed with exit code `$LASTEXITCODE" }
        "Published $templateName" | Out-File -FilePath `$resultPath
    }
} catch {
    "ERROR: `$(`$_.Exception.Message)" | Out-File -FilePath `$resultPath
}
"@

$taskName = "AdcsPublish_$(Get-Random)"
$scriptPath = "C:\Windows\Temp\adcs_publish_task_script.ps1"
$resultPath = "C:\Windows\Temp\adcs_publish_result.txt"

Remove-Item -Path $resultPath -Force -ErrorAction SilentlyContinue
Set-Content -Path $scriptPath -Value $innerScript

schtasks /Create /TN $taskName /TR "powershell.exe -ExecutionPolicy Bypass -File $scriptPath" /SC ONCE /ST 00:00 /RU "Administrator" /RP $adminPassword /RL HIGHEST /F | Out-Null
schtasks /Run /TN $taskName | Out-Null

$maxWait = 60
$waited = 0
while (-not (Test-Path $resultPath) -and $waited -lt $maxWait) {
    Start-Sleep -Seconds 2
    $waited += 2
}

schtasks /Delete /TN $taskName /F | Out-Null
Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue

if (-not (Test-Path $resultPath)) {
    throw "Scheduled task did not complete within $maxWait seconds"
}

$output = Get-Content $resultPath
Remove-Item -Path $resultPath -Force -ErrorAction SilentlyContinue
$output | Write-Output
if ($output -match "^ERROR:") {
    throw "Template publish task reported an error (see output above)"
}
