# CLAUDE.md — AgentCanvas

> The master project file. Claude Code reads this before every session.
> All agents read this before every task. This file is the single source of truth
> for stack, conventions, team structure, and non-negotiables.

---

## Product Vision

A browser-based, AI-first node graph platform where users build intelligent pipelines
by connecting nodes visually. The unique differentiator: agents are native node types,
the graph is self-modifying, and humans supervise agent edits via an approval UI.

**Demo goal:** A 5-minute walkthrough showing a live graph being built and modified by
an AI agent in real time. Target audience: developers and technical product people.
This is a proof-of-concept demo, not a production product — ship impressively, not exhaustively.

**The one thing that must work:** A user describes a goal in plain language, watches the
graph-writer agent build a graph node-by-node on the canvas, approves the agent's edits,
runs the graph, and sees results stream back live.

---

## Tech Stack

| Layer | Technology | Notes |
|---|---|---|
| Frontend | React 18 + TypeScript | Vite dev server |
| Node Canvas | React Flow v11 | Node graph, edge routing, port types |
| Code Editor | Monaco Editor | Per-node Python editor, in-panel |
| Styling | Tailwind CSS v3 | Utility-first, no CSS files |
| Design Tokens | `src/theme.ts` | All visual constants live here |
| API | FastAPI (Python 3.12) | REST + SSE for execution streaming |
| Agent Framework | LangGraph | Orchestrator, node agent, graph-writer |
| Execution | RestrictedPython | Sandboxed per-node code runner |
| Storage | JSON files | Graphs stored as JSON (demo-appropriate) |
| Streaming | SSE (Server-Sent Events) | One-directional execution streaming |
| Package manager (BE) | uv | `uv run` for all Python commands |
| Package manager (FE) | pnpm | `pnpm run` for all frontend commands |

**No database. No job queue. No Redis. No Docker.** This is a one-week demo.
These are deferred to v2. If a team member proposes adding them, flag it to Eran.

---

## Team Structure

Four agents. Each owns a domain. Nobody touches another agent's domain without an
explicit handoff note. Domain ownership is not flexible.

**Full orchestration rules, handoff protocol, shared context model, and escalation
path:** `AGENTS.md` — every agent reads this before any cross-domain work.

### Claude — Lead Developer
**Domain:** Everything not explicitly owned by Aria or Rex.
- FastAPI backend (`src/backend/**`)
- LangGraph agent runtime (`src/backend/agents/**`)
- Graph execution engine (`src/backend/executor/**`)
- All project-level markdown (`CLAUDE.md`, `ARCHITECTURE.md`, `DECISIONS.md`, `GLOSSARY.md`, `TASKS.md`)
- Commit protocol (`commit-protocol.md`)
- React Flow graph state (`src/frontend/store/**`)
- All integration wiring between frontend and backend

**Claude always commits with:**
```
Co-Authored-By: Claude <claude@anthropic.com>
```

### Aria — UI Designer
**Domain:** All things visual and experiential.
- React components (`src/frontend/components/**`)
- Design tokens (`src/frontend/theme.ts`)
- Page layouts (`src/frontend/pages/**`)
- Aria's worklog (`.claude/agents/logs/aria-worklog.md`)

**Full identity, rules, and standards:** `.claude/agents/aria.md`

**Aria always commits with:**
```
Co-Authored-By: Aria <aria.nodegraph@gmail.com>
```

### Rex — Backend Engineer
**Domain:** Python execution engine and node type system.
- Graph executor — topological sort, node runner (`src/backend/executor/**`)
- RestrictedPython sandbox (`src/backend/executor/sandbox.py`)
- Input hash cache (`src/backend/executor/cache.py`)
- Node type registry and port type definitions (`src/backend/nodes/registry.py`, `src/backend/nodes/types.py`)
- Pydantic models (`src/backend/models/**`)
- Rex's worklog (`.claude/agents/logs/rex-worklog.md`)

**Full identity, rules, and standards:** `.claude/agents/rex.md`

**Rex always commits with:**
```
Co-Authored-By: Rex <rex.nodegraph@gmail.com>
```

---

### Nova — AI Engineer
**Domain:** Everything that involves an LLM making a decision.
- LangGraph agent implementations (`src/backend/agents/**`)
- All agent prompts (`src/backend/agents/prompts/**`)
- Agent tool definitions (`src/backend/agents/tools.py`)
- LLM node execution — calling Anthropic/OpenAI from within the graph (`src/backend/nodes/llm_node.py`)
- Structured output schemas for all agent outputs
- Nova's worklog (`.claude/agents/logs/nova-worklog.md`)

**Full identity, rules, and standards:** `.claude/agents/nova.md`

**Nova always commits with:**
```
Co-Authored-By: Nova <nova.nodegraph@gmail.com>
```

---

## Commit Protocol

**Defined in full:** `commit-protocol.md`

Every step in the protocol is assigned to exactly one team member.
Claude Code reads the protocol, determines whose step is next, and invokes that agent.
No step is skipped. No two steps are combined into one commit.

---

## Pre-Commit Checks (Hook: `pre_commit_check.py`)

Before every `git commit`, Claude must confirm:

```
□ ARCHITECTURE.md — new component, pattern, or data flow introduced?
□ DECISIONS.md    — non-obvious design choice made this step?
□ GLOSSARY.md     — new concept or term introduced?
□ TASKS.md        — out-of-protocol work items discovered?
```

If any box applies and the file was not updated — stop and update it first.

**Credit check:** Did this fix, finding, or decision originate from Eran?
If yes, his name MUST appear in the commit message body.

---

## Post-Commit Hook (`post_commit_next_step.py`)

After every `git commit`, Claude automatically:
1. Reads `commit-protocol.md` to identify the next step
2. Briefly explains what the next step will build
3. Asks Eran for permission to proceed

---

## Environment Setup

```bash
# Backend
cd src/backend
uv sync
cp .env.example .env   # fill in OPENAI_API_KEY or ANTHROPIC_API_KEY
uv run uvicorn main:app --reload --port 8000

# Frontend
cd src/frontend
pnpm install
pnpm run dev           # Vite dev server on :5173
```

**Required env vars (backend `.env`):**
```
LLM_PROVIDER=anthropic          # or openai
ANTHROPIC_API_KEY=<your key>    # if using Anthropic
OPENAI_API_KEY=<your key>       # if using OpenAI
GRAPHS_DIR=./data/graphs        # JSON graph storage directory
```

---

## File Structure

```
agentcanvas/
├── CLAUDE.md                         ← this file
├── ARCHITECTURE.md                   ← living architecture doc
├── DECISIONS.md                      ← design decisions log
├── GLOSSARY.md                       ← term definitions
├── TASKS.md                          ← out-of-protocol tasks
├── commit-protocol.md                ← the build protocol
├── src/
│   ├── backend/
│   │   ├── main.py                   ← FastAPI app entry point
│   │   ├── config.py                 ← Settings (env vars)
│   │   ├── models/                   ← Pydantic models
│   │   │   ├── graph.py              ← Node, Edge, Graph models
│   │   │   └── execution.py          ← RunResult, NodeOutput models
│   │   ├── nodes/                    ← Node type registry
│   │   │   ├── registry.py           ← Available node types
│   │   │   └── types.py              ← NodeType enum + port type definitions
│   │   ├── executor/                 ← Graph execution engine
│   │   │   ├── runner.py             ← Topological sort + execute
│   │   │   ├── sandbox.py            ← RestrictedPython wrapper
│   │   │   └── cache.py              ← Input hash + output cache
│   │   ├── agents/                   ← Nova's domain
│   │   │   ├── orchestrator.py       ← LangGraph orchestrator
│   │   │   ├── node_agent.py         ← Per-node code fixer
│   │   │   ├── graph_writer.py       ← Adds/removes/rewires nodes
│   │   │   ├── tools.py              ← Agent tool definitions
│   │   │   └── prompts/              ← All system prompts (Nova owns)
│   │   │       ├── orchestrator.py
│   │   │       ├── node_agent.py
│   │   │       └── graph_writer.py
│   │   ├── storage/
│   │   │   └── graph_store.py        ← JSON file read/write
│   │   └── api/
│   │       ├── routes.py             ← All FastAPI route handlers
│   │       └── sse.py                ← SSE streaming helpers
│   └── frontend/
│       ├── index.html
│       ├── vite.config.ts
│       ├── tsconfig.json
│       ├── tailwind.config.ts
│       ├── src/
│       │   ├── main.tsx              ← React entry point
│       │   ├── App.tsx               ← Root layout
│       │   ├── theme.ts              ← ALL design tokens (Aria owns this)
│       │   ├── store/                ← Zustand graph state
│       │   │   └── graphStore.ts
│       │   ├── components/           ← Aria's domain
│       │   │   ├── canvas/           ← React Flow canvas wrapper
│       │   │   ├── nodes/            ← Custom node renderers
│       │   │   ├── panels/           ← Side panels (AI chat, node editor)
│       │   │   └── ui/               ← Shared UI primitives
│       │   ├── pages/
│       │   │   └── Editor.tsx        ← Main editor page
│       │   ├── hooks/                ← Custom React hooks
│       │   └── api/                  ← API client (fetch wrappers)
│       └── public/
├── .claude/
│   └── agents/
│       ├── aria.md                   ← Aria's identity + standards
│       ├── rex.md                    ← Rex's identity + standards
│       ├── nova.md                   ← Nova's identity + standards
│       └── logs/
│           ├── aria-worklog.md       ← Aria maintains this
│           ├── rex-worklog.md        ← Rex maintains this
│           └── nova-worklog.md       ← Nova maintains this
└── hooks/
    ├── pre_commit_check.py           ← Pre-commit markdown checker
    └── post_commit_next_step.py      ← Post-commit next step explainer
```

---

## Non-Negotiables

1. **No CSS files.** All styling via Tailwind utility classes in `.className` or `cn()`. Design tokens in `theme.ts` only.
2. **No `any` in TypeScript** unless absolutely unavoidable — and if unavoidable, comment why.
3. **All agent edits are diffs, never direct mutations.** The graph JSON is never mutated in place by an agent. Agents emit `GraphDiff` objects that the API validates before applying.
4. **The graph has two modes: EDIT and RUN.** Agents may only modify the graph in EDIT mode. A running graph is frozen.
5. **Every node conforms to the node schema** defined in `src/backend/models/graph.py`. Agent-generated nodes are validated before being added to the graph.
6. **One commit per protocol step.** Never combine two steps into one commit.
7. **Eran's approval is required before every commit.** No exceptions.
8. **SSE for execution streaming.** No WebSockets for one-directional data.
9. **JSON file storage only.** No database. No migrations. No Alembic.
10. **RestrictedPython for node sandbox.** No subprocess. No Docker. Demo-appropriate safety.

---

## How to Run a Protocol Step

1. Read `commit-protocol.md` — identify the current step and its owner.
2. Read `AGENTS.md` — check whether this step requires input from another agent before starting.
3. If a prerequisite handoff is needed, verify it is complete. If not, surface it to Eran.
4. Read the owning agent's most recent worklog session and any teammate worklogs the step depends on.
5. Invoke the right agent for the step:
   - **Claude's step** → Claude does the work directly
   - **Aria's step** → Claude invokes Aria, passes the relevant handoff context
   - **Rex's step** → Claude invokes Rex, passes the relevant handoff context
   - **Nova's step** → Claude invokes Nova, passes the relevant handoff context
6. The owning agent does the work, updates their worklog, writes any outgoing handoff notes, and prepares a commit proposal.
7. Claude runs the pre-commit checklist, updates project markdown if flagged.
8. Eran approves. The owning agent (or Claude on their behalf) commits.
9. The post-commit hook fires. Claude explains the next step, identifies its owner, and asks Eran to proceed.

---

## What Each Team Member Reads

| Agent | Must read before starting any task |
|---|---|
| Claude | `CLAUDE.md`, `AGENTS.md`, `commit-protocol.md`, `ARCHITECTURE.md` |
| Aria | `CLAUDE.md`, `AGENTS.md`, `.claude/agents/aria.md`, `.claude/agents/logs/aria-worklog.md` |
| Rex | `CLAUDE.md`, `AGENTS.md`, `.claude/agents/rex.md`, `.claude/agents/logs/rex-worklog.md` |
| Nova | `CLAUDE.md`, `AGENTS.md`, `.claude/agents/nova.md`, `.claude/agents/logs/nova-worklog.md` |

**Plus, before any cross-domain step:** read the worklogs of teammates whose recent output
your task depends on. See `AGENTS.md` for the full shared context rules.
