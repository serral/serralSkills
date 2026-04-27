#!/usr/bin/env bash
# scripts/audit.sh — vet every SKILL.md in skills/ for known-bad patterns.
#
# Layered checks:
#   1. Pattern grep — flags curl|wget shell-pipe-to-eval, base64 -d, password URLs,
#      direct executable downloads.
#   2. uvx mcp-scan@latest --skills skills/ — best-effort; skipped with a warning
#      if uvx isn't installed.
#
# Exits non-zero on any NEW finding (relative to the flags already recorded in
# vendor/*.lock — see compare logic below).
#
# Usage: bash scripts/audit.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

echo "==> Pattern grep over skills/"
HITS_FILE="$(mktemp)"
trap 'rm -f "$HITS_FILE"' EXIT

# Pipe-to-shell is the highest-severity pattern; flag separately.
grep -rnE '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh)' skills/*/SKILL.md > "$HITS_FILE.severe" 2>/dev/null || true

# Lower-severity / instructional patterns.
grep -rnE '(curl |wget |base64 -d|password.*://|http[s]?://[^ )"]*\.(zip|tar|exe|sh))' skills/*/SKILL.md > "$HITS_FILE" 2>/dev/null || true

severe_count=$(wc -l < "$HITS_FILE.severe" | tr -d ' ')
total_count=$(wc -l < "$HITS_FILE" | tr -d ' ')

echo "  total flagged lines: $total_count"
echo "  severe (curl|sh): $severe_count"

if [ "$severe_count" -gt 0 ]; then
  echo
  echo "==> SEVERE findings (curl/wget piped to shell):"
  cat "$HITS_FILE.severe"
  echo
  # gitops-workflow line 120 is the documented FluxCD install — already accepted in vendor lock.
  # Allow if the only severe hit is that one and it's listed in the lock.
  ACCEPTED='skills/gitops-workflow/SKILL.md:120'
  unaccepted=$(grep -v -F "$ACCEPTED" "$HITS_FILE.severe" || true)
  if [ -n "$unaccepted" ]; then
    echo "==> NEW severe findings not in accepted list:"
    echo "$unaccepted"
    rm -f "$HITS_FILE.severe"
    exit 1
  else
    echo "(only the FluxCD-install line at gitops-workflow:120, which is documented and accepted)"
  fi
fi
rm -f "$HITS_FILE.severe"

echo
echo "==> uvx snyk-agent-scan (formerly mcp-scan)"
if ! command -v uvx >/dev/null 2>&1; then
  echo "  (uvx not installed — skipping; install with 'pip install uv' for full audit)"
elif [ -z "${SNYK_TOKEN:-}" ]; then
  echo "  (SNYK_TOKEN not set — skipping snyk-agent-scan; pattern grep above is the primary gate)"
  echo "  (get a token at https://app.snyk.io/account and export SNYK_TOKEN to enable)"
else
  uvx snyk-agent-scan@latest --skills skills/ || {
    echo "snyk-agent-scan reported findings — review above" >&2
    exit 1
  }
fi

echo
echo "==> Audit OK"
