#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
dry=()
if [[ $# -gt 1 ]] || [[ $# -eq 1 && "$1" != --dry-run ]]; then echo 'usage: deploy.sh [--dry-run]' >&2; exit 1; fi
[[ $# -eq 0 ]] || dry=(--dry-run)
[[ -f "$ROOT/site/index.html" ]] || { echo 'site/index.html missing' >&2; exit 1; }
[[ -z "$(git -C "$ROOT" status --porcelain)" ]] || { echo 'uncommitted changes' >&2; exit 1; }
rsync -avz --delete --chmod=D755,F644 "${dry[@]}" -e 'ssh -o BatchMode=yes -o ConnectTimeout=5' "$ROOT/site/" devops:/var/www/devops-site/ || exit 1
[[ ${#dry[@]} -eq 0 ]] || exit 0
curl -fsS --cacert "${CA_CERT:-$HOME/devops.crt}" https://devops.local/ >/dev/null || exit 1
echo "Deployed $(git -C "$ROOT" rev-parse --short HEAD)"
