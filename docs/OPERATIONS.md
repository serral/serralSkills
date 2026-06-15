# Operations runbook

Operator-facing notes for maintaining `serralSkills` over time. Captures
lessons from the initial import (2026-04-27) so future syncs and additions
don't re-discover the same potholes.

---

## Adding a new skill

1. Confirm the skill exists upstream and has a real `SKILL.md` (not an agent
   persona — see [Per-upstream quirks](#per-upstream-quirks) below).
2. Read the full SKILL.md once. If you can't read it in <5 min, that's a red
   flag.
3. Run the import-time vetting checklist (see README's *Vetting policy*).
4. Add an entry under `skills:` in the relevant `vendor/<repo>.lock` with
   `name`, `source_path`, and `vetting_flags` (empty list if clean).
5. `cp -R <upstream>/<source_path> skills/<name>/`.
6. Add a symlink under the appropriate `plugins/<bundle>/skills/<name>` →
   `../../../skills/<name>`. If a new bundle is needed, also create
   `plugins/<bundle>/.claude-plugin/plugin.json`.
7. `python3 scripts/manifest.py` to regenerate `.claude-plugin/marketplace.json`.
8. Update `NOTICE` skill list.
9. Add a `CHANGELOG.md` entry under the next release heading (see
   [Keeping the CHANGELOG current](#keeping-the-changelog-current)).
10. `pre-commit run --all-files` — must pass.
11. Commit and push.

---

## Per-upstream quirks

### `jeffallan/claude-skills`
- Layout: `skills/<name>/SKILL.md` plus `references/`, `scripts/`, etc.
- Clean import. 87 skills total; we vendor 15.
- One known gitleaks finding (placeholder secrets in
  `skills/kubernetes-specialist/references/configuration.md`) is allowlisted
  in `.gitleaks.toml` with a file-scoped rule. **Do NOT broaden the
  allowlist by rule alone** — real secrets in a future sync would slip
  through.

### `wshobson/agents`
- Layout: `plugins/<plugin-name>/{agents,commands,skills}/`. Skills live
  under `plugins/<plugin>/skills/<skill>/SKILL.md`. **Some plugins contain
  ONLY `agents/` (Claude personas), not `skills/`** — these have no
  SKILL.md and were deferred at import time:
  `backend-api-security`, `frontend-mobile-security`, `security-compliance`,
  `comprehensive-review`. Recorded under `deferred_targets:` in
  `vendor/wshobson-agents.lock`.
- `pipeline-design` does NOT exist under that name; the actual upstream skill
  is `deployment-pipeline-design`. Imported under the upstream name.
- `security-scanning` is a 5-skill bundle, not a single skill.

### `sickn33/antigravity-awesome-skills`
- Layout: `skills/<name>/SKILL.md`. Clean.
- **Huge** (1,400+ skills, ~235 MB clone). Use `--depth 1` always.
- Persona-instructional content; vetting flags will normally be empty. Spot
  check each new skill anyway.

### `gemini-cli-extensions/security`
- Layout: `skills/<name>/SKILL.md` (same as jeffallan — straightforward import).
- **License: Apache-2.0** — first non-MIT vendor in this repo. Attribution is
  preserved via bit-identical vendoring and the NOTICE entry. No additional
  license file is required for redistribution of unmodified content, but do not
  broaden this to other Apache-2.0 repos without re-reading the license terms.
- **MCP-dependent skills**: all three skills (`poc`, `security-patcher`,
  `dependency-manager`) call custom MCP tools (`poc_context`, `run_poc`,
  `security_patch_context`, `install_dependencies`) that are shipped with the
  upstream Gemini CLI MCP server (`mcp-server/` in the repo). These skills work
  as instructional guidance in Claude Code but require that MCP server to be
  wired up for full end-to-end operation. Recorded as `mcp_dependency` under
  `vetting_flags:` in `vendor/gemini-security.lock`.
- The repo also contains `commands/` (Gemini CLI TOML slash-commands) and a
  `GEMINI.md` context file. These are Gemini-specific and were not imported —
  only the `skills/` subtree is vendored.

---

## Audit (the security gate)

`scripts/audit.sh` runs two layers:

### 1. Pattern grep (always runs, primary gate)
Scans `skills/*/SKILL.md` for: `curl|wget` piped to shell, `base64 -d`,
password-bearing URLs, direct executable downloads. Severe finding =
exit 1.

**Vetting flag taxonomy** (recorded in `vendor/*.lock` under `vetting_flags:`):

| Flag | Meaning | Action |
|---|---|---|
| *(empty list)* | Clean — no hits | None |
| example curl/wget | Instructional command in skill body | Confirm benign, record |
| `base64 -d` | Decode idiom (e.g., ArgoCD password) | Confirm benign, record |
| `mcp_dependency` | Skill calls MCP tools not in Claude Code's default toolset | Document which tools; skill works as instructional guidance only without the external MCP server |
| `executable_download` | Direct `.zip/.tar/.exe` URL | Investigate — likely a blocker |

**Allowlist:** the FluxCD install command at
`skills/gitops-workflow/SKILL.md:120` (`curl -s https://fluxcd.io/install.sh
| sudo bash`) is hard-coded as accepted in `audit.sh`. It's the
upstream-documented FluxCD install. **Re-review on every sync** — if the
URL changes, that's a red flag.

### 2. `uvx snyk-agent-scan` (was `mcp-scan`)
- Tool was renamed February 2026: `mcp-scan` → `snyk-agent-scan`.
- Requires `SNYK_TOKEN` env var. Get one at https://app.snyk.io/account.
- Skipped gracefully if token is unset; the pattern grep is the real gate.
- To enable in CI: `gh secret set SNYK_TOKEN` and add
  `env: { SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }} }` to the audit job step.

---

## Pre-commit hooks

`pre-commit run --all-files` runs 11 hooks. Notes:

- **`exclude` is per-hook, not global.** Whitespace fixers (`trailing-whitespace`,
  `end-of-file-fixer`, `check-yaml`, `check-json`) skip `skills/` so vendored
  content stays bit-identical to upstream. Gitleaks deliberately does NOT
  exclude `skills/` — that's the gate.
- The default `gitleaks` pre-commit hook scans **staged changes only**, not
  the full tree. Use `gitleaks detect --source=.` manually for one-shot
  full scans (e.g., right after a sync).
- Local hooks (`marketplace-in-sync`, `skills-pattern-audit`) only fire when
  relevant files change — see `files:` patterns in `.pre-commit-config.yaml`.

---

## Sync workflow

`scripts/sync.sh`:
1. Reads each `vendor/*.lock`, shallow-clones upstream into a temp dir.
2. Refreshes each tracked skill (`cp -R upstream → skills/`).
3. Updates `pinned_sha` in the lock file (skip with `--dry-run`).
4. Runs `scripts/audit.sh`.
5. Prints `git status --short` so the operator can review the diff.

`.github/workflows/sync.yml`: weekly cron (Mondays 06:23 UTC) opens a PR
titled `chore: upstream sync <run-id>`. The audit workflow runs as a check.
Review the diff (especially any new `vetting_flags`) before merging. **Before
merging, add the `CHANGELOG.md` entry to the PR branch** (see below) - the PR
template has a checklist item for it.

---

## Keeping the CHANGELOG current

`CHANGELOG.md` is the operator-facing record of what changed and why. It drifted
once already (the 2026-05-16 and 2026-06-15 syncs landed unrecorded), so the
reminder now lives in three places that are hard to skip:

1. The sync PR body (`.github/workflows/sync.yml`) has a `CHANGELOG.md updated`
   checklist item.
2. The add-a-skill checklist above (step 9).
3. `docs/SYNC_REVIEW.md` §8 (post-merge).

**What earns an entry:** every upstream sync (even content-only refreshes), every
skill import, and any tooling/CI change an operator would want surfaced (action
bumps, new secrets, audit-gate changes).

**Conventions:**
- Newest version first, under a `## <version> — <date> — <summary>` heading.
- Bump the patch digit for content-only syncs (e.g. `0.2.1`), the minor digit
  for structural changes or new skills (e.g. `0.3.0`).
- For syncs, list the per-source `pinned_sha` bumps (`<old> → <new>`) so the
  record is traceable without `git log`.
- Note "Skill count unchanged (N)" or the new total, and call out any new
  `vetting_flags`.

For the automated weekly sync PR, the merging operator is responsible for adding
the entry to the PR branch before merge - the bot does not write it.

---

## Push & GitHub gotchas

- **GitHub email-privacy** rejects pushes whose commits use a primary email.
  All commits must use the GitHub noreply form
  `<id>+<username>@users.noreply.github.com`. Look up your ID with
  `gh api user --jq .id`. If a future commit slips through, fix with:
  ```bash
  git filter-branch -f --env-filter '
  if [ "$GIT_AUTHOR_EMAIL" = "<old>" ]; then
    export GIT_AUTHOR_EMAIL="<noreply>"
  fi
  if [ "$GIT_COMMITTER_EMAIL" = "<old>" ]; then
    export GIT_COMMITTER_EMAIL="<noreply>"
  fi' -- --all
  ```
- **Account discipline**: `gh auth status` must show `serral` active before
  any operation on this repo. The work account `ARserralheiro` is for
  Asset Reality org repos only.
- **Marketplace name vs repo path**: in Claude Code, you `/plugin marketplace
  add serral/serralSkills` (repo path), but `/plugin marketplace remove
  serralSkills` (marketplace `name` field from `marketplace.json`). Don't
  confuse the two.

---

## Sub-agents (for AI-assisted maintenance)

If you delegate import work to Claude sub-agents, note that **agents may be
denied Bash permission even when the parent session has it**. The first
import attempt in this session hit exactly this — three sub-agents reported
back blocked on `git clone` / `cp`. The fix is either to grant Bash to
sub-agents explicitly, or run the imports inline from the parent session
(faster and what we ended up doing).

---

## Things that are NOT lessons but noise

- zsh-vs-bash word splitting in pipe-to-while subshells caused a brief
  `cp: command not found` red herring. Solved by using a bash heredoc with
  array iteration. Not a real bug — just a shell foot-gun.
- `git mv plan.md .history/plan.md` keeps the file tracked at the new path;
  `.gitignore` only affects untracked files. To make a moved file local-only,
  `git rm --cached <new-path>` after the move (or just delete it from index
  with `git reset HEAD` then commit the deletion).
