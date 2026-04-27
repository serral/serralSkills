# Changelog

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
