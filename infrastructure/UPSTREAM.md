# UPSTREAM — provenance, licensing & attribution

This repo is **original work** for the CSUSB "The Larpers" CPTC training range. It
draws on the sources below. Record any future adaptation here (file, source, commit,
license) so provenance is always auditable.

## Sources referenced

| Source | URL | Commit referenced | License | How used here |
|---|---|---|---|---|
| CyberHawks `cyber-range` | https://github.com/CyberHawks-IIT/cyber-range | `98307cc` (2026-09) | **NONE (all rights reserved)** | **Reference architecture only.** Topology, role-map, and management approach informed this original implementation. **No code copied.** Intentional-vulnerability roles are stubs pending explicit owner permission. |
| CyberHawks `AttackerVMs` | https://github.com/CyberHawks-IIT/AttackerVMs | `b22bef2` (2026-09) | MIT (© 2025 CyberHawks @ Illinois Tech) | Adapted (hardened) in the separate `cptc-2026-attacker-vms` repo, with LICENSE + copyright preserved. |
| Orange-Cyberdefense `GOAD` | https://github.com/Orange-Cyberdefense/GOAD | `992307a` (2026-09) | GPLv3 | Not used yet. Stage-6 progression only; GOAD-derived files must keep GPLv3 notices and stay in bounded files. |

## Licensing status & obligations

- **cyber-range — [BLOCKER for Stage 2–4].** No license = all rights reserved;
  publication on GitHub does **not** grant reuse. Until the owner grants explicit
  **written** permission to reuse *and* modify (ideally by adding a LICENSE, e.g.
  MIT, to the repo), this project uses it as a *reference architecture* only and
  copies none of its source. The MVP (Stage 1) needs none of its code — it is
  generic AD/DNS/SQL setup written from scratch here.
  - **Permission status:** _pending explicit confirmation._ (A collegial Slack
    share of the repo links was noted but is not, on its own, a reuse+modify grant;
    awaiting an explicit "yes, adapt it" from the owner or a LICENSE on the repo.)
- **AttackerVMs — MIT.** Reusable with attribution; preserve LICENSE + copyright in
  any derived file (done in the attacker-vms repo).
- **GOAD — GPLv3.** Copyleft; preserve notices; derivatives distributed must be GPLv3.

## When permission is confirmed

Add rows here for each adapted file, e.g.:

```
| Adapted file | Source file | Source commit | Changes | License note |
|---|---|---|---|---|
| roles/ad_attacks/tasks/kerberoast.yml | cyber-range roles/... | 98307cc | templated identity vars; ... | owner permission 2026-__-__ (screenshot in coach-materials) |
```

Keep the owner's permission message (or the added LICENSE) recorded in the private
`cptc-2026-coach-materials` repo.
