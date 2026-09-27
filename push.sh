#!/usr/bin/env bash
# Push this bundle to a GitHub repo you have write access to.
# Usage:  bash push.sh [git-remote-url]
# Default remote: CSUSB-CISO/ciso-cptc
set -euo pipefail

REMOTE="${1:-https://github.com/CSUSB-CISO/ciso-cptc.git}"
SRC="$(cd "$(dirname "$0")" && pwd)"

# sanity: are we in the bundle?
if [ ! -d "$SRC/infrastructure" ] || [ ! -d "$SRC/playbook" ]; then
  echo "Run this from inside the unzipped ciso-cptc/ folder." >&2; exit 1
fi

TMP="$(mktemp -d)"
echo "[*] Cloning $REMOTE ..."
git clone "$REMOTE" "$TMP/repo"

echo "[*] Copying bundle contents into the clone ..."
# copy everything except VCS metadata; overwrite placeholder files
if command -v rsync >/dev/null 2>&1; then
  rsync -a --exclude '.git' "$SRC"/ "$TMP/repo"/
else
  cp -a "$SRC"/. "$TMP/repo"/    # SRC has no .git, safe
fi

cd "$TMP/repo"
git add -A
if git diff --cached --quiet; then
  echo "[i] Nothing new to commit — repo already up to date."; exit 0
fi
git commit -m "Initial import: CPTC training range + attack playbook wiki"
echo "[*] Pushing ..."
git push origin HEAD:main
echo "[+] Done. Pushed to $REMOTE"
echo "    Next: repo Settings -> Actions -> Workflow permissions -> Read and write."
