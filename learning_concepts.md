# Learning Concepts

A running explanation of meaningful tools, patterns, and techniques introduced during
the build of AgentCanvas — written for Eran to understand what the team is building and why.

Each entry explains not just *what* something is, but *why* it works the way it does
and what would go wrong without it.

---

## Step 1 — Adam: Makefile & .env.example

### What is a Makefile?

A Makefile is a shortcut system. It lets you give long, hard-to-remember shell commands
a short, human-friendly name. You define the shortcut once, and from then on you just
type `make <name>`.

**Why not just write a shell script?**
- A Makefile is language-agnostic — it works the same whether the project uses Python,
  Node, Go, or anything else
- It's the universal convention developers expect. When someone clones an open-source
  project, the first thing they look for is a Makefile. It's the front door.
- It documents how to run the project just by existing — the targets are self-explanatory

---

### `make install` — setting up dependencies

This target runs two commands in sequence:
1. `uv sync` inside `src/backend/` — installs all Python dependencies listed in `pyproject.toml`
2. `pnpm install` inside `src/frontend/` — installs all JavaScript/TypeScript dependencies listed in `package.json`

**What is `uv`?**
- `uv` is a modern Python package manager (like pip, but much faster)
- `uv sync` reads the project's dependency list and installs exactly the versions specified
- It also creates a virtual environment automatically — an isolated Python environment
  so this project's packages don't conflict with other Python projects on your machine

**What is `pnpm`?**
- `pnpm` is a JavaScript package manager (like npm, but faster and more disk-efficient)
- `pnpm install` reads `package.json` and installs all the frontend libraries the project needs

---

### `make dev-backend` — starting the Python API server

Runs: `uv run uvicorn main:app --reload --port 8000`

Breaking this down:
- **`uv run`** — runs the command inside the project's virtual environment (so it uses the
  correct Python version and installed packages)
- **`uvicorn`** — a fast web server that can run Python FastAPI applications
- **`main:app`** — "look in the file called `main.py`, find the object named `app`, and serve it"
- **`--reload`** — hot-reload mode: every time you save a Python file, the server automatically
  restarts with your changes. You never have to stop and restart it manually during development.
- **`--port 8000`** — the server listens on port 8000, so you reach it at `http://localhost:8000`

---

### `make dev-frontend` — starting the React web app

Runs: `pnpm run dev` inside `src/frontend/`

**What is `pnpm run dev`?**
- Inside `src/frontend/package.json` there is a section called `"scripts"` — a list of named
  commands the project's developers defined
- `run dev` executes whichever command is defined under the `"dev"` key in that scripts section
- In this project it starts **Vite**, which is the frontend build tool

**What does Vite do in dev mode?**
- Starts a local web server, usually at `http://localhost:5173`
- Enables **Hot Module Replacement (HMR)** — this is the magic that makes your browser update
  the moment you save a file, without you pressing refresh. Vite surgically replaces only
  the changed module in memory, preserving the app's current state.

---

### `make dev` — starting both servers at once

Runs both the backend and frontend simultaneously in one terminal window.

**How does it work? The `&` and `wait` symbols:**
- `&` after a command means "start this in the background and immediately move on"
- Without `&`, the terminal would wait for the backend to finish before starting the frontend
  (and the backend never "finishes" — it runs until you stop it, so the frontend would never start)
- So: `make dev-backend &` starts the backend in the background, then `make dev-frontend &`
  starts the frontend in the background

**Why `wait` at the end?**
- Without `wait`, the shell sees that it has started both background processes and immediately
  thinks its job is done — it exits, which kills both servers
- `wait` tells the shell: "stay open and keep these background processes alive until I manually
  stop them (Ctrl+C)"
- The result: both servers run in parallel, both show their logs in the same window, and
  pressing Ctrl+C stops both cleanly

---

### `make lint` — checking code quality without running it

Runs two checks:
1. `ruff check src/backend/` — checks Python code
2. `tsc --noEmit` inside `src/frontend/` — checks TypeScript code

**What is Ruff?**
- A Python linter — it reads your code and flags problems: unused imports, undefined variables,
  style violations, potential bugs
- It doesn't run the code; it just reads it. Think of it like spell-check for Python.
- It's extremely fast (written in Rust) — checks thousands of lines in milliseconds

**What is `tsc --noEmit`?**
- `tsc` is the TypeScript Compiler — it checks that your TypeScript types are correct
  (e.g., you're not passing a number where a string is expected)
- Normally `tsc` would also *compile* your TypeScript into JavaScript files
- `--noEmit` says: "just check for errors, don't produce any output files"
- It's a pure health check — it catches type errors before they become runtime bugs

---

### `make test` — running the test suite

Runs: `pytest src/backend/`

**What is pytest?**
- Python's standard testing framework
- It discovers files named `test_*.py` or `*_test.py`, runs every function named `test_*`,
  and reports which ones pass and which ones fail
- `-x` flag (used in CI): stop at the first failure instead of running all tests.
  Fast feedback — you see the problem immediately.

---

### `make build-frontend` — packaging the app for production

Runs: `pnpm run build` inside `src/frontend/`

**Development mode vs production build — what's the difference?**

| | Dev mode (`make dev-frontend`) | Production build (`make build-frontend`) |
|---|---|---|
| Speed | Slow to start, optimised for change speed | Slow to build, optimised for delivery speed |
| Output | Hundreds of separate files served by Vite | 2–3 minified files in a `dist/` folder |
| Size | Large — includes debugging tools, source maps | Small — all whitespace, comments, long variable names stripped |
| Use case | Writing code | Deploying to users |

**Analogy:** Dev mode is a messy kitchen where you cook and taste as you go.
A production build is the final packaged meal ready to be delivered.

The `dist/` folder produced by the build is what FastAPI will serve to real users in production
(Step 38 in the protocol).

---

### `make production-check` — validating the deployment is ready

A safety check before deploying:
- Verifies the `FRONTEND_DIST_DIR` environment variable is set
- Verifies the `dist/` directory actually exists at that path
- Exits with a clear error message if either check fails

**Why this matters:**
Without this check, a missing `dist/` folder would cause the deployed app to silently serve
nothing — users would see blank pages or 404 errors. The check surfaces this problem before
deployment, not after.

---

### `.env.example` — documenting secrets without exposing them

The application needs secrets to run (API keys, config values). These live in a `.env` file
which is excluded from git — if it were committed, the secrets would be public on GitHub forever.

**The problem:** if `.env` is never committed, how does a new developer know what variables to set?

**The solution: `.env.example`**
- A committed file containing every variable name with a placeholder value and a comment
  explaining where to get the real value
- A new developer: copies `.env.example` → `.env`, fills in the blanks, and the app runs
- Acts as both documentation and a setup checklist

**The rule:** if the app needs an env var, it appears in `.env.example` *before* any code
that uses it is written. A secret that isn't documented is a secret that will be missing
at 2am when someone deploys to a new environment.

---

## Step 2 — Adam: GitHub Actions CI

### What is CI? (Continuous Integration)

CI stands for Continuous Integration. The idea: every time a developer pushes code, an
automated system immediately checks whether that code is correct — without anyone having
to manually run tests or check for errors.

**Why it matters:**
- Without CI: broken code can sit undetected until someone notices the app doesn't work
- With CI: broken code is caught within minutes of being pushed, while the context is fresh
- It also means the team can move fast with confidence — if CI is green, the code is in a
  known-good state

---

### What is GitHub Actions?

GitHub Actions is GitHub's built-in CI/CD system. You define workflows as YAML files in
`.github/workflows/`. When a trigger event happens (like a push to `main`), GitHub:

1. Spins up a fresh virtual machine (Ubuntu Linux in our case) in the cloud
2. Checks out your repository onto that machine
3. Runs every step you defined, in order
4. Reports pass/fail back to the pull request or commit

**Key concepts:**
- **Workflow** — the whole `.yml` file; defines when and what to run
- **Job** — a group of steps that run on the same machine
- **Step** — a single command or action within a job
- **Runner** — the virtual machine that executes the job (`ubuntu-latest`)

---

### Two independent jobs — why not one?

AgentCanvas has a Python backend and a TypeScript frontend. We could have run all checks
in one job, sequentially. We didn't — here's why:

**Sequential (one job):**
```
ruff check → pytest → tsc → pnpm build
```
If ruff fails, pytest never runs. If pytest fails, tsc never runs. You fix one error,
push again, find the next error. Fix-push-wait cycle repeats.

**Independent jobs (our approach):**
```
Job 1: ruff check → pytest     (runs in parallel)
Job 2: tsc → pnpm build        (runs in parallel)
```
Both jobs run simultaneously. If the backend lint fails AND the frontend build fails,
you see both failures at once and can fix everything in one go. Faster feedback.

---

### CI caching — why dependencies aren't reinstalled every time

Every CI run starts from a completely clean machine. Without caching, that means
reinstalling every Python and JavaScript package from the internet on every push.

**The cache key trick:**
- GitHub Actions can store directories between runs
- The cache key is a hash of the lock file (`uv.lock` or `pnpm-lock.yaml`)
- A lock file only changes when a dependency is added, removed, or updated
- If nothing changed: same hash → cache restored → packages available in seconds
- If something changed: new hash → fresh install → result cached for next run

**The practical difference:**
- Cold cache (no match): ~60 seconds to install dependencies
- Warm cache (match): ~5 seconds

Without caching, CI would be slow enough that developers start ignoring it.

---

### pytest exit code 5 — "no tests found" is not a failure

pytest uses specific exit codes to communicate different outcomes:
- **Exit code 0** — all tests passed ✓
- **Exit code 1** — one or more tests failed ✗
- **Exit code 2** — pytest itself had an internal error ✗
- **Exit code 5** — pytest ran fine, but found zero test files

In a brand-new project, there are no test files yet. pytest exits with code 5 every time.
Without handling this, CI would fail on every push from day one — before a single line
of business logic has been written.

**The fix:** remap exit code 5 to 0 in the shell step.
- Exit code 5 → treated as success (no tests yet is fine)
- Exit codes 1 and 2 → still surface as real failures

This keeps CI green from day one. As soon as the first test file is added, pytest
finds it and exit code 5 never appears again.

---

> Concepts are added here as the build progresses.
