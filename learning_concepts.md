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

> Concepts are added here as the build progresses.
