# Design Decisions

Non-obvious choices made during development — what was decided, why, and what was rejected.
Claude owns this file. Aria and Rex flag entries; Claude writes them.

Format: `DEC-XXX — [Title]`

---

## DEC-001 — JSON file storage instead of a database

**Decision:** Graphs are stored as JSON files in `GRAPHS_DIR`. No Postgres, no SQLite, no Alembic.

**Rationale:** This is a one-week demo. A database adds setup friction (Docker, migrations, connection pooling) that delays the demo goal. JSON files are trivially readable, portable, and sufficient for a single-user demo. Version history is a folder of JSON snapshots — no schema needed.

**Rejected:** SQLite (adds Alembic, migrations, async complexity). Postgres (too much infrastructure for a demo).

**Revisit:** Before any multi-user deployment.

---

## DEC-002 — SSE over WebSockets for execution streaming

**Decision:** `GET /runs/{run_id}/stream` uses Server-Sent Events (SSE), not WebSockets.

**Rationale:** Execution streaming is one-directional (server → browser). SSE is simpler to implement, more reliable over proxies, and needs no connection state management. The browser's `EventSource` API handles reconnection automatically. WebSockets are bidirectional — reserved for features that genuinely need it (none in scope).

**Rejected:** WebSockets (unnecessary complexity for one-directional data).

---

## DEC-003 — Agents emit diffs, never direct graph mutations

**Decision:** All three agents (orchestrator, node agent, graph-writer) return `GraphDiff` or `DiffBundle` objects. They never write to the graph store directly.

**Rationale:** Direct mutations are opaque and irreversible. Diffs are inspectable (the user sees exactly what the agent wants to change), validatable (the API rejects type violations before applying), and reversible (version history captures the state before any diff is applied). This design makes the "agent edits the graph" feature feel safe rather than scary.

**Rejected:** Agents calling the graph store directly (bypasses validation, no user review, no history).

---

## DEC-004 — Graph has two modes: EDIT and RUN, with agents blocked during RUN

**Decision:** The graph is a state machine with EDIT and RUN modes. Agent diffs are queued and rejected during RUN mode.

**Rationale:** Allowing agents to modify the graph while it's executing creates race conditions and produces non-reproducible runs. Inspired by ComfyUI's "queue a run, execute deterministically" model. The graph is frozen at run time — what you saw before clicking Run is what runs.

**Rejected:** Allowing mid-run agent modifications (concurrency nightmare, non-reproducible).

---

## DEC-005 — RestrictedPython over subprocess or Docker for node sandboxing

**Decision:** Code nodes are executed in a RestrictedPython sandbox in-process.

**Rationale:** This is a demo. Docker adds significant infrastructure overhead. Subprocess adds complexity and OS-level concerns. RestrictedPython is lightweight, in-process, and blocks dangerous builtins (os, sys, open, __import__) with clear error messages. Sufficient for a trusted-user demo environment.

**Revisit:** Before any public deployment — replace with Docker-based isolation per node execution.

---

## DEC-006 — LangGraph for all agent implementations

**Decision:** All three agents use LangGraph state machines. Nova owns all agent implementations.

**Rationale:** LangGraph makes agent control flow explicit and inspectable. The state transitions (read graph → decide action → produce diff → return) are defined as a graph — which is fitting given the domain. Human-in-the-loop checkpoints are native to LangGraph. Raw LLM calls in while loops are opaque and hard to debug.

**Rejected:** Raw LangChain chains (less structured), CrewAI (too high-level, loses control), direct LLM API calls (no state management).

---

## DEC-009 — Nova owns all LLM-touching code; Rex owns all execution-touching code

**Decision:** The AI engineer role (Nova) is split from the backend engineer role (Rex). Nova owns: LangGraph agents, prompts, tool definitions, LLM node execution. Rex owns: RestrictedPython sandbox, graph executor, node type registry, Pydantic models.

**Rationale:** Agent engineering and execution engine engineering are distinct disciplines with different failure modes, different debugging approaches, and different best practices. Mixing them in one agent creates an agent that is expert at neither. The split also clarifies the interface: Nova's agents consume Rex's `NodeSpec` / `GraphDiff` models and return structured diffs — the contract is clean.

**Interface between Nova and Rex:** Nova reads `NodeSpec`, `GraphDiff`, `DiffBundle` (Rex's models). Nova's agents return `DiffBundle`s. Rex's executor consumes `NodeSpec`s. They never directly call each other's code — Claude's API layer mediates.

---

## DEC-010 — Prompts live in agents/prompts/, not inlined in agent logic

**Decision:** System prompts and few-shot examples live in `src/backend/agents/prompts/` as separate Python files, not inlined as strings inside agent logic.

**Rationale:** Prompts are Nova's primary engineering artefact — they deserve the same treatment as code. Separating them from control flow makes them reviewable, diffable, and independently testable. A reviewer can read `prompts/graph_writer.py` without parsing through LangGraph node definitions to find the prompt string. It also makes prompt iteration faster: Nova can change a prompt without touching the agent logic.

---

## DEC-007 — Port type system enforced at canvas level, not just at runtime

**Decision:** React Flow's `isValidConnection` prop rejects incompatible port connections visually before they are attempted.

**Rationale:** Runtime port type errors are confusing — the user doesn't know why a node failed. Catching the type mismatch at connection time gives immediate, clear feedback. Inspired by ComfyUI's port type enforcement. The `PortType` enum is defined in the backend models and mirrored in the frontend.

---

## DEC-008 — One-week scope: no job queue, no Redis, no multi-tenancy

**Decision:** No Celery, no Redis, no BullMQ. Execution is synchronous within a request lifecycle. No user authentication.

**Rationale:** The demo goal is to show the graph modification interaction, not to demonstrate production infrastructure. Every deferred component (queue, auth, multi-tenancy) is correctly deferred because building it delays the demo without adding demo value.

**Revisit:** v2 roadmap — add ARQ + Redis queue, then authentication.

*More decisions added as they are made.*
