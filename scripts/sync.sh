#!/usr/bin/env bash
# scripts/sync.sh — re-pull upstream sources, refresh tracked skills, run audit, print diff.
#
# Reads vendor/*.lock for the list of upstream repos and tracked skills.
# Shallow-clones each upstream into a temp dir, copies tracked skills into skills/,
# regenerates NOTICE, runs scripts/audit.sh, then prints a git diff summary so the
# operator can review before committing.
#
# Usage: bash scripts/sync.sh [--dry-run]
#
# Requires: git, python3, uvx (for mcp-scan), grep.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

cd "$REPO_ROOT"

if ! command -v python3 >/dev/null; then
  echo "ERROR: python3 is required" >&2
  exit 2
fi

# parse_lock <lockfile> emits one tab-separated line per skill:
#   <skill-name>\t<source-path>
# Plus prints upstream URL + SHA on stderr (for the caller to use).
parse_lock() {
  python3 - "$1" <<'PY'
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text()
upstream = re.search(r'^upstream:\s*(\S+)', text, re.M).group(1)
sha = re.search(r'^pinned_sha:\s*(\S+)', text, re.M).group(1)
print(f"# upstream={upstream}", file=sys.stderr)
print(f"# pinned_sha={sha}", file=sys.stderr)
# Each skill has a `name:` and a `source_path:` field
entries = re.findall(r'-\s+name:\s*(\S+)\s*\n\s+source_path:\s*(\S+)', text)
for name, path in entries:
    print(f"{name}\t{path}")
PY
}

echo "==> Sync starting"
for lock in vendor/*.lock; do
  echo
  echo "--- $lock ---"
  upstream=$(grep -E '^upstream:' "$lock" | awk '{print $2}')
  echo "  upstream: $upstream"
  clone_dir="$TMP_ROOT/$(basename "$lock" .lock)"
  git clone --depth 1 "$upstream" "$clone_dir" 2>&1 | tail -2
  new_sha=$(git -C "$clone_dir" rev-parse HEAD)
  echo "  HEAD now: $new_sha"

  parse_lock "$lock" 2>/dev/null | while IFS=$'\t' read -r name path; do
    src="$clone_dir/$path"
    dst="skills/$name"
    if [ -d "$src" ]; then
      rm -rf "$dst"
      cp -R "$src" "$dst"
      echo "    refreshed $name"
    else
      echo "    MISSING upstream $name ($path) — keeping vendored copy"
    fi
  done

  # Update pinned_sha in the lock (only if not dry-run)
  if [ "$DRY_RUN" -eq 0 ]; then
    sed -i.bak -E "s|^pinned_sha:.*|pinned_sha: $new_sha|" "$lock" && rm -f "$lock.bak"
  fi
done

echo
echo "==> Audit"
bash scripts/audit.sh

echo
echo "==> Diff summary"
if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  git -C "$REPO_ROOT" status --short
  echo
  echo "Run 'git diff' to inspect, then commit if happy."
else
  echo "(not a git repo yet — skipping diff)"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo
  echo "(dry-run: vendor/*.lock SHAs not updated)"
fi
