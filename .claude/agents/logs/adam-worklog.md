# Adam — DevOps Engineer Worklog

> All infrastructure decisions, cross-domain findings, and inter-agent conversations
> live here. Claude reads this log to track Adam's work and route flags appropriately.

---

## Session Index

| Date | Session | Status | Key Decision |
|---|---|---|---|
| 2026-03-26 | Step 1 — Makefile, .env.example, .gitignore | ✅ Done | Added `data/graphs/*.json` to .gitignore (was missing from spec gap); all 8 env vars in .env.example; 8 Makefile targets complete |
| 2026-03-26 | Step 2 — GitHub Actions CI (lint and build) | ✅ Done | Two independent jobs (backend + frontend); pytest exit code 5 remapped to 0 so CI is green before tests exist; pnpm cache via setup-node integration rather than manual actions/cache |

---

<!-- New sessions are added below, most recent first -->

---

## 2026-03-26 — Step 1: Makefile, .env.example, .gitignore

### Task Brief

Deliver the local developer environment foundation for AgentCanvas. The infrastructure
problem being solved: a new developer should be able to clone the repo, run `make install`,
and have a working local stack — without reading a wall of documentation or guessing
which commands to run. Every env var the app needs must be listed before any application
code is written that consumes them.

Three deliverables:
1. `Makefile` — one-command entry points for install, dev, lint, test, build
2. `.env.example` — all 8 env vars with placeholder values and one-line comments
3. `.gitignore` — review and patch any gaps

---

### Decisions

**Makefile structure — `src/backend` and `src/frontend` don't exist yet (Steps 3 and 4)**

Decision: Define all targets correctly so they work when the directories exist. Do not
add existence guards — that would silently swallow errors later when a real failure
occurs. The Makefile is documentation-as-code; the targets should look exactly like
what the team will run.

Exception: `make dev` runs both services in parallel using `&` and `wait`. On Windows
this pattern does not work in cmd.exe, but the project uses bash (CLAUDE.md specifies
Unix shell syntax). Documented in a Makefile comment.

**`make production-check` target**

The step spec says: verify `FRONTEND_DIST_DIR` is set and `dist/` exists, exit non-zero
with a clear message if not. I used a shell conditional with `$(FRONTEND_DIST_DIR)` expansion
and a `-d` check on the resolved path. This gives a clear failure message instead of a
cryptic `make` error.

**`.gitignore` — gap found: `data/graphs/*.json`**

The commit-protocol.md Step 1 spec explicitly calls out that `data/graphs/*.json` should
be excluded, with `demo.json` as the tracked exception. The existing `.gitignore` does
not include this. Adding it with a negation pattern `!data/graphs/demo.json` to allow
the demo graph to be tracked.

Also adding: `*.egg-info/`, `.pytest_cache/`, `.ruff_cache/` — standard Python tooling
artifacts that will appear once Rex sets up the backend in Step 3. Better to pre-empt
them now than clean them up after.

**`.env.example` — ordering**

Ordered by concept group: LLM provider config first (the most common thing to fill in),
then storage config, then demo-tier access control, then production-only vars last.
This ordering guides a developer filling in the file top-to-bottom in priority order.

---

### Dependencies on Other Agents

None for this step. The Makefile references `src/backend` and `src/frontend` directories
that Rex (Step 3) and Aria (Step 4) will create. The Makefile is forward-compatible —
it will work correctly once those directories exist.

---

### Self-Review Checklist

- [x] All 8 env vars present in `.env.example` with placeholder values and comments
- [x] Makefile has all required targets: install, dev-backend, dev-frontend, dev, lint, test, build-frontend, production-check
- [x] `make dev` runs both services in parallel (with note about bash requirement)
- [x] `.gitignore` covers: `.env`, `src/backend/.env`, `*.pyc`, `__pycache__/`, `node_modules/`, `dist/`, `.claude/settings.local.json`, `memory/`, `data/graphs/*.json`
- [x] No secrets staged
- [x] Only files in Adam's domain staged

---

### Documentation Flags for Claude

📋 Documentation flags:
- No ARCHITECTURE.md update needed — this step adds tooling, not a new system component.
- No DECISIONS.md update needed — the Makefile/env structure is straightforward and follows standard conventions.
- No GLOSSARY.md update needed — no new domain terms introduced.
- TASKS.md: No out-of-protocol discoveries.

---

## 2026-03-26 — Step 2: GitHub Actions CI (lint and build on every push)

### Task Brief

Deliver the CI layer for AgentCanvas: a GitHub Actions workflow that validates every push
to `main` and every pull request. The infrastructure problem being solved: without CI,
a developer who introduces a Python import error or a TypeScript type violation won't know
until it reaches review — or worse, lands in main. CI catches these within minutes of the push.

Deliverable: `.github/workflows/ci.yml` — one workflow, two independent jobs.

---

### Decisions

**Two independent jobs, not a single sequential job**

The spec requires `backend` and `frontend` jobs that report independently. I validated
this is the right choice: if the backend lint fails and the frontend build also fails,
a sequential single job would mask the frontend failure entirely. The team would fix the
backend, push again, and only then discover the frontend error. Two independent jobs
show both failures simultaneously. GitHub Actions displays them as parallel status checks
on the PR — the team sees the full picture at a glance.

**pytest exit code 5 — remap to 0 in the CI step**

pytest uses exit code 5 to mean "no tests were collected". In a fresh project where
`src/backend/tests/` doesn't exist yet, every `pytest` invocation exits 5 — which
would fail CI on every push and train the team to ignore CI failures. The fix: capture
the exit code in the shell step, remap 5 → 0 with a clear echo message, and pass
through all other non-zero codes unchanged. This means CI is green from day one, and
stays accurate the moment tests are added. Using `|| true` was explicitly rejected —
that would silently swallow real pytest failures (exit codes 1, 2) as well.

**pnpm caching via `pnpm/action-setup` + `actions/setup-node` cache integration**

Two approaches for pnpm caching in GitHub Actions:
1. Manual: `pnpm/action-setup` to install pnpm, then `actions/cache` with `$(pnpm store path)` as the path.
2. Integrated: `pnpm/action-setup` to install pnpm first, then `actions/setup-node` with `cache: "pnpm"` and `cache-dependency-path: src/frontend/pnpm-lock.yaml`.

I chose option 2. The `actions/setup-node` built-in cache support for pnpm handles the
store path resolution automatically and follows GitHub's recommended pattern. The key is
correctly ordered: `pnpm/action-setup` must run before `actions/setup-node` so the node
action can locate the pnpm binary and resolve its store path. This is documented in a
comment in the workflow file.

**uv caching via `actions/cache` with `~/.cache/uv`**

uv stores its download cache at `~/.cache/uv` on Linux. This is not configurable without
env vars. I used `actions/cache` directly (not a uv-specific action) since the uv GitHub
Action ecosystem is still young and the manual cache approach is stable. The cache key
is keyed on `src/backend/uv.lock` — matching the Makefile's source of truth for
backend dependencies.

**`ruff check src/backend/` path — redundant but explicit**

The `working-directory: src/backend` is set for the lint step, making `src/backend/`
redundant in the ruff command. However, the commit protocol spec explicitly writes
`ruff check src/backend/` — I kept it as written to match the spec exactly. When
`src/backend/` exists and working-directory is set, ruff resolves to an absolute path —
no behavioral issue.

**Workflow pinned to `ubuntu-latest` for both jobs**

The spec says `ubuntu-latest` for both runners. I confirmed this is correct for the demo
phase — `ubuntu-latest` gets security patches automatically from GitHub. For production
CI (v2), pinning to a specific Ubuntu version (`ubuntu-22.04`) is the right call to
prevent surprise runner updates mid-sprint. Flagged for v2 planning.

---

### Dependencies on Other Agents

None for this step. The workflow references `src/backend/` and `src/frontend/` directories
that Rex (Step 3) and Aria (Step 4) will create. Both CI jobs will fail with path errors
until those directories exist — that is expected per the spec.

---

### Self-Review Checklist

- [x] `.github/workflows/ci.yml` is valid YAML (validated with Python yaml.safe_load)
- [x] Two jobs defined: `backend` and `frontend`
- [x] Runs on push to `main` and `pull_request`
- [x] Backend job: Python 3.12, uv install, uv sync, ruff check, pytest with exit code 5 handling
- [x] Frontend job: Node 20, pnpm install, tsc --noEmit, Vite build
- [x] uv cache keyed on `src/backend/uv.lock`
- [x] pnpm cache keyed on `src/frontend/pnpm-lock.yaml`
- [x] Both jobs report independently
- [x] No secrets in the workflow file
- [x] Only files in Adam's domain staged: `.github/workflows/ci.yml`, `adam-worklog.md`
- [x] learning_concepts.md updated with Step 2 concepts

---

### Documentation Flags for Claude

📋 Documentation flags for Step 2:
- DECISIONS.md: Consider logging the pytest exit-code-5 remapping decision — it's non-obvious and the rationale (keeping CI green before tests exist without silently swallowing real failures) is worth preserving. Claude's call on whether it clears the bar for DECISIONS.md vs. staying in this worklog.
- GLOSSARY.md: No new domain terms introduced.
- ARCHITECTURE.md: No new system component — CI is tooling.
- TASKS.md: No out-of-protocol discoveries.
- learning_concepts.md: Updated — 3 concepts added for Step 2: GitHub Actions overview, CI caching with lock files, and pytest exit code 5.

---

