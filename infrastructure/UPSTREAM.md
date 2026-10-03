# UPSTREAM — provenance, licensing & attribution

This repo is **original work** for the CSUSB "The Larpers" CPTC training range. It
draws on the sources below. Record any future adaptation here (file, source, commit,
license) so provenance is always auditable.

## Sources referenced

| Source | URL | Commit referenced | License | How used here |
|---|---|---|---|---|
| CyberHawks `cyber-range` | https://github.com/CyberHawks-IIT/cyber-range | `98307cc` (2026-09) | **NONE on GitHub (all rights reserved by default); reuse+modify permission granted out-of-band — see below** | Reference architecture, now cleared for direct adaptation into `ad_attacks`/`mssql_misconfig`/`adcs_esc`. Port with attribution; log each adapted file in the table below. |
| CyberHawks `AttackerVMs` | https://github.com/CyberHawks-IIT/AttackerVMs | `b22bef2` (2026-09) | MIT (© 2025 CyberHawks @ Illinois Tech) | Adapted (hardened) in the separate `cptc-2026-attacker-vms` repo, with LICENSE + copyright preserved. |
| Orange-Cyberdefense `GOAD` | https://github.com/Orange-Cyberdefense/GOAD | `992307a` (2026-09) | GPLv3 | Not used yet. Stage-6 progression only; GOAD-derived files must keep GPLv3 notices and stay in bounded files. |

## Licensing status & obligations

- **cyber-range — [UNBLOCKED 2026-10-03].** GitHub publication alone doesn't grant
  reuse, but direct permission from the repo owner does. Per the project owner
  (coach, this repo): the CyberHawks `cyber-range` maintainer is a NetSPI colleague
  and fellow CPTC coach who shared the repo links and a walkthrough video
  specifically so this range could reuse/adapt them — reported here 2026-10-03.
  Stage 2–4 vulnerability roles may now be ported/adapted.
  - **Record-keeping TODO (coach action item, not blocking):** save the actual
    Slack permission message (screenshot or export) in the private
    `cptc-2026-coach-materials` repo so provenance is auditable independent of
    this file, per "When permission is confirmed" below. No LICENSE file exists
    on the upstream repo, so this doc is the only paper trail until that's done.
- **AttackerVMs — MIT.** Reusable with attribution; preserve LICENSE + copyright in
  any derived file (done in the attacker-vms repo).
- **GOAD — GPLv3.** Copyleft; preserve notices; derivatives distributed must be GPLv3.

## When permission is confirmed

### Stage 2 ("Basic Assessment") — ported 2026-10-03

Replaces `_vuln_stubs/ad_attacks` (deleted; superseded by the real roles below).
`_vuln_stubs/mssql_misconfig` and `_vuln_stubs/adcs_esc` are Stage 3/4 and were
NOT touched by this port.

| Adapted file | Source file | Source commit | Changes | License note |
|---|---|---|---|---|
| roles/ad_base_accounts/tasks/main.yml | ad_base_accounts/tasks/main.yml | 98307cc | Dropped the 1000-account synthetic credential-pool generator (`generate_pool_accounts.py`/`jsmith.txt`/`apply_pool_accounts.ps1`) entirely; replaced with small explicit account lists in `group_vars/all.yml` reusing existing Stage 1 `ad_users` (c.churro, w.wrench, g.usher weak/spray; new `svc-reports` AS-REP target; existing `svc-sql` Kerberoast target). Rewritten as native `microsoft.ad.user` tasks + `win_shell` for SPN/preauth, templated to `thelarpers.local`/`THELARPERS`/`domain_dn`. Passwords moved to vault vars. | owner permission 2026-10-03 (see "Licensing status" above) |
| roles/ad_misc_findings/files/gpp_password.ps1 | ad_misc_findings/files/gpp_password.ps1 | 98307cc | Domain name, domain DN, target OU, GPO name, and local account name templated via env vars instead of hardcoded `cyberhawks.lab`; idempotence checks added (compare existing content before `Set-Content`/`Replace`) | owner permission 2026-10-03 |
| roles/ad_misc_findings/tasks/main.yml | ad_misc_findings/tasks/dc1_findings.yml | 98307cc | Kept only the GPP-password task; dropped `netlogon_script.ps1`/`setup_svc_backup_account.ps1`/`ad_side_findings.ps1` (NETLOGON cleartext creds, svc-backup, anonymous logon, computer4/5 default/blank passwords — not in this range's Stage 2 finding list; left for a possible future stage). Added an original SMB-credential-exposure task (see below) in the same role since both are dc1-only "misc AD findings." | owner permission 2026-10-03 |
| roles/ad_misc_findings/files/smb_credential_exposure.ps1 | *(none — original)* | — | Not a direct port; written for this range using the same "plaintext creds on an open share" pattern CyberHawks itself uses in `smb_file_dump`/`netlogon_script.ps1`, to cover the "SMB credential exposure (dc1, …)" row of this range's own Stage 2 map. | n/a (original work) |
| roles/dns_zone_transfer/files/enable_zone_transfer.ps1 | dns_zone_transfer/files/enable_zone_transfer.ps1 | 98307cc | Zone name templated via env var (`domain_dns_name`) instead of hardcoded `cyberhawks.lab` | owner permission 2026-10-03 |
| roles/dns_zone_transfer/tasks/main.yml | dns_zone_transfer/tasks/main.yml | 98307cc | Added `ZONE_NAME` environment var pass-through and the Stage 2 tag; dc1-only scope note carried over verbatim (confirmed still applicable) | owner permission 2026-10-03 |
| roles/smb_file_dump/files/build_file_dump.ps1 | smb_file_dump/files/build_file_dump.ps1 | 98307cc | Share name/path templated via env vars (now runs on `web` AND `workstation`, not one sql host); folder/user-name list re-themed to Butters Family Farm identities; credential-leak file made optional (`INCLUDE_CRED_LEAK`, only set for `workstation` so it also carries that host's SMB-credential-exposure leg) | owner permission 2026-10-03 |
| roles/smb_file_dump/tasks/main.yml | smb_file_dump/tasks/main.yml | 98307cc | Retargeted from sql1 to web+workstation; removed the 1000-account-pool CSV lookup (credential now comes from `vault_local_admin_reuse_password`, tying this finding to the `local_admin_reuse` finding by design); added per-host `INCLUDE_CRED_LEAK` logic and Stage 2 tags | owner permission 2026-10-03 |
| roles/workstation_privesc/files/setup_workstation_privesc.ps1 | workstation_privesc/files/setup_workstation_privesc.ps1 | 98307cc | Substantially trimmed: kept only weak service permissions (writable binary), unquoted service path (writable intermediate folder), and a new writable-PATH-directory finding; dropped RDP/WinRM grants for the low-priv user, SeImpersonatePrivilege, forced profile creation + PSReadLine history credential planting, AlwaysInstallElevated, autologon creds, the DLL-hijack service, and the writable SYSTEM scheduled task (out of scope for this range's "straightforward" Stage 2 privesc finding / would duplicate other listed findings). Target identity switched from a single named low-priv user to a templated domain group (`privesc_target_group`, default "Domain Users"). Service/namespace names re-themed (`CyberHawksSvc` → `LarpersSvc`, `WorkstationHealthMonitor` → `LarpersHealthMonitor`, etc.) | owner permission 2026-10-03 |
| roles/workstation_privesc/tasks/main.yml | workstation_privesc/tasks/main.yml | 98307cc | Added `PRIVESC_TARGET_GROUP`/`PRIVESC_TARGET_SID` env var pass-through (SID resolved via a preceding task) and per-technique Stage 2 tags | owner permission 2026-10-03 |
| roles/workstation_privesc/files/llmnr_nbtns_ensure_enabled.ps1 | *(none — original)* | — | Not a port: LLMNR/NBT-NS poisoning is this range's Stage 2 map asking to leave the Windows **default** (enabled) alone, not a CyberHawks script. Written to idempotently re-assert the enabled default (registry) in case a hardening baseline disabled it, so the finding stays reliably present and individually tagged (`llmnr_poisoning`). | n/a (original work) |
| roles/local_admin_reuse/tasks/main.yml | *(none — original)* | — | Not a port: no matching CyberHawks source role was found for "local administrator password reuse" as a standalone finding. Written for this range's Stage 2 map row (workstation/sql1/sql2/web, shared `svc-helpdesk` local account) using `ansible.windows.win_user`; intentionally shares its password with the GPP-password finding above (same `vault_local_admin_reuse_password`) so the two findings chain. | n/a (original work) |

Keep the owner's permission message (or the added LICENSE) recorded in the private
`cptc-2026-coach-materials` repo.
