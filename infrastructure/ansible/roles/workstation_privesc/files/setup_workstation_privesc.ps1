# Adapted (substantially trimmed) from CyberHawks `cyber-range`
# roles/workstation_privesc/files/setup_workstation_privesc.ps1 (98307cc),
# owner permission 2026-10-03 — see ../../../UPSTREAM.md.
#
# The upstream script builds an elaborate multi-phase privesc chain (RDP/
# WinRM grants for a low-priv user, SeImpersonatePrivilege, forced profile
# creation, PSReadLine history credential planting, AlwaysInstallElevated,
# autologon creds, four custom services each demonstrating a distinct
# service-abuse primitive, plus a writable SYSTEM scheduled task). This
# range's Stage 2 map asks for one "straightforward" finding only ("weak
# service permissions, unquoted service path, or writable PATH dir"), so
# only those three primitives are ported — the RDP/WinRM/profile-forcing/
# AlwaysInstallElevated/autologon/scheduled-task material is intentionally
# NOT carried over (out of scope for Stage 2; would also duplicate/overlap
# other listed findings).
#Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$TargetGroup   = $env:PRIVESC_TARGET_GROUP          # e.g. "THELARPERS\Domain Users"
$TargetSid     = $env:PRIVESC_TARGET_SID
$CscExe        = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not $TargetGroup -or -not $TargetSid) { throw "PRIVESC_TARGET_GROUP/PRIVESC_TARGET_SID environment variables not set" }

function Write-Step($msg) { Write-Host "=== $msg ===" }

$csTemplate = @'
using System;
using System.IO;
using System.ServiceProcess;

namespace LarpersSvc
{
    public class Svc : ServiceBase
    {
        public Svc() { ServiceName = "__SVCNAME__"; }

        protected override void OnStart(string[] args)
        {
            string log = @"__LOGPATH__";
            File.AppendAllText(log, DateTime.Now + " - started" + Environment.NewLine);
        }

        protected override void OnStop()
        {
            string log = @"__LOGPATH__";
            File.AppendAllText(log, DateTime.Now + " - stopped" + Environment.NewLine);
        }

        static void Main() { ServiceBase.Run(new Svc()); }
    }
}
'@

function New-LarpersService {
    param(
        [string]$SvcName,
        [string]$DisplayName,
        [string]$Dir,
        [string]$ExeName,
        [string]$BinPath,
        [string]$SddlRights,
        [switch]$GrantFileAcl,
        [switch]$GrantFolderAcl
    )

    if (-not (Test-Path $Dir)) { New-Item -Path $Dir -ItemType Directory -Force | Out-Null }
    $exePath = Join-Path $Dir $ExeName
    $csPath  = Join-Path $Dir ($ExeName -replace '\.exe$', '.cs')
    $logPath = Join-Path $Dir 'service.log'

    if (-not (Test-Path $exePath)) {
        $src = $csTemplate.Replace('__SVCNAME__', $SvcName).Replace('__LOGPATH__', $logPath)
        Set-Content -Path $csPath -Value $src
        & $CscExe /nologo /target:winexe /out:"$exePath" /reference:System.ServiceProcess.dll "$csPath" | Out-Null
        if (-not (Test-Path $exePath)) { throw "Failed to compile $exePath" }
        Write-Host "Compiled $exePath"
    } else {
        Write-Host "$exePath already compiled"
    }

    if (-not (Get-Service -Name $SvcName -ErrorAction SilentlyContinue)) {
        sc.exe create $SvcName binPath= "$BinPath" start= demand DisplayName= "$DisplayName" | Out-Null
        Write-Host "Created service $SvcName"
    } else {
        Write-Host "Service $SvcName already exists"
    }

    if ($GrantFileAcl -and (Test-Path $exePath)) {
        $acl = icacls $exePath
        if ($acl -notmatch [regex]::Escape($TargetGroup)) {
            icacls $exePath /grant "${TargetGroup}:(M)" | Out-Null
            Write-Host "Granted Modify on $exePath to $TargetGroup"
        }
    }
    if ($GrantFolderAcl) {
        $acl = icacls $Dir
        if ($acl -notmatch [regex]::Escape($TargetGroup)) {
            icacls $Dir /grant "${TargetGroup}:(OI)(CI)M" | Out-Null
            Write-Host "Granted Modify on $Dir to $TargetGroup"
        }
    }

    $curSddl = sc.exe sdshow $SvcName
    $curSddl = ($curSddl -join '').Trim()
    $strippedSddl = $curSddl -replace "\(A;;[A-Z]+;;;$TargetSid\)", ''
    $desiredAce = "(A;;$SddlRights;;;$TargetSid)"
    if ($strippedSddl -notmatch [regex]::Escape($desiredAce)) {
        $newSddl = $strippedSddl -replace '^(D:)', "`$1$desiredAce"
        sc.exe sdset $SvcName $newSddl | Out-Null
        Write-Host "Granted service rights ($SddlRights) on $SvcName to $TargetGroup"
    } else {
        Write-Host "Service $SvcName already grants rights ($SddlRights) to $TargetGroup"
    }
}

# ---------------------------------------------------------------------------
# 1. Weak service permissions - writable service binary (LarpersHealthMonitor)
#    RP (start) + WP (stop) at the SC level; write access on the exe file.
# ---------------------------------------------------------------------------
Write-Step "Weak service permissions (writable binary)"
New-LarpersService -SvcName 'LarpersHealthMonitor' -DisplayName 'Workstation Health Monitor' `
    -Dir 'C:\ProgramData\Larpers\HealthMonitor' -ExeName 'HealthMonitorSvc.exe' `
    -BinPath 'C:\ProgramData\Larpers\HealthMonitor\HealthMonitorSvc.exe' `
    -SddlRights 'RPWPLC' -GrantFileAcl

# ---------------------------------------------------------------------------
# 2. Unquoted service path with a writable intermediate folder
#    (LarpersDeploySvc) - binPath (unquoted, contains spaces) resolves
#    "C:\Program Files\Vulnerable Service\Sub.exe" as an earlier candidate
#    than the real exe; that folder is writable by the target group.
# ---------------------------------------------------------------------------
Write-Step "Unquoted service path"
$deploySvcDir = 'C:\Program Files\Vulnerable Service'
$deploySvcSub = Join-Path $deploySvcDir 'Sub Folder'
if (-not (Test-Path $deploySvcSub)) { New-Item -Path $deploySvcSub -ItemType Directory -Force | Out-Null }
New-LarpersService -SvcName 'LarpersDeploySvc' -DisplayName 'Workstation Deploy Service' `
    -Dir $deploySvcSub -ExeName 'svc.exe' `
    -BinPath (Join-Path $deploySvcSub 'svc.exe') `
    -SddlRights 'RPWPLC'
# binPath is registered unquoted (sc.exe's own quoting is just for its CLI
# parser - the stored ImagePath has no quotes), so the vulnerable candidate
# "C:\Program Files\Vulnerable Service\Sub.exe" lands one level up, inside
# $deploySvcDir, which is the folder actually granted to the target group.
if ((icacls $deploySvcDir) -notmatch [regex]::Escape($TargetGroup)) {
    icacls $deploySvcDir /grant "${TargetGroup}:(OI)(CI)M" | Out-Null
    Write-Host "Granted Modify on $deploySvcDir to $TargetGroup (unquoted-path target folder)"
}

# ---------------------------------------------------------------------------
# 3. Writable directory in the system PATH (classic "DLL/EXE search order"
#    style finding independent of any specific service).
# ---------------------------------------------------------------------------
Write-Step "Writable PATH directory"
$pathDir = 'C:\ProgramData\Larpers\Tools'
if (-not (Test-Path $pathDir)) { New-Item -Path $pathDir -ItemType Directory -Force | Out-Null }
if ((icacls $pathDir) -notmatch [regex]::Escape($TargetGroup)) {
    icacls $pathDir /grant "${TargetGroup}:(OI)(CI)M" | Out-Null
    Write-Host "Granted Modify on $pathDir to $TargetGroup"
}
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$pathEntries = $machinePath -split ';' | Where-Object { $_ -ne '' }
if ($pathEntries -notcontains $pathDir) {
    $newPath = ($pathEntries + $pathDir) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'Machine')
    Write-Host "Added $pathDir to the system PATH"
} else {
    Write-Host "$pathDir already on the system PATH"
}

Write-Host "=== ALL PHASES COMPLETE ==="
