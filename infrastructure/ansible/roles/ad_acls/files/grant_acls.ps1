$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory

# Adapted from CyberHawks cyber-range roles/ad_acls/files/grant_acls.ps1
# (98307cc), owner permission 2026-10-03 -- see ../../../UPSTREAM.md.
#
# Trimmed from CyberHawks' 9 ACEs (which also cover DCSync,
# ForceChangePassword, AdminSDHolder/Self-Membership persistence, msDS-
# KeyCredentialLink, and RBCD) down to exactly the 3 named in this range's
# finding map: "GenericAll/WriteDACL/WriteOwner granted to a non-admin
# account or group". The principal and the three targets come from
# group_vars/all.yml instead of a synthetic credential-pool CSV, reusing
# this range's existing Butters Family Farm identities so the finding
# chains off Stage 2's g.usher weak-password/spray target rather than
# introducing a parallel, unrelated "attacker" account.

$principalSam = $env:ACL_ABUSE_PRINCIPAL_SAM
$genericAllTargetSam = $env:ACL_ABUSE_GENERICALL_TARGET_SAM
$writeDaclTargetSam = $env:ACL_ABUSE_WRITEDACL_TARGET_SAM
$writeOwnerTargetSam = $env:ACL_ABUSE_WRITEOWNER_TARGET_SAM
if (-not $principalSam) { throw "ACL_ABUSE_PRINCIPAL_SAM environment variable not set" }
if (-not $genericAllTargetSam) { throw "ACL_ABUSE_GENERICALL_TARGET_SAM environment variable not set" }
if (-not $writeDaclTargetSam) { throw "ACL_ABUSE_WRITEDACL_TARGET_SAM environment variable not set" }
if (-not $writeOwnerTargetSam) { throw "ACL_ABUSE_WRITEOWNER_TARGET_SAM environment variable not set" }

$principalSid = New-Object System.Security.Principal.SecurityIdentifier((Get-ADUser $principalSam).SID)

function Add-Ace {
    param(
        [Parameter(Mandatory = $true)][string]$TargetDN,
        [Parameter(Mandatory = $true)][System.DirectoryServices.ActiveDirectoryRights]$Rights,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $path = "AD:\$TargetDN"
    $acl = Get-Acl -Path $path

    $alreadyPresent = $acl.Access | Where-Object {
        $_.IdentityReference -eq $principalSid.Translate([System.Security.Principal.NTAccount]) -and
        $_.ActiveDirectoryRights -eq $Rights -and
        $_.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Allow
    }
    if ($alreadyPresent) {
        Write-Output "Already present: $Label on $TargetDN"
        return
    }

    $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
        $principalSid, $Rights, [System.Security.AccessControl.AccessControlType]::Allow)
    $acl.AddAccessRule($rule)
    Set-Acl -Path $path -AclObject $acl
    Write-Output "Granted $Label on $TargetDN"
}

# 1. GenericAll -> genericall-target user (full control: reset password,
#    add to groups via shadow credentials, etc.)
$genericAllTarget = Get-ADUser $genericAllTargetSam
Add-Ace -TargetDN $genericAllTarget.DistinguishedName -Rights GenericAll -Label "GenericAll"

# 2. WriteDacl -> writedacl-target user (can grant itself further rights)
$writeDaclTarget = Get-ADUser $writeDaclTargetSam
Add-Ace -TargetDN $writeDaclTarget.DistinguishedName -Rights WriteDacl -Label "WriteDacl"

# 3. WriteOwner -> writeowner-target user (can take ownership, then grant itself rights)
$writeOwnerTarget = Get-ADUser $writeOwnerTargetSam
Add-Ace -TargetDN $writeOwnerTarget.DistinguishedName -Rights WriteOwner -Label "WriteOwner"

Write-Output "DONE"
