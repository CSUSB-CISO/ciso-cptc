# Adapted from CyberHawks `cyber-range` roles/ad_misc_findings/files/gpp_password.ps1
# (98307cc), owner permission 2026-10-03 — see ../../../UPSTREAM.md. Changes:
# domain/OU/GPO names templated to this range's env vars instead of being
# hardcoded to cyberhawks.lab; local account name re-themed.
$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory
Import-Module GroupPolicy

$domainDnsName = $env:GPP_DOMAIN_DNS_NAME
$domainDn = $env:GPP_DOMAIN_DN
$ouDN = $env:GPP_TARGET_OU_DN
$gpoName = $env:GPP_GPO_NAME
$localAccountName = $env:GPP_LOCAL_ACCOUNT_NAME
$gppPassword = $env:GPP_PASSWORD
if (-not $domainDnsName -or -not $domainDn -or -not $ouDN -or -not $gpoName -or -not $localAccountName -or -not $gppPassword) {
    throw "GPP_DOMAIN_DNS_NAME/GPP_DOMAIN_DN/GPP_TARGET_OU_DN/GPP_GPO_NAME/GPP_LOCAL_ACCOUNT_NAME/GPP_PASSWORD environment variables not set"
}

function ConvertTo-GppCpassword {
    param([string]$Password)
    # The well-known, publicly-documented Microsoft GPP AES key -- this is
    # what makes GPP cpassword values trivially reversible by design.
    $key = [byte[]](0x4e, 0x99, 0x06, 0xe8, 0xfc, 0xb6, 0x6c, 0xc9, 0xfa, 0xf4, 0x93, 0x10, 0x62, 0x0f, 0xfe, 0xe8,
        0xf4, 0x96, 0xe8, 0x06, 0xcc, 0x05, 0x79, 0x90, 0x20, 0x9b, 0x09, 0xa4, 0x33, 0xb6, 0x6c, 0x1b)
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV = New-Object byte[] 16
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $encryptor = $aes.CreateEncryptor()
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($Password)
    $encrypted = $encryptor.TransformFinalBlock($bytes, 0, $bytes.Length)
    # GPP cpassword uses base64url, not standard base64: '+' -> '-', '/' -> '_', no padding.
    return [Convert]::ToBase64String($encrypted).TrimEnd("=").Replace("+", "-").Replace("/", "_")
}

# --- Create the GPO and write the GPP Local Users and Groups preference ---
$gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
if (-not $gpo) {
    $gpo = New-GPO -Name $gpoName
    Write-Output "Created GPO $gpoName"
}
$gpoGuid = $gpo.Id.ToString("B").ToUpper()
$sysvolPath = "\\$domainDnsName\SYSVOL\$domainDnsName\Policies\$gpoGuid\Machine\Preferences\Groups"
if (-not (Test-Path $sysvolPath)) {
    New-Item -Path $sysvolPath -ItemType Directory -Force | Out-Null
}

$cpassword = ConvertTo-GppCpassword -Password $gppPassword
$changed = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$groupsXmlPath = "$sysvolPath\Groups.xml"

# Creating a brand-new local account (action="C") instead of updating the
# built-in Administrator avoids well-known-RID-500 targeting ambiguity and
# demonstrates the exact same cpassword vulnerability just as validly (see
# upstream script's comment for the empirical reason this was chosen).
$groupsXml = @"
<?xml version="1.0" encoding="utf-8"?>
<Groups clsid="{3125E937-EB16-4b4c-9934-544FC6D24D26}"><User clsid="{DF5F1855-51E5-4d24-8B1A-D9BDE98BA1D1}" name="$localAccountName" image="2" changed="$changed" uid="{$([Guid]::NewGuid().ToString().ToUpper())}"><Properties action="C" newName="" fullName="Help Desk Service" description="Local account for help desk tooling" cpassword="$cpassword" changeLogon="0" noChange="0" neverExpires="1" acctDisabled="0" userName="$localAccountName"/></User></Groups>
"@
if (-not (Test-Path $groupsXmlPath) -or (Get-Content $groupsXmlPath -Raw) -ne $groupsXml) {
    Set-Content -Path $groupsXmlPath -Value $groupsXml
    Write-Output "Wrote GPP Groups.xml with encrypted cpassword"
} else {
    Write-Output "GPP Groups.xml already up to date"
}

# Register the GPP client-side extension so Group Policy actually processes
# Preferences (a GPO with no extensions declared gets ignored even if the
# XML files exist).
$gpoDN = "CN=$gpoGuid,CN=Policies,CN=System,$domainDn"
$extNames = "[{17D89FEC-5C44-4972-B12D-241CAEF74509}{79F92669-4224-476C-9C5C-6EFB4D87DF4A}]"
$currentExt = (Get-ADObject -Identity $gpoDN -Properties gPCMachineExtensionNames).gPCMachineExtensionNames
if ($currentExt -ne $extNames) {
    Set-ADObject -Identity $gpoDN -Replace @{ gPCMachineExtensionNames = $extNames }
    Write-Output "Registered GPP client-side extension on the GPO"
} else {
    Write-Output "GPP client-side extension already registered"
}

# The client also gates on versionNumber (packed Machine/User version
# halves) matching gpt.ini's Version= -- both default to 0 since SYSVOL
# content was written directly rather than through GPMC's settings APIs.
$newVersion = ([int](Get-ADObject -Identity $gpoDN -Properties versionNumber).versionNumber) + 1
$gptIniPath = "\\$domainDnsName\SYSVOL\$domainDnsName\Policies\$gpoGuid\GPT.INI"
$desiredGptIni = "[General]`r`nVersion=$newVersion"
if (-not (Test-Path $gptIniPath) -or (Get-Content $gptIniPath -Raw) -ne $desiredGptIni) {
    Set-ADObject -Identity $gpoDN -Replace @{ versionNumber = $newVersion }
    Set-Content -Path $gptIniPath -Value $desiredGptIni
    Write-Output "Bumped GPO version so the client recognizes it has real content"
} else {
    Write-Output "GPO version already current"
}

# --- Link the GPO to the target OU ---
$existingLink = Get-GPInheritance -Target $ouDN
if (-not ($existingLink.GpoLinks | Where-Object { $_.DisplayName -eq $gpoName })) {
    New-GPLink -Name $gpoName -Target $ouDN | Out-Null
    Write-Output "Linked $gpoName to target OU"
} else {
    Write-Output "$gpoName already linked to target OU"
}

Write-Output "DONE"
