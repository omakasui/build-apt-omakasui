#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

(cd "$ROOT" && GITHUB_OUTPUT="$OUT" bash scripts/detect-changes.sh --mode dispatch --package omakasui-nvim) >/dev/null
BUILDS=$(sed -n 's/^builds=//p' "$OUT")
MATRIX=$(sed -n 's/^build_matrix=//p' "$OUT")

[[ "$(jq -r '.[0].targets | map(.product + "/" + .suite) | sort | join(" ")' <<< "$BUILDS")" == \
   'omabuntu/noble omabuntu/resolute omadeb/trixie' ]]
[[ "$(jq '[.include[] | select(.platform=="debian13")] | length' <<< "$MATRIX")" == 2 ]] || {
  echo 'ERROR: shared Trixie publications created duplicate builds' >&2; exit 1;
}
[[ "$(jq -r '.[0].targets[] | select(.product=="omadeb") | .produces | join(" ")' <<< "$BUILDS")" == \
   'omakasui-nvim omadeb-nvim' ]]

: > "$OUT"
(cd "$ROOT" && GITHUB_OUTPUT="$OUT" bash scripts/detect-changes.sh --mode product --product omari --suite trixie) >/dev/null
BUILDS=$(sed -n 's/^builds=//p' "$OUT")
jq -e 'all(.[]; all(.targets[]; .product=="omari" and .suite=="trixie"))' <<< "$BUILDS" >/dev/null
jq -e 'all(.[]; all(.targets[].produces[]; startswith("omari-") or .=="omakasui-archive-keyring" or .=="calamares-settings-omari"))' <<< "$BUILDS" >/dev/null

echo 'Target resolution tests OK.'
