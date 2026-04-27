#!/usr/bin/env python3
"""scripts/manifest.py — regenerate .claude-plugin/marketplace.json from plugins/.

Walks plugins/<bundle>/.claude-plugin/plugin.json, builds a marketplace.json
listing each one. Keeps the marketplace manifest in sync with the on-disk
plugin tree.

Usage:
    python3 scripts/manifest.py            # regenerate, write to disk
    python3 scripts/manifest.py --check    # diff-only; exit 1 if regenerated content differs
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PLUGINS_DIR = REPO_ROOT / "plugins"
MARKETPLACE_PATH = REPO_ROOT / ".claude-plugin" / "marketplace.json"

OWNER = {"name": "Andre Serralheiro", "url": "https://github.com/serral"}
MARKETPLACE_NAME = "serral-claude-skills"
MARKETPLACE_DESC = (
    "Personally curated Claude Code skills, fed from vetted upstream repos. "
    "Focus: security, secdevops, devops, kubernetes, AWS, terraform, backend, "
    "frontend, fullstack."
)


def collect_plugins() -> list[dict]:
    plugins = []
    for plugin_json in sorted(PLUGINS_DIR.glob("*/.claude-plugin/plugin.json")):
        meta = json.loads(plugin_json.read_text())
        bundle = plugin_json.parent.parent.name
        plugins.append({
            "name": meta["name"],
            "source": f"./plugins/{bundle}",
            "description": meta.get("description", ""),
        })
    return plugins


def build_marketplace() -> dict:
    return {
        "name": MARKETPLACE_NAME,
        "owner": OWNER,
        "metadata": {"description": MARKETPLACE_DESC, "version": "0.1.0"},
        "plugins": collect_plugins(),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="exit 1 if regenerated content differs")
    args = parser.parse_args()

    new = build_marketplace()
    new_str = json.dumps(new, indent=2) + "\n"

    if args.check:
        existing = MARKETPLACE_PATH.read_text() if MARKETPLACE_PATH.exists() else ""
        if existing != new_str:
            print("marketplace.json is out of date — run scripts/manifest.py to regenerate", file=sys.stderr)
            return 1
        print("marketplace.json up to date")
        return 0

    MARKETPLACE_PATH.write_text(new_str)
    print(f"wrote {MARKETPLACE_PATH.relative_to(REPO_ROOT)} — {len(new['plugins'])} plugins")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
