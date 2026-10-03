$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory

# Adapted (heavily trimmed) from CyberHawks cyber-range
# roles/adcs_esc_templates/files/build_esc_templates.ps1 (98307cc), owner
# permission 2026-10-03 -- see ../../../UPSTREAM.md. CyberHawks builds 8
# ESC templates (ESC1,2,3,4,9,13,15,17) plus ESC5/ESC6/ESC7/ESC9/ESC10/
# ESC11/ESC16 CA-/DC-wide config. This range's finding map asks only for
# "at least one ESC1 or ESC8 template misconfig" on ca, so only the ESC1
# template (enrollee supplies subject + client auth EKU, Enroll granted to
# Domain Users -- the classic "impersonate anyone" misconfig) is built
# here; ESC8 is a pre-existing property of the Web Enrollment role already
# installed by roles/adcs_ca (confirmed, not built, by this role's
# publish_template.yml / confirm_esc8.yml).

$templateName = $env:ESC1_TEMPLATE_NAME
$enrollGroup = $env:ESC1_ENROLL_GROUP
if (-not $templateName) { throw "ESC1_TEMPLATE_NAME environment variable not set" }
if (-not $enrollGroup) { throw "ESC1_ENROLL_GROUP environment variable not set" }

$configNC = (Get-ADRootDSE).configurationNamingContext
$templatesContainer = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"

$ENROLL_GUID = [Guid]"0e10c968-78fb-11d2-90d4-00c04f79dc55"
$CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT = 1
$EKU_CLIENT_AUTH = "1.3.6.1.5.5.7.3.2"

$existing = Get-ADObject -SearchBase $templatesContainer -Filter "Name -eq '$templateName'" -ErrorAction SilentlyContinue
if ($existing) {
    Write-Output "$templateName already exists, skipping creation"
} else {
    # Base the new template on the built-in "User" template, copying only
    # the known pKICertificateTemplate schema attributes (not every
    # returned property -- many are read-only/computed and New-ADObject
    # rejects them). This preserves tricky byte-array fields like
    # pKIExpirationPeriod/pKIOverlapPeriod exactly rather than hand-rolling
    # them.
    $baseTemplate = Get-ADObject -SearchBase $templatesContainer -Filter "Name -eq 'User'" -Properties *
    $oidPrefix = ($baseTemplate."msPKI-Cert-Template-OID" -replace '\.\d+$', '')
    $newOid = "$oidPrefix.101"

    $copyableAttrs = @(
        "flags", "pKIDefaultKeySpec", "pKIKeyUsage", "pKIMaxIssuingDepth",
        "pKICriticalExtensions", "pKIExpirationPeriod", "pKIOverlapPeriod",
        "pKIDefaultCSPs", "msPKI-Minimal-Key-Size", "msPKI-Template-Schema-Version",
        "msPKI-Template-Minor-Revision", "msPKI-Private-Key-Flag",
        "msPKI-Certificate-Application-Policy", "msPKI-RA-Application-Policies",
        "msPKI-Enrollment-Flag", "msPKI-Certificate-Name-Flag"
    )
    $srcProps = @{}
    foreach ($p in $copyableAttrs) {
        if ($null -ne $baseTemplate.$p) { $srcProps[$p] = $baseTemplate.$p }
    }

    $newObj = New-ADObject -Name $templateName -Type "pKICertificateTemplate" -Path $templatesContainer -OtherAttributes $srcProps -PassThru

    Set-ADObject -Identity $newObj -Replace @{
        "displayName"                 = $templateName
        "msPKI-Cert-Template-OID"     = $newOid
        "msPKI-Certificate-Name-Flag" = $CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT   # ESC1: enrollee supplies subject
        "msPKI-RA-Signature"          = 0
        "pKIExtendedKeyUsage"         = @($EKU_CLIENT_AUTH)                 # client auth -> usable for logon/impersonation
        "revision"                    = 100
    }

    # Grant Enroll to the given low-priv group -- any member can request a
    # cert for an arbitrary subject (ESC1).
    $acl = Get-Acl -Path "AD:\CN=$templateName,$templatesContainer"
    $groupSid = New-Object System.Security.Principal.SecurityIdentifier((Get-ADGroup $enrollGroup).SID)
    $rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
        $groupSid, "ExtendedRight", "Allow", $ENROLL_GUID)
    $acl.AddAccessRule($rule)
    Set-Acl -Path "AD:\CN=$templateName,$templatesContainer" -AclObject $acl

    Write-Output "Created $templateName (OID $newOid, ENROLLEE_SUPPLIES_SUBJECT set, Enroll granted to $enrollGroup)"
}

Write-Output "DONE"
