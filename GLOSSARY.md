# Glossary

Quick reference for project-specific terms, patterns, and concepts.
Claude owns this file. Aria and Rex flag new entries; Claude writes them.

---

## Quick Reference

| Term | Category | Summary |
|---|---|---|
| `NodeSpec` | Model | Pydantic model defining a single node — its type, ports, code, config, and cache state |
| `Edge` | Model | A typed connection between a source port on one node and a target port on another |
| `Graph` | Model | The full graph: a list of `NodeSpec`s, a list of `Edge`s, and a `GraphState` |
| `GraphState` | Model | Enum: `EDIT` (modifiable) or `RUN` (frozen during execution) |
| `Port` | Model | A named, typed input or output on a node — `{name, type, required, default}` |
| `PortType` | Model | Enum of valid data types a port can carry: `string`, `number`, `boolean`, `any`, `prompt`, `completion`, `json` |
| `GraphDiff` | Model | A single proposed change from an agent: `{action, payload, agent, reason}` |
| `DiffBundle` | Model | A set of `GraphDiff`s the user approves or rejects together, with a summary |
| `DiffAction` | Model | Enum: `ADD_NODE`, `REMOVE_NODE`, `PATCH_NODE`, `ADD_EDGE`, `REMOVE_EDGE` |
| `NodeOutput` | Model | Execution result for one node: `{node_id, status, output, error, cached, duration_ms}` |
| `OrchestratorDecision` | Model | The orchestrator agent's routing decision: `{action, payload, response}` |
| Node agent | Agent | Fixes broken code in a failed node — produces a `PATCH_NODE` diff |
| Graph-writer agent | Agent | Builds pipelines from plain-language intent — produces `ADD_NODE` + `ADD_EDGE` diffs |
| Orchestrator agent | Agent | Reads graph + execution history + user message — decides which agent to delegate to |
| Nova | Agent | AI engineer — owns LangGraph agents, prompts, tool definitions, LLM node execution |
| Structured output | AI Engineering | Constraining an LLM's response to a Pydantic schema — prevents free-form text that fails unpredictably |
| `agents/prompts/` | Structure | Directory where Nova keeps all system prompts as separate Python files — not inlined in agent logic |
| Hallucination guard | AI Engineering | Validation that cross-checks agent output against known context before returning a diff |
| Context window budget | AI Engineering | Deciding exactly what goes into an agent's context — only what the model needs, nothing more |
| Few-shot example | AI Engineering | A concrete input/output example in a prompt — the highest-leverage part of a system prompt |
| DiffCard | UI | The React component shown when pending diffs exist — displays summary, reasons, Approve/Reject |
| `input_hash` | Execution | SHA-256 of a node's resolved inputs — used to skip unchanged nodes on re-run |
| `cached_output` | Execution | A node's last execution output — returned directly on cache hit |
| `agent_generated` | Node field | Boolean flag on `NodeSpec` — true if an agent created or last edited this node |
| Topological sort | Execution | Algorithm that orders nodes so every node executes after all its dependencies |
| RestrictedPython | Execution | Python sandbox that blocks dangerous builtins (`os`, `sys`, `open`) for safe node code execution |
| SSE | Transport | Server-Sent Events — one-directional HTTP streaming from server to browser, used for execution output |
| Diff protocol | Pattern | Agents produce diffs → API validates → user approves → graph updated + snapshot saved |
| Graph-as-conversation | Feature | The user types a goal in the chat panel; the graph-writer agent builds the graph live |
| `isNew` flag | UI | Temporary boolean on a node (2 seconds after addition) that triggers the entrance animation |
| Port type enforcement | UX | Incompatible port connections are rejected visually at the canvas level, not at runtime |
| Version snapshot | Storage | A full `Graph` JSON saved before every approved diff is applied — enables one-click rollback |
| Design token | UI | A named TypeScript constant in `theme.ts` mapping a semantic name to a Tailwind class string |

---

## Agent Terms

### Graph-writer agent
A LangGraph agent that takes a plain-language intent and the current graph state,
and produces a `DiffBundle` of `ADD_NODE` and `ADD_EDGE` diffs that build the described pipeline.
It never modifies the graph directly — it produces diffs for the user to approve.

### Node agent
A LangGraph agent invoked automatically when a node fails during execution.
It receives the failed node's spec, its error message, and the graph context,
and produces a `PATCH_NODE` diff with corrected Python code.

### Orchestrator agent
The top-level agent that routes between the other two. It reads the full graph,
execution history, and the user's message, and decides whether to delegate to the
node agent (fix a failure), the graph-writer (build/modify the graph), or respond
conversationally (clarify or explain).

---

## Execution Terms

### Topological sort
An algorithm that orders nodes in a directed acyclic graph such that every node
comes after all nodes it depends on (its input sources). In this project, it ensures
that a node never executes before the node feeding its inputs has completed.
If the graph has a cycle, a `ValueError` is raised before execution begins.

### Input hash cache
Each node stores the SHA-256 hash of its last resolved inputs. On re-run, if the
current inputs produce the same hash and a `cached_output` exists, the node is skipped
and the cached result is used. This prevents redundant LLM calls and expensive
re-computation when only part of the graph changes.

### RestrictedPython
A Python library that compiles and executes code in a restricted environment.
In this project, it blocks: `import os`, `import sys`, `open()`, `__import__`,
and other system-level access. Node code can use: string operations, math, json,
list and dict manipulation. Violations produce clear error messages naming the
blocked operation.

---

## Frontend Terms

### React Flow
The node graph library used for the canvas. Provides node rendering, edge routing,
connection validation, drag-and-drop, and pan/zoom. Custom nodes are React components
that receive `data` props from the graph store. Connection validation uses the
`isValidConnection` prop to enforce port type compatibility.

### Design token
A named TypeScript constant in `src/frontend/src/theme.ts` that maps a semantic name
to a Tailwind CSS utility class string. Used in component `className` props to ensure
all visual decisions are defined once and referenced by name everywhere.
Example: `NODE_STYLES.running = "border-blue-500 shadow-blue-500/20"`.

### DiffCard
The React component shown in the AI chat panel when the graph-writer or node agent
has proposed changes. Displays the diff summary, an expandable list of individual
diffs with agent-provided reasons, and Approve + Reject buttons. Designed to feel
like a smart assistant confirming a plan — not a security warning.

*More terms added as they are introduced.*
