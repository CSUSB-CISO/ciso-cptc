# 12 — Evidence Standard & Finding Writeup

**Goal:** every action produces defensible evidence and clean findings. This is where CPTC points are
actually scored — reporting, communication, remediation, professionalism.

## Evidence discipline (do this continuously, not at the end)
- Log **every command** with a timestamp and the target host. Keep a running per-host note.
- Screenshot the **cause** (the misconfig/vuln) and the **effect** (the access/data), not just a shell.
- Redact secrets in report images (partial hashes/passwords).
- Keep raw tool output in `scans/` and `evidence/` so a finding can be reproduced.
- Strip client/institution-identifying data from evidence you carry out (see rule below).

## Finding anatomy (our template — one finding = all of this)
1. **Title** — clear and specific ("SMB signing not enforced enables NTLM relay to domain hosts").
2. **Severity** — with justification (impact × likelihood; note if chained).
3. **Affected assets** — hostnames/IPs/accounts (use real values in the internal copy).
4. **Discovery / reproduction** — the exact steps + commands + timestamped evidence.
5. **Business impact** — what it means to the *business*, in plain language.
6. **Remediation** — concrete, actionable fix (config/policy change, not just "patch").
7. **References** — MITRE ATT&CK technique ID, vendor guidance.

## Chaining for the narrative
Tell the path as a story in the exec summary: initial access → the pivot → the privilege → the data.
A single "we reached Domain Admin and read customer financials, here's the chain" beats a pile of lows.

## Client communication (scored)
- Send status updates: what's done, what's blocked, what you need.
- Ask scope questions in writing when something is ambiguous (there will be an ambiguous-scope inject).
- Keep it professional and clear — assume a non-technical reader for the executive summary.

## CPTC competition rules to bake in
- Identify only by **region + team number** in competition deliverables — **no team name ("The Larpers")
  and no CSUSB branding** in anything submitted or presented during the event.
- Stay strictly in scope; social engineering only if explicitly scoped.
- File incident reports promptly if something breaks or goes out of scope — it reduces penalties.
- No outside assistance during competition hours; the coach cannot help once the event starts.

## Deliverable templates in this project
- `CSUSB_CPTC_Internal_Network_Penetration_Testing_Report_Template.docx` — the report shell.
- Finding/Evidence standards — enforce the anatomy above on every finding from Stage 1 of practice.

## Pitfalls
- Evidence collected after the fact is weak — capture at the moment of exploitation.
- A finding without a remediation and a business-impact sentence is an incomplete finding.
