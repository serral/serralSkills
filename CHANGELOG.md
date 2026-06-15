# Changelog

> Maintenance: add an entry here on **every** upstream sync and every skill
> import. The sync PR template and `docs/SYNC_REVIEW.md` §8 both call this out.
> Tooling/CI changes worth an operator's attention belong here too.

## 0.3.0 — 2026-06-15 — Upstream sync (threat-model skills restructured) + CI hardening

### Upstream sync
SHA bumps (3 of 4 sources; `gemini-cli-extensions/security` unchanged):
- `jeffallan/claude-skills` `5e8b6b8f` → `e8be415b`
- `wshobson/agents` `112197c6` → `cc37bfdd`
- `sickn33/antigravity-awesome-skills` `2e0c5a9c` → `2312cadd`

### Changed skills
Upstream moved the bulk of 6 threat-modeling skills out of `SKILL.md` into a new
`references/details.md` (~3,240 lines relocated, no net content loss):
`attack-tree-construction`, `deployment-pipeline-design`,
`incident-runbook-templates`, `security-requirement-extraction`,
`stride-analysis-patterns`, `threat-mitigation-mapping`. Skill count unchanged
(34). No new vetting flags.

### CI / tooling
- Bumped `actions/checkout@v4 → v5` and `peter-evans/create-pull-request@v6 → v8`
  for Node 24 readiness (ahead of the 2026-06-16 runner cutover).
- Wired the `SNYK_TOKEN` repo secret into the audit job so `snyk-agent-scan`
  runs in CI instead of skipping. Forked-PR runs still skip (secret withheld by
  design); the pattern grep remains the primary gate.
- Renamed stale `mcp-scan` references to `snyk-agent-scan` across workflows,
  scripts, and README (the tool was renamed Feb 2026).
- Enabled the GitHub Actions "create and approve pull requests" setting so the
  weekly sync PR opens automatically.

---

## 0.2.1 — 2026-05-16 — Upstream sync + sync-review playbook

### Upstream sync
SHA bumps across all 4 sources:
- `jeffallan/claude-skills` `3d95bb16` → `5e8b6b8f`
- `wshobson/agents` `adde832d` → `112197c6`
- `sickn33/antigravity-awesome-skills` `89e9867f` → `2e0c5a9c`
- `gemini-cli-extensions/security` `0e4812c4` → `2227f3cf`

### Changed skills
Content refresh across 16 vendored skills (mostly footer-link/metadata
additions); `sast-configuration` trimmed by 12 lines. Skill count unchanged
(34). No new vetting flags.

### Tooling / docs
- Added `docs/SYNC_REVIEW.md`, a human supply-chain review checklist that sits
  on top of the automated audit for every sync PR.
- Normalized `vendor/gemini-security.lock` to the flat top-level schema (it had
  used nested `source.*` keys, which aborted the sync under `set -e`).
- `.gitignore`'d `skilltemp/`.

---

## 0.2.0 — 2026-04-27 — Add gemini-cli-extensions/security

### Imported
- **`gemini-cli-extensions/security`** @ `0e4812c4` (Apache-2.0) — 3 skills

### New skills
- `poc` → `security-core` — PoC generation for vulnerability testing
- `security-patcher` → `security-core` — vulnerability patching workflow
- `dependency-manager` → `secdevops-core` — isolated dependency management for PoC execution

### Vetting flags carried forward (informational, all benign)
- All three skills carry `mcp_dependency` flags: they invoke MCP tools
  (`poc_context`, `run_poc`, `security_patch_context`, `install_dependencies`) shipped
  with the upstream Gemini CLI MCP server. Skills function as instructional content in
  Claude Code but require that MCP server to be wired up for full operation.

### License note
Apache-2.0 (first non-MIT vendor). Attribution preserved in NOTICE; upstream copyright
retained via bit-identical vendoring.

---

## 0.1.0 — 2026-04-27 — Initial import

Curated 31 skills from 3 vetted upstream repos.

### Imported
- **`jeffallan/claude-skills`** @ `3d95bb16` (MIT) — 15 skills
- **`wshobson/agents`** @ `adde832d` (MIT) — 12 skills
- **`sickn33/antigravity-awesome-skills`** @ `89e9867f` (MIT + CC BY 4.0) — 4 skills

### Plugin bundles
`security-core` (6), `secdevops-core` (8), `infra-core` (4), `devops-core`
(7), `backend-core` (3), `frontend-core` (2), `fullstack-core` (1).

### Deferred
4 wshobson plugins contained agent personas only (no `SKILL.md`):
`backend-api-security`, `frontend-mobile-security`, `security-compliance`,
`comprehensive-review`. Recorded under `deferred_targets:` in
`vendor/wshobson-agents.lock`.

### Tooling
- `scripts/sync.sh`, `scripts/audit.sh`, `scripts/manifest.py`.
- `.github/workflows/{audit,sync}.yml` (weekly cron + PR audits).
- Pre-commit: gitleaks, pre-commit-hooks, ruff, shellcheck, plus local hooks
  for marketplace-sync and the skills pattern audit.
- `.gitleaks.toml` with one file-scoped allowlist for known-safe placeholder
  secrets in a vendored Kubernetes tutorial.
- `audit.sh` allow-lists the FluxCD install command at
  `skills/gitops-workflow/SKILL.md:120` (upstream-documented `curl|sudo
  bash`).

### Vetting flags carried forward (informational, all benign)
- `incident-runbook-templates`, `deployment-pipeline-design`,
  `secrets-management`, `devops-engineer`, `secure-code-guardian`: example
  `curl` commands in instructional content.
- `gitops-workflow`: ArgoCD `base64 -d` password idiom + FluxCD install
  command (allow-listed).
