# Plan: Personal curated Claude Code skills repo (`serral/claude-skills`)

## Context

You want a single, trustworthy entry point for installing skills onto your Claude Code CLI, fed from three vetted upstream repos. The repo will be a **public GitHub repo at `github.com/serral/claude-skills`** that:

- Vendors copies of selected skills (pinned to upstream SHAs).
- Exposes them both as a **Claude Code plugin marketplace** AND as a flat `skills/` directory for manual copy/symlink.
- Re-pulls from upstream via a sync script that runs `uvx mcp-scan` and produces diffs you review before merging.
- Starts with a **tight curated core (~30 skills)** scoped to security, secdevops, auditor, devops, kubernetes, AWS, terraform, backend, frontend, fullstack.

Your CISO-grade vetting principle is the design constraint: every skill is reviewed once on import, scanned automatically on each upstream sync, and only updated through reviewed PRs.

## Upstream vetting summary

| Repo | Stars | License | Skills (total) | Red flags | Verdict |
|---|---|---|---|---|---|
| `jeffallan/claude-skills` | 8.6k | MIT | 87 | None detected | Safe |
| `wshobson/agents` | 34.4k | MIT | 78 plugins / 150 skills / 184 agents | None detected | Safe |
| `sickn33/antigravity-awesome-skills` | 35.2k | MIT + CC BY 4.0 | 1,436+ | None detected | Safe |

All three: active maintenance, transparent licensing, no base64-encoded commands, no runtime external fetches in the SKILL.md bodies that were sampled, no jailbreak/prompt-injection patterns. Per-skill audit still required on import.

## Repo layout

```
serral/claude-skills/
├── .claude-plugin/
│   └── marketplace.json            # Claude Code marketplace manifest (lists plugins below)
├── plugins/                        # Plugin bundles for /plugin install
│   ├── security-core/              # security-auditor, security-reviewer, secure-code-guardian, ...
│   ├── secdevops-core/             # k8s-security-policies, security-scanning, gitops-workflow, ...
│   ├── infra-core/                 # terraform-engineer, cloud-architect, kubernetes-specialist
│   ├── devops-core/                # devops-engineer, sre-engineer, monitoring-expert, github-actions-templates, cost-optimization, incident-runbook-templates
│   ├── backend-core/               # fastapi-expert, nestjs-expert, golang-pro, backend-development
│   ├── frontend-core/              # react-expert, nextjs-developer, vue-expert
│   └── fullstack-core/             # fullstack-guardian, microservices-architect, full-stack-orchestration
├── skills/                         # Flat tree (same content, for manual copy/symlink into ~/.claude/skills/)
│   └── <skill-name>/SKILL.md
├── vendor/                         # Sync state — NOT installed, just bookkeeping
│   ├── jeffallan-claude-skills.lock     # pinned commit SHA + per-skill source paths
│   ├── wshobson-agents.lock
│   └── sickn33-antigravity-awesome-skills.lock
├── scripts/
│   ├── sync.sh                     # Re-pulls upstream, copies tracked skills, runs mcp-scan, prints diff
│   ├── audit.sh                    # Runs `uvx mcp-scan@latest --skills skills/` over the whole tree
│   └── manifest.py                 # Regenerates .claude-plugin/marketplace.json from plugins/*/
├── .github/workflows/
│   ├── audit.yml                   # On PR + weekly cron: run audit.sh, fail if mcp-scan flags anything
│   └── sync.yml                    # Weekly cron: run sync.sh, open PR if upstream changed
├── NOTICE                          # Per-skill upstream attribution + commit SHA + license
├── LICENSE                         # MIT (your repo) — upstream licenses preserved in NOTICE
└── README.md                       # Install instructions, vetting policy, skill catalog
```

**Why both marketplace AND `skills/`:** marketplace gives you `/plugin install security-core@serral` from any machine; `skills/` lets you symlink individual skills into `~/.claude/skills/` for testing without committing to a plugin install.

## Initial curated skill list (~30)

Names below are upstream skill names. Sources marked: **J** = jeffallan, **W** = wshobson, **S** = sickn33.

**Security / Auditor (6):**
- `security-auditor` (S)
- `security-reviewer` (J)
- `secure-code-guardian` (J)
- `code-reviewer` (J)
- `api-security-testing` (S)
- `production-code-audit` (S)

**SecDevOps (4):**
- `security-scanning` (W)
- `backend-api-security` (W)
- `frontend-mobile-security` (W)
- `security-compliance` (W)

**DevOps / SRE (5):**
- `devops-engineer` (J)
- `sre-engineer` (J)
- `monitoring-expert` (J)
- `incident-runbook-templates` (W)
- `comprehensive-review` (W)

**Kubernetes (3):**
- `kubernetes-specialist` (J)
- `k8s-security-policies` (W)
- `gitops-workflow` (W)

**AWS / Cloud (2):**
- `cloud-architect` (J) — covers AWS/Azure/GCP
- `cost-optimization` (W)

**Terraform / IaC (2):**
- `terraform-engineer` (J)
- `cloudformation-best-practices` (S)

**CI/CD (2):**
- `github-actions-templates` (W)
- `cicd-automation` skills bundle (W) — pipeline-design + secrets-management

**Backend (3):**
- `fastapi-expert` (J)
- `nestjs-expert` (J)
- `golang-pro` (J)

**Frontend (2):**
- `react-expert` (J)
- `nextjs-developer` (J)

**Fullstack (2):**
- `fullstack-guardian` (J)
- `full-stack-orchestration` (W)

**Total: 31 skills.** Naming collisions (e.g., if `security-auditor` exists in two repos) get a source suffix: `security-auditor-sickn33`.

## Sync & vetting workflow

`scripts/sync.sh`:

1. Read each `vendor/*.lock` — extract upstream repo URL + currently-pinned commit SHA + tracked skill paths.
2. Shallow-clone each upstream into `/tmp/` at HEAD.
3. For each tracked skill: copy `SKILL.md` (and any sibling resources) from upstream into `skills/<name>/`.
4. Mirror each skill into the appropriate `plugins/<bundle>/skills/<name>/`.
5. Regenerate `NOTICE` (skill name → upstream repo + new SHA + license).
6. Run `uvx mcp-scan@latest --skills skills/` — fail loudly on any finding.
7. Print `git diff` summary so you can review before committing.
8. Update `vendor/*.lock` to new SHAs.

`.github/workflows/audit.yml`:
- Runs on every PR and on a weekly cron.
- Executes `scripts/audit.sh` (which is `uvx mcp-scan@latest --skills skills/` plus a grep for known bad patterns: `curl|wget` in skill bodies, `base64 -d`, password-protected URL patterns).
- Fails the PR check on any finding.

`.github/workflows/sync.yml`:
- Weekly cron runs `sync.sh` and opens a PR titled "chore: upstream sync <date>".
- You review the PR diff, the audit job runs automatically, you merge if clean.

## Vetting checklist applied at import time (one-shot per skill)

Per your principle, before adding any skill to `vendor/*.lock`:

1. Read the full SKILL.md — must fit on screen / readable in <5 min.
2. `grep -E '(curl|wget|base64|eval)' SKILL.md` — investigate any hit.
3. Confirm it doesn't fetch external content at runtime (or document it explicitly in NOTICE if it does).
4. `uvx mcp-scan@latest --skill <path>` — clean.
5. Check upstream commit history for the file — has the body been stable, or did it change suspiciously recently?

## Installation (after the repo exists)

```bash
# Marketplace install (any machine):
gh auth status                                          # ensure 'serral' account is active
# In Claude Code:
/plugin marketplace add serral/claude-skills
/plugin install security-core@serral
/plugin install secdevops-core@serral
/plugin install infra-core@serral
# ...etc

# Or manual symlink for individual skills:
ln -s ~/code/claude-skills/skills/security-auditor ~/.claude/skills/security-auditor
```

## Critical files to be created

- `/.claude-plugin/marketplace.json` — Claude Code plugin marketplace manifest
- `/plugins/<bundle>/.claude-plugin/plugin.json` — one per bundle
- `/scripts/sync.sh` — upstream sync engine
- `/scripts/audit.sh` — mcp-scan wrapper
- `/scripts/manifest.py` — regenerates marketplace.json from `plugins/`
- `/vendor/jeffallan-claude-skills.lock` (+ wshobson, sickn33)
- `/.github/workflows/audit.yml`, `/.github/workflows/sync.yml`
- `/NOTICE`, `/LICENSE`, `/README.md`

## Reused tools / patterns

- **`uvx mcp-scan@latest --skills`** — your stated vetting tool, runs in-tree and in CI.
- **Plugin marketplace format** — copied from how `jeffallan/claude-skills` and `wshobson/agents` already work (`.claude-plugin/marketplace.json` + `/plugin marketplace add <user>/<repo>`).
- **Shallow clone** — same approach `sickn33/antigravity-awesome-skills` uses internally; minimal disk + no upstream history pollution.
- **`gh` CLI on `serral` account** — your default; no account switching needed since the repo is personal.

## Agent team for execution (when you exit plan mode)

Per your "team of agents per repo, shut down when done" requirement, execution will spawn three short-lived `general-purpose` agents in parallel:

1. **import-jeffallan** — clones `jeffallan/claude-skills`, extracts the 14 selected skills + their resources, writes them into `skills/` and the appropriate plugin bundles, populates `vendor/jeffallan-claude-skills.lock`. Reports back. Done.
2. **import-wshobson** — same for the 11 wshobson skills.
3. **import-sickn33** — same for the 4 sickn33 skills.

A fourth agent (sequential, after imports) wires up `marketplace.json`, `NOTICE`, `README.md`, and the GitHub Actions workflows, then runs `audit.sh` locally to confirm the tree is clean.

## Verification

End-to-end test before declaring done:

1. `bash scripts/audit.sh` — exits 0, no mcp-scan findings.
2. `python scripts/manifest.py --check` — generated marketplace.json matches committed file.
3. From a scratch dir: `gh repo clone serral/claude-skills && cd claude-skills && bash scripts/sync.sh --dry-run` — exits 0, prints "no upstream changes" or a clean diff.
4. In Claude Code: `/plugin marketplace add serral/claude-skills` → `/plugin install security-core@serral` → confirm a known skill (e.g., `security-auditor`) is invocable.
5. Force a fake upstream change (edit a file in `/tmp/` clone), re-run `sync.sh`, confirm the diff appears and the audit job catches it if a malicious pattern is injected.
6. Spot-check `NOTICE` — every skill has an upstream URL, commit SHA, and license entry.

## Out of scope (for this iteration)

- Asset Reality-internal/private skills (revisit when the public repo is stable).
- Asset Reality-org-account (`ARserralheiro`) workflows — repo is personal, lives under `serral`.
- Importing all 1,436+ sickn33 skills — start tight, expand once the sync workflow is proven.
