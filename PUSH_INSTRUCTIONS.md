# Pushing this to GitHub

Claude can't push to `CSUSB-CISO/ciso-cptc` from its sandbox (the git proxy only
injects credentials for repos authorized to the Claude GitHub App, which isn't
installed on the `CSUSB-CISO` org). You have write access, so push it yourself —
it takes one of the two options below.

## Option A — one command (macOS / Linux / WSL / Git Bash)

From inside this unzipped `ciso-cptc/` folder:

```bash
bash push.sh                                   # defaults to CSUSB-CISO/ciso-cptc
# or target a different repo:
bash push.sh https://github.com/n3t1nv4d3/ciso-cptc.git
```

## Option B — manual (any OS)

The remote already has an initial commit, so clone it and layer these files on top:

```bash
git clone https://github.com/CSUSB-CISO/ciso-cptc.git
# copy the CONTENTS of this unzipped folder into the cloned ciso-cptc/ folder
# (overwrite the placeholder README.md; there's no LICENSE to worry about)
cd ciso-cptc
git add -A
git commit -m "Initial import: CPTC training range + attack playbook wiki"
git push origin main
```

## After the push — two repo settings

1. **Settings → Actions → General → Workflow permissions → "Read and write"**
   (lets the wiki Action commit the rebuilt `CPTC_Playbook_Wiki.html`).
2. Confirm the repo is **Private**.

## To let Claude push directly next time

An **org owner** installs the **Claude GitHub App** on `CSUSB-CISO` (GitHub → org
**Settings → GitHub Apps / Installed GitHub Apps** → grant Claude **write** to
`ciso-cptc`). After that, Claude can commit and push updates on its own.
