# Sync Review Playbook

**Date:** 2026-05-16
**Trigger:** every run of `scripts/sync.sh` (manual or weekly CI PR).
**Goal:** human gate that catches what the regex audit cannot —
supply-chain risk, prompt-injection in vendored content, schema drift,
silent failures.

This sits **on top of** the automated gates (pattern grep,
`snyk-agent-scan`, branch-protection required checks). The automated
gates are necessary but not sufficient.

## 0. Pre-flight

Before running `bash scripts/sync.sh`:

- [ ] Confirm working tree is clean on `main` (`git status`).
- [ ] Confirm `SNYK_TOKEN` is set if you want full scan locally; if not,
      note that CI must enforce it.
- [ ] Confirm `gh auth status` points to the right account for any
      push at the end (`serral` for this repo).
- [ ] Pull latest `main` so the diff is against current upstream.

## 1. Run the sync

```
bash scripts/sync.sh > /tmp/sync.log 2>&1
echo "EXIT=$?"
```

**Stop signals — investigate before continuing:**

- Non-zero exit code: parser/clone failure. Check `/tmp/sync.log`.
- A `MISSING upstream <name>` line: upstream removed a tracked skill;
  decide whether to drop it from the lockfile or pin to old SHA.
- An audit section "SEVERE findings" line count above the documented
  baseline (currently 1: gitops-workflow FluxCD installer). Any new
  severe hit is automatic block.
- "snyk-agent-scan" not skipped but reporting findings.

## 2. Lockfile sanity

For each `vendor/*.lock`, confirm the four required top-level keys are
present at column 0 (the schema-drift class that bit us on
2026-05-16 with `gemini-security.lock`):

- [ ] `upstream:` is a valid HTTPS git URL
- [ ] `pinned_sha:` is a 40-char hex SHA
- [ ] `imported_at:` is an ISO date
- [ ] `license:` is set

Quick check:

```
for f in vendor/*.lock; do
  echo "=== $f ==="
  grep -E '^(upstream|pinned_sha|imported_at|license):' "$f"
done
```

If any lockfile uses nested `source.*` or other variant keys, **stop
and normalize before committing the sync**.

## 3. SHA traceability

For each new pinned SHA, confirm it actually exists in the public
upstream (not a SHA fabricated locally or rewritten by a mirror):

```
for f in vendor/*.lock; do
  url=$(awk '/^upstream:/ {print $2}' "$f")
  sha=$(awk '/^pinned_sha:/ {print $2}' "$f")
  echo "$f  $sha"
  git ls-remote "$url" | grep -q "^$sha" && echo "  ✓ exists on upstream" \
    || echo "  ✗ NOT FOUND on upstream — investigate"
done
```

A SHA not on upstream means: (a) force-push rewrite by upstream
maintainer, (b) a local mirror is serving stale objects, or (c) tamper.
Any of these is a hard stop.

## 4. Per-source diff inspection

Run `git diff` and read each upstream's changes as a group.

**Diff intent categorization** — every changed `skills/*/SKILL.md`
should fit one of these:

| Pattern | What it looks like | Action |
|---|---|---|
| Cosmetic addition | Footer link, formatting tweak, typo fix | Skim, accept |
| Content refresh | Updated examples, new sections within scope | Read in full |
| Removal | Section dropped, file shrinks | Verify the removal is upstream's intent, not corruption |
| Suspicious | New shell command, new URL, new tool call, new env-var read, instructions to fetch external content | **STOP — escalate** |

**Red flags to grep for in the diff body:**

```
git diff skills/ | grep -nE '\b(curl|wget|nc|netcat|base64 -d|eval|exec|subprocess|os\.system|child_process)\b'
git diff skills/ | grep -nE 'https?://[^ )"]*\.(zip|tar|tar\.gz|sh|exe|bin)'
git diff skills/ | grep -nE 'ignore (previous|all|prior) instructions'
git diff skills/ | grep -nE 'system prompt|developer message'
```

Any hit on the second or third grep is a hard block until explained.
First-grep hits need context (instructional vs. directive).

## 5. Bulk-change sanity

If a single upstream's diff exceeds **20% line growth** across its
tracked skills, or **>50% of tracked skills** have non-cosmetic
changes, treat the sync as a major version:

- [ ] Read every changed SKILL.md in full, not just the diff hunks.
- [ ] Check upstream's commit log between old and new SHA for the
      maintainers' framing of the change.
      ```
      git -C /tmp/<clone> log --oneline <old_sha>..<new_sha>
      ```
- [ ] Consider holding the sync as a separate branch / PR rather than
      bundling.

## 6. Audit script invariants

The audit must produce, on a clean sync:

- [ ] `==> Pattern grep over skills/` — count matches the historical
      baseline (currently 19 lines flagged, 1 severe).
- [ ] `==> SEVERE findings` — only the documented FluxCD line.
- [ ] `==> uvx snyk-agent-scan` — either runs successfully or reports
      skipped with the SNYK_TOKEN note. Anywhere in between (errors,
      crashes) is a block.

**Improvement to land:** add a `validate-lockfile-schema` step to
`scripts/audit.sh` that asserts §2's checklist. One-time fix prevents
the 2026-05-16 schema-drift class from recurring.

## 7. Commit & push

If everything passes:

- [ ] Split into commits by intent — schema fixes separate from content
      syncs. Today's example: `4c5c04c` (schema) then `ab5f872` (sync).
- [ ] Commit message body lists per-source SHA bumps with a 1-line
      summary of content delta. Compare today's `ab5f872` body for
      shape.
- [ ] Run pre-commit hooks (they auto-run on `git commit`).
- [ ] Push only after confirming `gh auth status` is the right
      account.

## 8. Post-merge

After the sync lands on `main`:

- [ ] Spot-check one or two installed plugin bundles in Claude Code
      (`/plugin install <bundle>@serral`) and confirm skills load.
- [ ] If an upstream introduced a new dependency (MCP server, env var,
      external tool), update `vendor/<lock>.vetting_flags` and surface
      it in the README plugin table.
- [ ] Append a one-line entry to `CHANGELOG.md` under the next release
      heading.

## 9. Audit-yourself questions

Before declaring the sync done, answer aloud:

1. Did I read every diff hunk, or did I trust the summary?
2. Is there any change I accepted because it "looked routine" without
   tracing it back to an upstream commit?
3. Did the audit gate run with `SNYK_TOKEN` set, or did I skip the
   scanner?
4. If a user installed `security-core` tomorrow, am I confident no
   SKILL.md will tell their agent to run an attacker-controlled URL?

A "no" to any of these means take another pass.

---

## Living checklist

This playbook is a living doc. Each time the sync uncovers a new
failure mode, add it as a numbered section here. Two known failure
modes from history:

- **2026-05-16:** `vendor/gemini-security.lock` used nested
  `source.{repo,pinned_sha,...}` schema; sync aborted on `set -e` when
  flat-key grep returned empty. Fix: §2 schema checklist.
- *(add more here)*
