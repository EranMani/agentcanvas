# Architecture & Data Flow

A living document. Updated as each phase is built.
Claude owns this file — Aria and Rex flag updates, Claude writes them.

---

## System Overview

```
Browser (React + React Flow)
        │
        │  REST (graph CRUD, agent chat, diff approve)
        │  SSE  (execution streaming)
        ▼
FastAPI Backend (Python 3.12)
        │
        ├── Graph Executor (topological sort + RestrictedPython sandbox)
        ├── Agent Runtime (LangGraph — orchestrator, node agent, graph-writer)
        └── JSON File Store (graphs saved as .json files)
```

---

## Graph State Machine

The graph has exactly two modes. Agents may only modify the graph in EDIT mode.

```
        ┌─────────────────────────────────────┐
        │              EDIT mode              │
        │  • User can add/remove/rewire nodes  │
        │  • Agents can propose diffs         │
        │  • Diffs can be approved/rejected   │
        └────────────────┬────────────────────┘
                         │  POST /run
                         ▼
        ┌─────────────────────────────────────┐
        │              RUN mode               │
        │  • Graph is frozen                  │
        │  • Node code executes in order      │
        │  • NodeOutput events stream via SSE │
        │  • No diffs accepted                │
        └────────────────┬────────────────────┘
                         │  execution complete or error
                         ▼
                     EDIT mode
```

---

## Node Data Model

Every node — hand-coded or agent-generated — conforms to `NodeSpec`.

| Field | Type | Purpose |
|---|---|---|
| `node_id` | UUID string | Unique instance identifier |
| `node_type` | string | "code", "llm_call", "input", "output", "agent" |
| `label` | string | Display name on canvas |
| `inputs` | Port[] | Typed input ports |
| `outputs` | Port[] | Typed output ports |
| `code` | string or null | Python source (code nodes only) |
| `config` | dict | Node parameters (model, temperature, etc.) |
| `input_hash` | string or null | SHA-256 of last inputs — drives cache skip |
| `cached_output` | dict or null | Last execution output |
| `agent_generated` | bool | Whether an agent created or last edited this node |
| `position` | {x, y} | Canvas coordinates |

---

## Port Type System

Port types enforce connection compatibility at the canvas level.
Incompatible connections are rejected visually before they are attempted.

| Type | Use case |
|---|---|
| `string` | Plain text |
| `number` | Numeric value |
| `boolean` | True/False |
| `any` | Untyped — connects to anything |
| `prompt` | AI-native: structured LLM prompt (string with intent) |
| `completion` | AI-native: LLM output text |
| `json` | Structured JSON object |

---

## Agent Diff Protocol

Agents never mutate the graph directly. They produce `GraphDiff` objects.

```
Agent produces GraphDiff(s)
        │
        ▼
DiffBundle assembled (with summary + reasons)
        │
        ▼
POST /graphs/{id}/diffs  ← stores as pending
        │
        ▼
DiffCard shown in UI  ← user reads reasons, approves or rejects
        │
        ├── Approve → POST /diffs/{bundle_id}/approve
        │              → API validates diffs (port types, node schema)
        │              → Graph updated
        │              → Snapshot saved to version history
        │
        └── Reject  → DELETE /diffs/{bundle_id}
                       → pending diffs cleared, graph unchanged
```

---

## Execution Pipeline

```
POST /graphs/{id}/run
        │
        ▼
Graph state → RUN (frozen)
        │
        ▼
Topological sort of nodes
        │
        ▼
For each node in order:
  ├── Compute input_hash from resolved inputs
  ├── If hash == node.input_hash AND cached_output exists → SKIP (emit cached)
  └── Else → execute node
        │
        ├── code node  → RestrictedPython sandbox
        ├── llm node   → LLM provider call (Anthropic or OpenAI)
        ├── input node → pass through user-provided value
        └── output node → surface result to canvas
        │
        ▼
NodeOutput emitted via SSE stream
        │
        ▼
Graph state → EDIT (on complete or error)
```

---

## Frontend Component Map

```
Editor.tsx (main layout)
├── TopBar
│   ├── GraphNameInput
│   ├── RunButton
│   ├── SaveButton
│   └── HistoryButton
├── NodePalette (left panel, w-64)
│   └── NodeTypeCard (per available type)
├── GraphCanvas (center, flex-1)
│   ├── ReactFlow
│   │   ├── BaseNode (custom node renderer)
│   │   │   ├── NodeHeader (type badge + label)
│   │   │   ├── PortHandle (per input/output)
│   │   │   └── NodeStatusBadge (running/complete/error/cached)
│   │   └── Background + Controls + MiniMap
│   └── OnboardingHint (dismissed after first node added)
└── RightPanel (w-80, context-sensitive)
    ├── NodeEditorPanel (when node selected)
    │   ├── NodeLabelInput
    │   └── MonacoEditor
    ├── AIChatPanel (when no node selected)
    │   ├── ChatHistory
    │   ├── DiffCard (when pendingDiffs exist)
    │   └── ChatInput
    └── VersionHistoryPanel (when history icon clicked)
        └── VersionCard (per snapshot)
```

*More sections added as phases are built.*
