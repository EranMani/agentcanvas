# Learning Concepts

Meaningful concepts and techniques introduced during the build of AgentCanvas.
Updated by the committing agent when a step introduces something genuinely worth explaining.

**The bar:** Only add an entry if the concept is non-obvious, interesting, or likely to
confuse someone reading the code for the first time. Wiring steps and boilerplate do not
need entries. Quality over quantity — 1–2 tight concepts beats 5 padded ones.

**Format:** One section per step. Concept name as a subheading. 3–6 sentences max per concept —
explain what it is, why it was chosen, and what would go wrong without it.

---

## Step 1 — Adam: Makefile, .env.example, .gitignore

### Makefile — project command shortcuts

A Makefile is a simple system for defining named commands (called *targets*) that run
shell instructions. Instead of remembering `cd src/backend && uv run uvicorn main:app --reload --port 8000`,
you type `make dev-backend`. Instead of starting the frontend and backend separately, `make dev` runs both
in parallel.

The reason to use a Makefile over a shell script or npm scripts: it's language-agnostic, universally
available on Mac/Linux (Git Bash on Windows), and the standard convention developers expect. Cloning a
repo and running `make install` is the shortest path from "nothing" to "running". It also enforces
consistency — everyone on the team runs the same commands in the same way, eliminating "works on my
machine" startup differences.

### .env.example — documenting secrets without exposing them

The `.env` file holds real secrets (API keys, database URLs) and is excluded from git. `.env.example`
is the committed counterpart — it lists every environment variable the project needs with placeholder
values and a comment explaining where to get the real one. It serves as both documentation and a
setup checklist: a new developer copies it to `.env` and fills in the blanks.

The rule: if the application needs an env var, it must appear in `.env.example` before any code
that uses it is written. A secret that isn't documented is a secret that will be missing at 2am
when someone deploys to a new environment.

---

## Step 2 — Adam: GitHub Actions CI

### GitHub Actions — automated checks on every push

GitHub Actions runs workflows defined as YAML files in `.github/workflows/`. When a developer pushes to `main` or opens a pull request, GitHub spins up a fresh virtual machine (Ubuntu, in this case), checks out the repository, and executes each step in the workflow. If any step exits with a non-zero code, the job fails and the pull request is blocked.

The key architectural choice here: two **independent jobs** (`backend` and `frontend`). If the backend lint fails, GitHub still runs the frontend build — both results are visible simultaneously. A single job with sequential steps would hide the frontend failure behind the backend failure, which wastes time when the failures are unrelated.

### CI job caching — why lock files are the cache key

Each CI run starts from a clean machine, which means reinstalling dependencies from scratch every time — slow and expensive. GitHub Actions' `actions/cache` stores directories between runs and restores them when the cache key matches. The cache key is a hash of the lock file (`uv.lock` or `pnpm-lock.yaml`): if no dependency changed, the hash is identical and the full cache is restored in seconds. If a dependency was added or updated, the hash changes, the old cache is bypassed, and a fresh install runs — then the result is cached for the next run.

Without this, a 30-dependency Python project and a 200-package Node project would reinstall from the internet on every push. With it, a cold cache takes ~60 seconds; a warm cache takes ~5.

### pytest exit code 5 — "no tests collected" is not a failure

pytest uses exit code 5 specifically to mean "the test runner ran successfully, but found no test files." This is distinct from exit code 1 (test failed) or exit code 2 (internal error). In a fresh project where the test suite hasn't been written yet, `pytest` will exit 5 every time — which would cause CI to fail on every push, discouraging the team from running CI at all.

The solution: check the exit code in the shell step and remap exit code 5 to 0 (success). Any other non-zero code still surfaces as a real failure. This means CI is green from day one and stays accurate as tests are added.

---

> Concepts are added here as the build progresses.
