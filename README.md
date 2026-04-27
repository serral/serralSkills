# serral/claude-skills

Personally curated Claude Code skills, vendored from three vetted upstream
repos. Exposed as a Claude Code plugin marketplace **and** a flat `skills/`
tree, with a sync workflow that keeps everything pinned, scanned, and
reviewed.

Focus areas: **security, secdevops, devops, kubernetes, AWS, terraform,
backend, frontend, fullstack.**

## Install

```bash
# In Claude Code:
/plugin marketplace add serral/claude-skills

# Then install whichever bundles you want:
/plugin install security-core@serral
/plugin install secdevops-core@serral
/plugin install infra-core@serral
/plugin install devops-core@serral
/plugin install backend-core@serral
/plugin install frontend-core@serral
/plugin install fullstack-core@serral
```

Or, for a single skill without committing to a bundle, symlink it directly:

```bash
ln -s /path/to/this/repo/skills/security-auditor ~/.claude/skills/security-auditor
```

## Plugin bundles

| Bundle | Skills | Description |
|---|---|---|
| `security-core` | 6 | Auditor, secure-code-guardian, code-reviewer, security-reviewer, api-security-testing, production-code-audit |
| `secdevops-core` | 8 | STRIDE, attack trees, SAST, k8s security policies, GitOps, secrets-management |
| `infra-core` | 4 | Terraform, CloudFormation, Kubernetes, multi-cloud architecture |
| `devops-core` | 7 | DevOps/SRE, monitoring, GH Actions, deployment pipelines, runbooks, cost-opt |
| `backend-core` | 3 | FastAPI, NestJS, Go |
| `frontend-core` | 2 | React, Next.js |
| `fullstack-core` | 1 | Fullstack guardian |

Total: **31 skills.** See `NOTICE` for per-skill upstream attribution and
pinned SHAs.

## Vetting policy

Every skill in this repo has been:

1. Read in full (the SKILL.md must be reviewable in <5 min).
2. Scanned with `grep -nE '(curl |wget |base64 -d|password.*://|http[s]?://[^ )"]*\.(zip|tar|exe))' SKILL.md` — any hits are recorded under `vetting_flags` in the corresponding `vendor/*.lock`. All current flags are benign instructional examples (health-check curls, ArgoCD password idiom).
3. Confirmed not to fetch external content at runtime.
4. Pinned to a specific upstream commit SHA in `vendor/*.lock`.

Updates are gated: `scripts/sync.sh` re-pulls upstream, regenerates the
content, runs `uvx mcp-scan@latest`, and produces a diff for review. The
`.github/workflows/audit.yml` workflow blocks PRs on any new vetting hit.

## Layout

```
.
├── .claude-plugin/marketplace.json   # marketplace manifest
├── plugins/<bundle>/                 # plugin manifests + symlink trees into skills/
├── skills/<skill>/SKILL.md           # canonical vendored content
├── vendor/<repo>.lock                # per-source pinned SHA + per-skill provenance + vetting flags
├── scripts/
│   ├── sync.sh                       # re-pull upstreams, copy tracked skills, audit, diff
│   ├── audit.sh                      # run mcp-scan + grep checks
│   └── manifest.py                   # regenerate marketplace.json from plugins/
├── .github/workflows/{audit,sync}.yml
├── NOTICE                            # upstream attribution
└── plan.md                           # original design doc
```

## Sync workflow

```bash
# Manual sync, locally:
bash scripts/sync.sh

# CI: a weekly cron in .github/workflows/sync.yml opens a PR titled
# "chore: upstream sync <date>". Audit job runs on every PR.
```

## Upstream sources

- [`jeffallan/claude-skills`](https://github.com/jeffallan/claude-skills) — MIT — 15 skills
- [`wshobson/agents`](https://github.com/wshobson/agents) — MIT — 12 skills
- [`sickn33/antigravity-awesome-skills`](https://github.com/sickn33/antigravity-awesome-skills) — MIT + CC BY 4.0 — 4 skills

## License

This repo is MIT (see `LICENSE`). Vendored skills retain their upstream
licenses; see `NOTICE` for attribution.
