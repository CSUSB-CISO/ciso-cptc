# ciso-cptc — CSUSB "The Larpers" CPTC program

Training range + attack playbook for the CSUSB CPTC team, themed to the CPTC12
(2026–27) scenario **Butters Family Farm** (theme-park operations).

> ⚠️ **Keep this repository PRIVATE.** It carries team branding and offensive
> reference material. It is **student-accessible**, so **coach-only solution keys and
> the real Stage 2–4 intentional-vulnerability roles must NOT be committed here** —
> those belong in a separate coach-only private repo. What's here today contains no
> answers (only benign infra + vulnerability *stubs*).

## Layout

```
infrastructure/   # Terraform + Ansible to build the isolated Proxmox range (MVP)
playbook/         # The searchable attack playbook wiki (source .md + generated HTML)
.github/workflows # Auto-rebuilds the playbook wiki on push
```

## Playbook wiki (`playbook/`)

Phase-ordered CPTC attack reference with full-text, tool-aware search.

- **Read/search it:** open `playbook/CPTC_Playbook_Wiki.html` in any browser. Search a
  tool/technique/port (e.g. `evil-winrm`, `kerberoast`, `esc1`, `1433`) — every hit
  jumps + highlights.
- **Edit it:** change a `playbook/NN_*.md` file. On push, the GitHub Action rebuilds
  `CPTC_Playbook_Wiki.html` automatically. To build locally: `python playbook/build_wiki.py`.
- The `.md` files are the source of truth; the HTML is generated.

## Range (`infrastructure/`)

Isolated Proxmox AD range, provisioned with Terraform, configured with Ansible,
staged from a benign MVP up to full CPTC-style complexity via one `vuln_stage`
variable. Start with:

- `infrastructure/README.md` — overview
- `infrastructure/REQUIRED_INPUTS.md` — what access/info is needed to build
- `infrastructure/docs/LAB_INTAKE_QUESTIONNAIRE.md` — intake questions (incl. GlobalProtect access)
- `infrastructure/docs/BUILD_RUNBOOK.md` — step-by-step build

**Access:** the team uses **Palo Alto GlobalProtect**; range VMs sit on an isolated
bridge with no uplink. See the runbook/questionnaire for the build-host vs student-access design.

## Provenance & licensing

See `infrastructure/UPSTREAM.md`. This is original work using CyberHawks `cyber-range`
as a **reference architecture only** (no license → all rights reserved); its
intentional-vulnerability roles are **stubbed** pending explicit owner permission.
`AttackerVMs` is MIT (adapted with attribution where used). GOAD is GPLv3 (later stages).

## First-time setup

1. Keep the repo **Private** (Settings ▸ General ▸ Danger Zone if needed).
2. Settings ▸ Actions ▸ General ▸ Workflow permissions → **Read and write**
   (lets the wiki Action commit the rebuilt HTML).
3. Copy `infrastructure/terraform/terraform.tfvars.example` → `terraform.tfvars` and
   fill in (gitignored). Create the Ansible Vault (`infrastructure/ansible/group_vars/`).
4. Push an edit to a `playbook/NN_*.md` and confirm the Action runs green.
