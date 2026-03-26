# Commit Protocol — AgentCanvas

**39 atomic commits across 9 phases.**
Every step is owned by exactly one agent.
No step touches another agent's domain files.
Steps are ordered so every dependency is built before it is consumed.
Execute in order. No combining. No skipping.

---

## Ownership at a glance

| Agent | Owns | Commit signature |
|---|---|---|
| **Claude** | All project markdown (`CLAUDE.md`, `ARCHITECTURE.md`, `DECISIONS.md`, `GLOSSARY.md`, `TASKS.md`, `AGENTS.md`) — zero code files | `Co-Authored-By: Claude <claude@anthropic.com>` |
| **Rex** | All `src/backend/**` except agents — models, executor, storage, API routes, node registry, config | `Co-Authored-By: Rex <rex.stockagent@gmail.com>` |
| **Nova** | `src/backend/agents/**` + `src/backend/nodes/llm_node.py` — LangGraph agents, prompts, LLM node | `Co-Authored-By: Nova <nova.nodegraph@gmail.com>` |
| **Aria** | All `src/frontend/**` — React components, store, design tokens, hooks, API client | `Co-Authored-By: Aria <aria.stockagent@gmail.com>` |
| **Adam** | `.github/workflows/**`, `Makefile`, `.railway.toml`, `.env.example`, deployment config | `Co-Authored-By: Adam <adam.stockagent@gmail.com>` |

**Hard rule:** If a step's target files include anything outside the owner's domain —
stop, flag to Eran, do not proceed. Never fix a domain violation by having an agent
touch files they don't own.

---

## What was intentionally cut

The following were scoped out for the demo sprint. Do not re-introduce without Eran's approval.

- **Input hash cache** — adds complexity without changing the demo experience
- **Version history** (snapshot storage, history panel, restore) — v2 scope
- **Keyboard shortcuts** — v2 scope; demo does not depend on them
- **RUN mode guard as a separate step** — merged into the run endpoint (Step 20)

---

## Handoff markers

Each step that produces output another agent depends on ends with a `→ HANDOFF` line
naming the receiving agent and what they now have access to. The receiving agent
does not start their dependent step until they have read the producing agent's
worklog session and written receipt confirmation in their own.

---

## Phase 1 — Infrastructure & Local Dev (Steps 1–4)

*Goal: The project can be cloned and run locally in one command. CI catches regressions
from the first commit. Every env var is documented before anyone writes code that needs one.*

---

### Step 1 — `chore: add Makefile, .env.example, and confirm .gitignore`
**Owner:** Adam
**Touches:** `Makefile`, `.env.example`, `.gitignore`
**What happens:**
- `Makefile` targets: `make install` (uv sync + pnpm install), `make dev-backend` (uv run uvicorn on :8000),
  `make dev-frontend` (pnpm run dev on :5173), `make dev` (both in parallel), `make lint` (ruff + tsc --noEmit),
  `make test` (pytest), `make build-frontend` (pnpm run build in src/frontend)
- `.env.example`: all env vars the project will need — placeholder value + one-line comment per key:
  - `LLM_PROVIDER=anthropic` — which provider to use: `anthropic` or `openai`
  - `ANTHROPIC_API_KEY=sk-ant-...` — Anthropic Console → API Keys
  - `OPENAI_API_KEY=sk-...` — OpenAI Platform → API Keys
  - `GRAPHS_DIR=./data/graphs` — directory where graph JSON files are stored
  - `ERAN_API_KEY=` — owner's key used for demo free-tier calls; set in Railway secrets, never in repo
  - `FREE_USES_PER_SESSION=3` — free LLM calls per browser session before key modal appears
  - `FRONTEND_DIST_DIR=../frontend/dist` — compiled React build path served by FastAPI in production
  - `SLOWAPI_RATE_LIMIT=30/minute` — per-IP rate limit on LLM endpoints
- `.gitignore` review: confirm `.env`, `src/backend/.env`, `*.pyc`, `__pycache__/`, `node_modules/`,
  `dist/`, `.claude/settings.local.json`, `data/graphs/*.json` (demo.json is the exception — tracked) are excluded
**Acceptance:** `make install` completes. `.env.example` contains all 8 vars with comments.
`git status` shows no secrets staged.

---

### Step 2 — `chore: add GitHub Actions CI — lint and build on every push`
**Owner:** Adam
**Touches:** `.github/workflows/ci.yml`
**What happens:**
- Single workflow, two jobs — runs on push to `main` and on `pull_request`:
  - `backend`: Python 3.12, `uv sync`, `ruff check src/backend/`, `pytest src/backend/ -x --tb=short`
    (passes when test directory is empty — structure exists for future tests)
  - `frontend`: Node 20, `pnpm install`, `pnpm -C src/frontend exec tsc --noEmit`, `pnpm -C src/frontend run build`
    — catches TypeScript errors before they reach review
- Cache: uv pip cache + pnpm store for fast reruns
- Both jobs report independently — lint failure doesn't hide test result
**Acceptance:** Push to main → both CI jobs pass on a clean repo. Intentional TypeScript error → `frontend` job fails.

---

### Step 3 — `chore: initialize python backend with fastapi, uv, and settings`
**Owner:** Rex
**Touches:** `src/backend/pyproject.toml`, `src/backend/main.py`, `src/backend/config.py`
**What happens:**
- `uv init src/backend --python 3.12`
- `uv add fastapi "uvicorn[standard]" pydantic pydantic-settings python-dotenv langchain langgraph
  langchain-anthropic langchain-openai restrictedpython slowapi`
- `config.py`: `class Settings(BaseSettings)` with model_config pointing to `.env`:
  - `LLM_PROVIDER: str = "anthropic"`
  - `ANTHROPIC_API_KEY: str | None = None`
  - `OPENAI_API_KEY: str | None = None`
  - `GRAPHS_DIR: str = "./data/graphs"`
  - `ERAN_API_KEY: str | None = None`
  - `FREE_USES_PER_SESSION: int = 3`
  - `FRONTEND_DIST_DIR: str | None = None`
  - `SLOWAPI_RATE_LIMIT: str = "30/minute"`
  - Startup: if all three of ANTHROPIC_API_KEY, OPENAI_API_KEY, ERAN_API_KEY are None →
    logs a clear warning (does not crash — canvas testing works without keys)
- `main.py`: bare FastAPI app, CORS for `http://localhost:5173`, `GET /health → {"status": "ok", "version": "0.1.0"}`
**Acceptance:** `uv run uvicorn main:app --reload` starts. `/health` returns 200.
→ **HANDOFF to Aria:** Backend is live. Aria scaffolds the frontend.

---

### Step 4 — `chore: initialize react frontend with vite, typescript, and tailwind`
**Owner:** Aria
**Touches:** `src/frontend/package.json`, `src/frontend/vite.config.ts`, `src/frontend/tsconfig.json`,
`src/frontend/tailwind.config.ts`, `src/frontend/index.html`, `src/frontend/src/main.tsx`,
`src/frontend/src/App.tsx`
**What happens:**
- `pnpm create vite src/frontend --template react-ts`
- `pnpm add -D tailwindcss postcss autoprefixer`
- `pnpm add zustand @xyflow/react @monaco-editor/react`
- `npx tailwindcss init -p`
- `App.tsx`: `<div className="w-screen h-screen bg-gray-950 text-white">hello</div>`
- `vite.config.ts`: proxy `/api` → `http://localhost:8000` for dev convenience
**Acceptance:** `pnpm run dev` starts. Browser shows dark screen with "hello". No console errors.

> Steps 1–4 are infrastructure — no business logic yet. All agents reference `.env.example`
> as the single source of truth for required config.

---

## Phase 2 — Foundation Models (Steps 5–7)

*Goal: All Pydantic models exist and are locked. Nova, Aria, and Rex build against these shapes.*
*Rex works alone in this phase. No other agent touches code until Step 7 is complete.*

---

### Step 5 — `feat: define PortType enum and all graph Pydantic models`
**Owner:** Rex
**Touches:** `src/backend/models/__init__.py`, `src/backend/models/graph.py`
**What happens:**
- `PortType(str, Enum)`: `STRING`, `NUMBER`, `BOOLEAN`, `ANY`, `PROMPT`, `COMPLETION`, `JSON`,
  `EMBEDDING`, `DOCUMENT`, `CHUNK`
  - `EMBEDDING`: output of an Embeddings node — not compatible with PROMPT
  - `DOCUMENT`: raw document objects from a loader
  - `CHUNK`: split text chunks from a splitter
- `Port(BaseModel)`: `name: str`, `type: PortType`, `required: bool = True`, `default: Any = None`
- `NodeSpec(BaseModel)`: `node_id: str`, `node_type: str`, `label: str`, `inputs: list[Port]`,
  `outputs: list[Port]`, `code: str | None = None`, `config: dict[str, Any] = {}`,
  `agent_generated: bool = False`, `position: dict[str, float]`
- `Edge(BaseModel)`: `edge_id: str`, `source_node: str`, `source_port: str`,
  `target_node: str`, `target_port: str`
- `GraphState(str, Enum)`: `EDIT = "edit"`, `RUN = "run"`
- `Graph(BaseModel)`: `graph_id: str`, `name: str`, `state: GraphState = GraphState.EDIT`,
  `nodes: list[NodeSpec] = []`, `edges: list[Edge] = []`, `created_at: str`, `updated_at: str`
- `NodeOutput(BaseModel)`: `node_id: str`, `status: Literal["running","complete","error"]`,
  `output: dict[str, Any] | None = None`, `error: str | None = None`, `duration_ms: int | None = None`
**Acceptance:** `python -c "from models.graph import Graph, NodeOutput, PortType; print(PortType.EMBEDDING)"` runs cleanly.
→ **HANDOFF to Nova, Aria:** `NodeSpec`, `Graph`, `Edge`, `GraphState`, `NodeOutput`, and the new port types
(`EMBEDDING`, `DOCUMENT`, `CHUNK`) are finalised. Read Rex's worklog before any step that uses these models.

---

### Step 6 — `feat: define GraphDiff, DiffBundle (with narration), and OrchestratorDecision models`
**Owner:** Rex
**Touches:** `src/backend/models/diff.py`
**What happens:**
- `DiffAction(str, Enum)`: `ADD_NODE`, `REMOVE_NODE`, `PATCH_NODE`, `ADD_EDGE`, `REMOVE_EDGE`
- `GraphDiff(BaseModel)`:
  - `action: DiffAction`
  - `payload: dict[str, Any]`
  - `agent: str`
  - `reason: str = Field(description="Teaching-voice explanation of why this diff serves the goal")`
- `DiffBundle(BaseModel)`:
  - `bundle_id: str`
  - `diffs: list[GraphDiff]`
  - `summary: str = Field(description="One-sentence summary of what this bundle does")`
  - `narration: str | None = Field(default=None, description="2–3 sentences in the voice of a senior AI engineer explaining the architectural reasoning behind this graph structure. Generated by a second LLM call after structured diffs are locked. May be None if the second call fails — diffs are still valid.")`
- `OrchestratorDecision(BaseModel)`:
  - `action: Literal["fix_node","build_graph","respond"]`
  - `payload: dict[str, Any] = {}`
  - `response: str`
**Acceptance:** Invalid `DiffAction` raises `ValidationError`. `DiffBundle` with `narration=None` is valid.
`DiffBundle.narration` accepts a multi-sentence string.
→ **HANDOFF to Nova, Aria:** All agent I/O shapes are locked. `DiffBundle.narration` is the teaching-voice
field — Nova populates it via a second LLM call in the graph-writer; Aria renders it in the chat panel.
No field changes after this commit without Eran's approval.

---

### Step 7 — `feat: define 12-node type registry with explanation, example, and category fields`
**Owner:** Rex
**Touches:** `src/backend/nodes/__init__.py`, `src/backend/nodes/types.py`, `src/backend/nodes/registry.py`
**What happens:**
- `NodeCategory(str, Enum)`:
  - `RETRIEVAL = "retrieval"`
  - `GENERATION = "generation"`
  - `CONTROL_FLOW = "control_flow"`
  - `MEMORY_TOOL = "memory_tool"`
- `NodeTypeDefinition(BaseModel)`:
  - `node_type: str`
  - `label: str`
  - `description: str`
  - `category: NodeCategory`
  - `default_inputs: list[Port]`
  - `default_outputs: list[Port]`
  - `has_code: bool`
  - `icon: str` — icon name string; Aria maps to SVG in CategoryIcon.tsx
  - `explanation: str` — senior AI engineer voice (placeholder text in this commit; **Eran reviews and
    approves all explanation content before the demo — this is the product's voice**)
  - `example: str` — minimal runnable code or config snippet (same review applies)
- `REGISTRY: dict[str, NodeTypeDefinition]` — 12 entries:
  1. `llm_call` — GENERATION — inputs: [prompt: PROMPT, system: STRING(required=False)] — outputs: [completion: COMPLETION, tokens_used: NUMBER]
  2. `prompt_template` — GENERATION — inputs: [variables: JSON] — outputs: [prompt: PROMPT]
  3. `document_loader` — RETRIEVAL — inputs: [source: STRING] — outputs: [documents: DOCUMENT]
  4. `text_splitter` — RETRIEVAL — inputs: [documents: DOCUMENT] — outputs: [chunks: CHUNK]
  5. `embeddings` — RETRIEVAL — inputs: [chunks: CHUNK] — outputs: [embeddings: EMBEDDING]
  6. `vector_store` — RETRIEVAL — inputs: [embeddings: EMBEDDING, query: STRING(required=False)] — outputs: [results: JSON]
  7. `output_parser` — GENERATION — inputs: [completion: COMPLETION] — outputs: [parsed: JSON]
  8. `conditional_router` — CONTROL_FLOW — inputs: [value: ANY, condition: STRING] — outputs: [true_branch: ANY, false_branch: ANY]
  9. `memory` — MEMORY_TOOL — inputs: [message: STRING, history: JSON(required=False)] — outputs: [history: JSON]
  10. `tool_call` — MEMORY_TOOL — inputs: [prompt: PROMPT, tools: JSON] — outputs: [result: JSON]
  11. `human_checkpoint` — CONTROL_FLOW — inputs: [value: ANY] — outputs: [approved: ANY]
  12. `entry_exit` — CONTROL_FLOW — inputs: [value: ANY(required=False)] — outputs: [value: ANY(required=False)], config: {mode: "entry"|"exit"}
- `def get_node_type(node_type: str) -> NodeTypeDefinition` — raises `KeyError` with message listing available types
- `def list_node_types() -> list[NodeTypeDefinition]`
**Acceptance:** `list_node_types()` returns 12. `get_node_type("unknown")` raises descriptive `KeyError`.
→ **HANDOFF to Nova, Aria:** Registry locked. Nova's graph-writer uses `list_node_types()` for context.
Aria reads `category`, `icon`, `explanation`, `example` for the visual language and explanation panel.
`NodeCategory` enum values are the four valid category strings.

---

## Phase 3 — Canvas, Store & API Shell (Steps 8–15)

*Goal: Nodes exist on a canvas. The store manages state. The API saves and loads graphs.*
*Rex builds the storage and API layer (Steps 13–14). Aria builds everything visual (Steps 8–12, 15).*
*Nova is not involved in Phase 3.*

---

### Step 8 — `feat: create design token system and three-panel editor shell`
**Owner:** Aria
**Touches:** `src/frontend/src/theme.ts`, `src/frontend/src/pages/Editor.tsx`, `src/frontend/src/App.tsx`
**What happens:**
- `theme.ts`: every visual constant for the project —
  - `COLOURS`: backgrounds, borders, text, node status (running=blue, complete=green, error=red),
    `NODE_CATEGORY_COLOURS` (retrieval=blue, generation=violet, control_flow=amber, memory_tool=teal)
  - `TYPOGRAPHY`, `SPACING`, `RADIUS`, `SHADOW`, `TRANSITIONS`
  - `NODE_STYLES`, `PANEL_STYLES`
  - Zero Tailwind strings live in any component file — every class string is derived from `theme.ts`
- `Editor.tsx`: three empty panels — left sidebar (`w-64`), canvas (`flex-1`), right panel (`w-80`).
  Dark palette consistent with `COLOURS`.
- `App.tsx` renders `<Editor />`
**Acceptance:** `pnpm run dev` shows three-panel dark layout. No errors.
→ **HANDOFF to Aria (self):** Token system established. All subsequent Aria steps use `theme.ts` exclusively.

---

### Step 9 — `feat: implement Zustand graph store with node and edge state`
**Owner:** Aria
**Touches:** `src/frontend/src/store/graphStore.ts`, `src/frontend/src/store/types.ts`
**What happens:**
- `store/types.ts`: TypeScript mirrors of Rex's models — `NodeSpec`, `Edge`, `Graph`, `GraphState`,
  `NodeOutput`, `DiffBundle`, `OrchestratorDecision`, `GraphDiff`, `DiffAction`, `NodeCategory`
- `graphStore.ts` (Zustand): state —
  - `nodes: NodeSpec[]`, `edges: Edge[]`, `graphId: string | null`, `graphName: string`
  - `graphState: 'edit'|'run'`
  - `selectedNodeId: string | null`
  - `pendingDiffs: DiffBundle | null`
  - `executionOutputs: Record<string, NodeOutput>`
- Actions: `addNode`, `removeNode`, `patchNode` (partial update by `node_id`), `addEdge`, `removeEdge`,
  `setGraphState`, `setSelectedNode`, `setPendingDiffs`, `applyDiffBundle`, `rejectDiffBundle`,
  `setNodeOutput`, `loadGraph`
- `applyDiffBundle`: sets `agent_generated: true` on all ADD_NODE nodes. Sets transient `isNew: true`
  (cleared after 1500ms via `setTimeout`) — Aria reads `isNew` in BaseNode and ExplanationPanel.
**Acceptance:** `addNode()` → node in store. `removeNode()` → gone. `applyDiffBundle({ADD_NODE, ADD_EDGE})`
adds node then edge in correct order. `graphState` starts `'edit'`.

---

### Step 10 — `feat: build React Flow canvas with typed port handles and connection validation`
**Owner:** Aria
**Touches:** `src/frontend/src/components/canvas/GraphCanvas.tsx`,
`src/frontend/src/components/nodes/BaseNode.tsx`,
`src/frontend/src/components/nodes/PortHandle.tsx`
**What happens:**
- `GraphCanvas.tsx`: `<ReactFlow>` with `snapToGrid`, `Background`, `Controls`, `MiniMap`. Reads
  `nodes`, `edges` from store. `onNodesChange`/`onEdgesChange` dispatch to store.
  `onNodeClick` → `setSelectedNode`. `isValidConnection` enforces port type rules.
- `PortHandle.tsx`: React Flow `Handle` — coloured dot per `PortType` mapped from `theme.ts`.
  `data-port-type` attribute on each handle.
- `BaseNode.tsx`:
  - Node header: 3px left border tinted by `NODE_CATEGORY_COLOURS[category]`, type badge, label
  - Input handles left, output handles right
  - Execution status ring: idle=grey, running=blue+`animate-pulse`, complete=green, error=red+tooltip on hover
  - `isNew` → `ring-2 ring-indigo-400 animate-pulse` for 1500ms (via store timeout)
  - `agent_generated` → "✦ AI" badge in header (`text-xs text-indigo-400`)
  - All styles from `theme.ts`
- Port compatibility rules:
  - `ANY` ↔ anything
  - `EMBEDDING` ↔ `EMBEDDING` only
  - `DOCUMENT` ↔ `DOCUMENT` only
  - `CHUNK` ↔ `CHUNK` only
  - `PROMPT` ↔ `PROMPT` only
  - `COMPLETION` ↔ `COMPLETION` or `ANY`
  - Others: exact type match
**Acceptance:** Dummy node in store appears on canvas with category-tinted left border. Incompatible
port connection shows red ✕ and does not create an edge.

---

### Step 11 — `feat: build node palette sidebar with category grouping and drag-to-canvas`
**Owner:** Aria
**Touches:** `src/frontend/src/components/panels/NodePalette.tsx`
**What happens:**
- Hardcoded 12-entry node type list (replaced with live API in Step 15)
- Nodes grouped into four category sections with header labels:
  - **Retrieval**: Document Loader, Text Splitter, Embeddings, Vector Store
  - **Generation**: LLM Call, Prompt Template, Output Parser
  - **Control Flow**: Conditional Router, Human-in-the-Loop, Entry/Exit
  - **Memory & Tools**: Memory/Chat History, Tool/Function Call
- Category header accent uses `NODE_CATEGORY_COLOURS`
- Draggable card per type: icon placeholder + label + description. `onDragStart` sets `nodeType` in event data.
- `GraphCanvas.tsx` `onDrop`: reads `nodeType`, calls `addNode()` with new `NodeSpec` at drop position.
  Port definitions copied from registry shape.
- Empty state: "Drag a node onto the canvas to start building"
- All styles from `theme.ts`
**Acceptance:** Four category groups visible. Dragging any card onto canvas creates a node at the drop position.

---

### Step 12 — `feat: build node editor panel with Monaco code editor`
**Owner:** Aria
**Touches:** `src/frontend/src/components/panels/NodeEditorPanel.tsx`
**What happens:**
- Right panel renders this component when `selectedNodeId` is set (and no explanation panel is open)
- Editable label at top: `<input>` → `patchNode({label: value})`
- Code nodes: Monaco editor bound to `node.code`. Python language, dark theme, `fontSize: 13`, no minimap.
  `onChange` → `patchNode({code: value})`
- Non-code nodes: "This node is configured, not coded" with key/value config view
- LLM nodes: "Config available — see Step 33" placeholder
- `entry_exit` nodes: editable "value" field for entry mode; read-only for exit mode
- Empty state: "Select a node to edit"
- All styles from `theme.ts`
**Acceptance:** Code node → Monaco editor. Non-code node → config view. Nothing selected → empty state.

---

### Step 13 — `feat: implement graph storage, REST endpoints, and API key resolution dependency`
**Owner:** Rex
**Touches:** `src/backend/storage/__init__.py`, `src/backend/storage/graph_store.py`,
`src/backend/api/__init__.py`, `src/backend/api/dependencies.py`,
`src/backend/api/routes.py`, `src/backend/main.py`
**What happens:**
- `graph_store.py`: `save_graph`, `load_graph`, `list_graphs`, `delete_graph` —
  reads/writes `{GRAPHS_DIR}/{graph_id}.json`. Creates directory on startup if absent.
- `routes.py`: `GET /graphs`, `GET /graphs/{id}`, `POST /graphs`, `PUT /graphs/{id}`,
  `DELETE /graphs/{id}`, `GET /node-types` (calls `list_node_types()`)
- `dependencies.py`:
  - `resolve_api_key(x_user_api_key: str | None = Header(default=None)) -> str`:
    - If `X-User-API-Key` header present → return it
    - Else if `settings.ERAN_API_KEY` is set → return it
    - Else → raise `HTTPException(401, "No API key available. Provide X-User-API-Key header or configure ERAN_API_KEY on the server.")`
  - This dependency is applied only to LLM-calling endpoints (Step 26) — not to graph CRUD
  - `require_edit_mode` defined here too (see Step 14)
- `main.py`: `app.include_router(router)`. Slowapi limiter initialised:
  `limiter = Limiter(key_func=get_remote_address)` — rate decorator applied to LLM endpoints in Step 26.
**Acceptance:** `POST /graphs` creates a file. `GET /node-types` returns 12 entries.
`resolve_api_key` with no header and no `ERAN_API_KEY` → 401 with clear message.
→ **HANDOFF to Aria:** Graph CRUD and `/node-types` are live. Aria wires the frontend in Step 15.

---

### Step 14 — `feat: add require_edit_mode dependency — block mutations during execution`
**Owner:** Rex
**Touches:** `src/backend/api/dependencies.py`, `src/backend/api/routes.py`
**What happens:**
- `dependencies.py` addition:
  `require_edit_mode(graph_id: str) -> Graph`:
  - Loads graph from store
  - If `graph.state == GraphState.RUN` → raises `HTTPException(409, "Graph is currently running — mutations are blocked until execution completes")`
  - Returns the loaded graph so routes can reuse it without a second disk read
- Applied to: `PUT /graphs/{id}`, `POST /graphs/{id}/diffs/{bid}/approve`,
  `DELETE /graphs/{id}/diffs/{bid}`, `POST /graphs/{id}/chat`, second `POST /graphs/{id}/run`

**Why separate from Step 13:** Step 13 ships the positive path. Step 14 is the safety guard.
If the guard logic is too aggressive and needs rollback, Step 13's working CRUD is untouched.

**Acceptance:** `PUT /graphs/{id}` while `state=RUN` → 409 with message. Same endpoint in `state=EDIT` → 200.

---

### Step 15 — `feat: wire frontend save/load, palette, and URL sync to live API`
**Owner:** Aria
**Touches:** `src/frontend/src/api/graphApi.ts`, `src/frontend/src/api/apiClient.ts`,
`src/frontend/src/hooks/useGraphSync.ts`, `src/frontend/src/pages/Editor.tsx`,
`src/frontend/src/components/panels/NodePalette.tsx`
**What happens:**
- `apiClient.ts`: base fetch wrapper. Reads `sessionStorage.getItem('ac_user_key')` — attaches as
  `X-User-API-Key` header if present (key is stored in Step 31, but the header injection lives here from day one)
- `graphApi.ts`: typed wrappers — `saveGraph`, `loadGraph`, `listGraphs`, `listNodeTypes`
- `useGraphSync.ts`: `useSaveGraph()`, `useLoadGraph()` hooks
- `Editor.tsx` top bar: "Save" button, "Load" dropdown, graph name input
- `NodePalette.tsx` updated: `useEffect` calls `listNodeTypes()` → replaces hardcoded 12 from Step 11.
  Category grouping preserved from API response `category` field.
- URL sync: graph ID in `?g=` query param. On load, reads `?g=`, calls `loadGraph(id)`, dispatches to store.
**Acceptance:** Save → reload with `?g=` param → graph reappears with all nodes and edges.
Palette populated from live `/node-types`. Four category groups intact.

---

## Phase 4 — Teaching Layer (Steps 16–17)

*Goal: Every node teaches as it lands. The explanation panel opens automatically when an agent
places a node. Developers who already know it skip it; developers who don't get exactly
what they need — without walls of text.*

*Both steps are Aria. They depend on `NodeTypeDefinition.explanation`/`example` (Step 7)
and the `isNew` flag in the store (Step 9).*

---

### Step 16 — `feat: build explanation panel — auto-opens when agent places a node`
**Owner:** Aria
**Touches:** `src/frontend/src/components/panels/ExplanationPanel.tsx`,
`src/frontend/src/components/panels/NodeEditorPanel.tsx`,
`src/frontend/src/pages/Editor.tsx`
**What happens:**
- `ExplanationPanel.tsx`:
  - Three sections: **"What is it?"** (renders `node_type.explanation`),
    **"Example"** (`node_type.example` in a `<pre>` monospace block — no Monaco, not interactive)
  - Coloured header accent using `NODE_CATEGORY_COLOURS[category]`
  - "Got it →" dismiss button collapses the panel immediately
  - Auto-dismiss: 4 seconds of no hover/interaction → collapse animation
  - Shown when `isNew` is true on the selected node AND `node_type.explanation` is non-empty
- Right panel logic (in `Editor.tsx` or `NodeEditorPanel.tsx`):
  when `isNew` on selected node → show `<ExplanationPanel>`;
  otherwise → show `<NodeEditorPanel>`
- All styles from `theme.ts`
**Acceptance:** Approve a diff → new node is auto-selected → right panel shows ExplanationPanel.
Auto-dismisses in 4s. "Got it →" dismisses immediately. Selecting an older node shows NodeEditorPanel.

---

### Step 17 — `feat: add node category visual language — icons and color accents per category`
**Owner:** Aria
**Touches:** `src/frontend/src/components/nodes/CategoryIcon.tsx`,
`src/frontend/src/components/nodes/BaseNode.tsx`,
`src/frontend/src/components/panels/NodePalette.tsx`
**What happens:**
- `CategoryIcon.tsx`: small SVG icon component — one icon per `NodeCategory`:
  - `retrieval` → database/stack icon
  - `generation` → sparkles icon
  - `control_flow` → git-branch icon
  - `memory_tool` → chip/memory icon
  - Sized 14×14px, coloured from `NODE_CATEGORY_COLOURS`. No external icon library — inline SVG paths.
- `BaseNode.tsx` updated:
  - `<CategoryIcon>` in node header before the label
  - Subtle category-tinted background: 5% opacity tint so category is readable at a glance without being garish
  - 3px left border already added in Step 10 — confirm it uses `NODE_CATEGORY_COLOURS`
- `NodePalette.tsx` updated: `<CategoryIcon>` shown in each palette card; category section headers use full category colour
- All category colours controlled exclusively via `theme.ts` — zero hardcoded colour strings anywhere
**Acceptance:** Four categories visually distinct on canvas and in palette.
Retrieval=blue, Generation=violet, Control Flow=amber, Memory/Tool=teal.
Icons appear in both palette and canvas nodes.

---

## Phase 5 — Execution Engine (Steps 18–21)

*Goal: Node code executes safely. Results stream live to the canvas.*
*Rex builds the full execution stack (Steps 18–20). Aria connects the UI (Step 21).*
*Nova is not involved in Phase 5.*

---

### Step 18 — `feat: implement RestrictedPython sandbox for safe node code execution`
**Owner:** Rex
**Touches:** `src/backend/executor/__init__.py`, `src/backend/executor/sandbox.py`
**What happens:**
- `execute_code_node(code: str, inputs: dict[str, Any]) -> dict[str, Any]`
- RestrictedPython compiles and runs in restricted environment. `inputs` available as variable.
  Code must assign `outputs` dict.
- Blocked: `import os`, `import sys`, `open()`, `__import__`, `exec`, `eval`, any `__builtins__` override
- `SandboxViolation(message: str)` — message names the blocked operation:
  e.g. `"'os' import is blocked — system imports are disabled in node code"`
- 10-second timeout via `threading.Timer` → `TimeoutError("Node execution exceeded 10s limit")`
**Acceptance:** `outputs = {"x": inputs["n"] * 2}` works. `import os` raises `SandboxViolation` with
clear message. 15-second sleep raises `TimeoutError`.

---

### Step 19 — `feat: implement topological sort executor with input resolution`
**Owner:** Rex
**Touches:** `src/backend/executor/runner.py`
**What happens:**
- `topological_sort(graph: Graph) -> list[NodeSpec]` — Kahn's algorithm.
  `ValueError("Cycle detected involving nodes: {ids}")` on cycle.
- `resolve_inputs(node: NodeSpec, graph: Graph, completed_outputs: dict) -> dict` — walks edges to
  resolve each input port's value from upstream outputs. Missing required input →
  `ValueError(f"Required input '{port.name}' on node '{node.node_id}' has no upstream connection")`
- `async def execute_graph(graph: Graph, api_key: str | None = None) -> AsyncIterator[NodeOutput]`:
  - Topological sort → for each node in order:
    `resolve_inputs` → yield `NodeOutput(status="running")` → execute → yield `NodeOutput(status="complete" or "error")`
  - `code` nodes: `execute_code_node()`
  - `entry_exit` (entry): passes `config.get("value", "")` as `{"value": ...}`
  - `entry_exit` (exit): yields its input value as output
  - `llm_call` nodes: raises `NotImplementedError("LLM node execution added in Step 26")` — placeholder
  - All other node types: raises `NotImplementedError(f"Node type '{node.node_type}' not yet implemented")`
  - No caching — deliberately omitted for demo scope
**Acceptance:** 3-node graph (entry→code→exit) executes in order. Code node receives entry's output.
Cycle detection raises correctly.
→ **HANDOFF to Rex (self → Step 20):** `execute_graph()` async iterator is the SSE integration point.

---

### Step 20 — `feat: add graph run endpoint, SSE streaming, and RUN mode guard`
**Owner:** Rex
**Touches:** `src/backend/api/routes.py`, `src/backend/api/sse.py`
**What happens:**
- `sse.py`: `format_sse(event: str, data: dict) -> str` — `f"event: {event}\ndata: {json.dumps(data)}\n\n"`
- `routes.py` additions:
  - `ACTIVE_RUNS: dict[str, AsyncIterator[NodeOutput]]` — module-level
  - `POST /graphs/{graph_id}/run`:
    - Loads graph; if `state == RUN` → 409 ("already running")
    - Sets `state = RUN`, saves, creates `execute_graph(graph, api_key=None)` iterator (api_key wired in Step 26),
      stores in `ACTIVE_RUNS`, returns `{"run_id": uuid}`
  - `GET /runs/{run_id}/stream`:
    - `StreamingResponse(media_type="text/event-stream", headers={"X-Accel-Buffering": "no"})`
    - Iterates stored iterator, yields each `NodeOutput` as SSE event `"node_output"`
    - Final event: `"complete"` with `{"run_id": ...}`
    - On completion: sets graph `state = EDIT`, saves graph
  - `POST /runs/{run_id}/cancel` — removes from `ACTIVE_RUNS`, sets `state = EDIT`, saves
- `X-Accel-Buffering: no` on all SSE responses — prevents Railway/nginx proxy from buffering the stream
**Acceptance:** `POST /run` → `run_id`. `GET /stream` yields one event per node. Stream closes after
final event. Graph returns to EDIT. Second `POST /run` while running → 409.
→ **HANDOFF to Aria:** `/run` and `/stream` are live. Aria wires them to the canvas in Step 21.

---

### Step 21 — `feat: connect SSE stream to canvas with live node status rendering`
**Owner:** Aria
**Touches:** `src/frontend/src/hooks/useExecution.ts`,
`src/frontend/src/components/nodes/BaseNode.tsx`,
`src/frontend/src/pages/Editor.tsx`
**What happens:**
- `useExecution.ts`: `useRunGraph(graphId)` hook:
  - `POST /run` → `run_id`
  - `EventSource` on `GET /runs/{run_id}/stream`
  - Each `node_output` event → `setNodeOutput(nodeId, output)` on store
  - `complete` event → `setGraphState('edit')`
  - Returns `{runGraph, isRunning, cancelRun, error}`
- `BaseNode.tsx` execution state (reads `executionOutputs[node_id]`):
  - no output → grey ring (idle)
  - `running` → blue ring + `animate-pulse`
  - `complete` → green ring
  - `error` → red ring + error message tooltip on hover
- `Editor.tsx` top bar: "Run" button → `runGraph()`. "Cancel" visible during run.
  "Running…" label + spinner while active. Both disabled correctly.
- All styles from `theme.ts`
**Acceptance:** Run lights up nodes in order. Error shows red ring with tooltip. Cancel stops the stream.
Completed nodes stay green.

---

## Phase 6 — Agent Runtime (Steps 22–31)

*Goal: Agents build graphs. Agents fix broken code. The teaching-voice narration renders in the chat
panel. The self-modifying loop works end-to-end.*

*Nova builds all agents first (Steps 22–25). Rex integrates LLM and wires agent endpoints (Steps 26–27).
Aria builds all agent UI last (Steps 28–31). This ordering is strict — do not reorder.*

---

### Step 22 — `feat: implement node agent — fixes failed node code via PATCH_NODE diff`
**Owner:** Nova
**Touches:** `src/backend/agents/__init__.py`, `src/backend/agents/prompts/__init__.py`,
`src/backend/agents/prompts/node_agent.py`, `src/backend/agents/node_agent.py`
**What happens:**
- `prompts/node_agent.py`: role → task → constraints → output format.
  Constraints: "Do NOT change port names — the port contract is fixed",
  "Do NOT add imports that were not in the original code unless they are pure-Python builtins",
  "The fixed code must assign an `outputs` dict".
  One concrete few-shot example: TypeError on undefined variable → corrected code.
- `node_agent.py`: LangGraph state machine:
  - State: `{node: NodeSpec, error: str, graph_context: str, api_key: str, result: GraphDiff | None, attempts: int}`
  - Flow: `read_context` → `generate_fix` → `validate_fix` → (retry once on failure) → `END`
  - `generate_fix`: LLM with `.with_structured_output(GraphDiff)`
  - `validate_fix`: `action == PATCH_NODE` ✓, `payload["node_id"]` matches ✓,
    `compile()` on new code ✓, port names unchanged ✓
  - Max 1 retry. Second failure → error `GraphDiff(reason="Agent could not produce a valid fix after 2 attempts: {error}")`
  - `api_key` passed to LLM instantiation — not pulled from global settings
- `async def fix_node(node: NodeSpec, error: str, graph: Graph, api_key: str) -> GraphDiff`
**Acceptance:** Node with `outputs = {"x": undefined_var}` → diff with corrected code. `compile(diff.payload["code"])` passes. Port names unchanged.
→ **HANDOFF to Nova (self → Step 23):** Pattern established. Graph-writer follows same LangGraph structure.

---

### Step 23 — `feat: implement graph-writer agent — builds pipelines from intent with teaching narration`
**Owner:** Nova
**Touches:** `src/backend/agents/prompts/graph_writer.py`, `src/backend/agents/graph_writer.py`
**What happens:**
- `prompts/graph_writer.py`:
  - System prompt constraints: "ONLY use node_types from the provided list", "NEVER invent port names —
    use only ports from the node type definition", "max 8 nodes per bundle",
    "position nodes at y=200, x spaced 260px apart starting from x=100"
  - One complete few-shot example: "double a number" → 3 ADD_NODE + 2 ADD_EDGE diffs
  - Narration prompt (second call, appended as user message): "You have assembled the following graph:
    {diffs_summary}. In 2–3 sentences, explain *why* this structure serves the user's goal. Write in
    the voice of a senior AI engineer giving genuine advice — explain the architectural reason for
    each component, not just what it does. Do NOT describe what nodes are; explain why they belong here."
- `graph_writer.py`: **Two-call architecture**
  - State: `{intent, current_graph, available_types, result: DiffBundle | None, api_key: str}`
  - Flow: `build_context` → `generate_bundle` → `validate_bundle` → `generate_narration` → `END`
  - `build_context`: formats `available_types` as compact JSON (node_type, description, port names only —
    not full `NodeTypeDefinition`; context must be tight)
  - `generate_bundle`: LLM call 1 — `.with_structured_output(DiffBundle)` — produces structured diffs,
    `narration=None`
  - `validate_bundle`: every ADD_NODE → node_type in registry; every port reference → port name exists
    on that type; every ADD_EDGE → both node IDs present in ADD_NODEs. Assigns sequential x positions.
  - `generate_narration`: LLM call 2 — plain call with narration prompt → free-text string assigned
    to `result.narration`. **If this call fails, `result.narration = None` — not a blocking failure.
    Diffs are always returned even when narration fails.**
- `async def build_graph(intent: str, current_graph: Graph, available_types: list, api_key: str) -> DiffBundle`
**Acceptance:** Intent "build a RAG pipeline" → `DiffBundle` with 5–7 ADD_NODE + edges. All port names
valid against registry. `narration` is a 2–3 sentence teaching explanation (or None on failure).
→ **HANDOFF to Nova (self → Step 24):** Both sub-agents ready. Orchestrator can now delegate.

---

### Step 24 — `feat: implement orchestrator agent — reads graph state and delegates`
**Owner:** Nova
**Touches:** `src/backend/agents/prompts/orchestrator.py`, `src/backend/agents/orchestrator.py`,
`src/backend/agents/tools.py`
**What happens:**
- `tools.py`: context builders (not LLM tools):
  - `format_graph_summary(graph: Graph) -> str` — compact: node types + edge list as "A.port → B.port"
  - `format_execution_summary(outputs: list[NodeOutput]) -> str` — node → status + error message if any
- `prompts/orchestrator.py`: role, routing rules:
  `fix_node` if error nodes exist AND user implies fix;
  `build_graph` if user describes a structural goal;
  `respond` for questions/comments. `response` always required.
- `orchestrator.py`: LangGraph state machine:
  - State: `{graph, user_message, execution_history, api_key, decision: OrchestratorDecision | None}`
  - Flow: `summarise_context` → `decide` → `END`
  - `summarise_context`: calls both format functions, assembles context string
  - `decide`: LLM with `.with_structured_output(OrchestratorDecision)`
- `async def run_orchestrator(graph: Graph, user_message: str, execution_history: list[NodeOutput], api_key: str) -> OrchestratorDecision`
**Acceptance:** Failed node + "fix it" → `action="fix_node"`. "Add a JSON formatter" → `action="build_graph"`. "What does this do?" → `action="respond"`.
→ **HANDOFF to Rex:** All three agents have stable async signatures. `api_key` explicit through every call. Rex wires these in Steps 26–27.
→ **HANDOFF to Aria:** `DiffBundle.narration` is the teaching-voice field to render. `OrchestratorDecision.response` is the conversational reply. Read Nova's worklog for Steps 22–24 before starting Step 28.

---

### Step 25 — `feat: implement LLM node execution — calls AI provider from within the graph`
**Owner:** Nova
**Touches:** `src/backend/nodes/llm_node.py`
**What happens:**
- `async def execute_llm_node(node: NodeSpec, inputs: dict[str, Any], api_key: str) -> dict[str, Any]`
  - Reads `node.config`: `model`, `temperature` (default 0.7), `max_tokens` (default 512),
    `system_prompt` (optional)
  - Reads `inputs["prompt"]` (required), `inputs.get("system", "")` (optional override)
  - Provider from `settings.LLM_PROVIDER`:
    `anthropic` → `AsyncAnthropic(api_key=api_key)`;
    `openai` → `AsyncOpenAI(api_key=api_key)`
  - Returns `{"completion": text, "tokens_used": total_tokens}`
  - Error cases — never raise, always return error dict:
    - missing key → `{"error": "API key not configured — add ERAN_API_KEY to server env or provide X-User-API-Key"}`
    - rate limit → `{"error": "Rate limit hit — wait 60s and retry"}`
    - timeout after 30s → `{"error": "LLM call timed out after 30s"}`
**Acceptance:** Valid prompt + key → `{"completion": "...", "tokens_used": N}`. Missing key → error dict (no exception raised). Provider selected from settings.
→ **HANDOFF to Rex:** `execute_llm_node(node, inputs, api_key)` is ready. Rex integrates it in Step 26.

---

### Step 26 — `feat: integrate LLM node into executor and wire all agent API endpoints`
**Owner:** Rex
**Touches:** `src/backend/executor/runner.py`, `src/backend/api/routes.py`
**What happens:**
- `runner.py`: integrate `execute_llm_node` for `llm_call` nodes:
  `output = await execute_llm_node(node, resolved_inputs, api_key)`.
  `api_key` threaded through `execute_graph(graph, api_key)` call signature.
  Removes `NotImplementedError` placeholder.
- `routes.py` — agent endpoints:
  - Module-level: `PENDING_DIFFS: dict[str, DiffBundle]`, `RUN_HISTORY: dict[str, list[NodeOutput]]`
  - `GET /runs/{run_id}/stream` updated: on completion, saves full `NodeOutput` list to `RUN_HISTORY[graph_id]`
  - `POST /graphs/{graph_id}/run` updated: passes `api_key` to `execute_graph(graph, api_key)`
    (uses `resolve_api_key` dependency — applied here now)
  - `POST /graphs/{graph_id}/chat`
    (with `resolve_api_key` dependency + `@limiter.limit(settings.SLOWAPI_RATE_LIMIT)` + `require_edit_mode`):
    - Loads graph + history from `RUN_HISTORY`
    - `run_orchestrator(graph, message, history, api_key)` → `OrchestratorDecision`
    - If `fix_node`: `fix_node(failed_node, error, graph, api_key)` → wrapped in `DiffBundle` → stored in `PENDING_DIFFS`
    - If `build_graph`: `build_graph(message, graph, list_node_types(), api_key)` → stored in `PENDING_DIFFS`
    - Adds `bundle_id` to `OrchestratorDecision.payload` when applicable
    - Returns `OrchestratorDecision`
  - `POST /graphs/{graph_id}/diffs/{bundle_id}/approve` (with `require_edit_mode`):
    - Validates: ADD_NODE → schema check; ADD_EDGE → port type compatibility
    - Applies diffs in order: ADD_NODE first, then ADD_EDGE, then PATCH_NODE, then REMOVE_*
    - Returns updated `Graph`
  - `DELETE /graphs/{graph_id}/diffs/{bundle_id}` → removes from `PENDING_DIFFS`, 204
**Acceptance:** `POST /chat "add a node that doubles the input"` → `OrchestratorDecision` with `bundle_id`.
`POST /approve` → graph updated with new nodes. `/approve` with incompatible port types → 422.
31 requests/minute to `/chat` → 429 from slowapi.
→ **HANDOFF to Aria:** All agent endpoints live. Paths and response shapes locked. Read this worklog session before Steps 28–31.

---

### Step 27 — `feat: verify end-to-end LLM execution with test graph`
**Owner:** Rex
**Touches:** `data/graphs/llm_test.json`, `src/backend/executor/runner.py` (fix only if needed)
**What happens:**
- `llm_test.json`: minimal test graph — `entry_exit` (entry, value="What is 2+2?") →
  `llm_call` (model=claude-3-5-haiku-20241022, temperature=0.3) → `entry_exit` (exit)
- Manual smoke test via `POST /graphs/llm_test/run` + `GET /runs/{id}/stream`
- Any integration bugs found in `runner.py` fixed in this step (Rex's domain only)
- `llm_test.json` committed as a test artifact
**Acceptance:** SSE stream completes. LLM completion visible in exit node output. `tokens_used > 0`.
No exceptions raised.
→ **HANDOFF to Aria:** LLM execution verified end-to-end. Aria can build agent UI against a working backend.

---

### Step 28 — `feat: build AI chat panel with narration rendering`
**Owner:** Aria
**Touches:** `src/frontend/src/components/panels/AIChatPanel.tsx`, `src/frontend/src/api/agentApi.ts`
**What happens:**
- `agentApi.ts`: `sendMessage(graphId, message) -> OrchestratorDecision`,
  `approveDiff(graphId, bundleId) -> Graph`, `rejectDiff(graphId, bundleId) -> void`
- `AIChatPanel.tsx`:
  - Message list: user bubbles (right, indigo), agent replies (left, gray) with "✦" avatar
  - `OrchestratorDecision.response` → agent's conversational text
  - `DiffBundle.narration` → teaching voice block rendered below the response, visually distinct:
    `text-sm italic text-gray-400` with a 2px left border in indigo. Only shown when `narration` is non-null.
  - Loading: "Agent is thinking…" with 3 pulsing dots (staggered `animate-pulse`)
  - Error: dismissible `ErrorBanner` with retry
  - Empty: "Describe a goal and the agent will build it for you →"
  - Input: text field + "Send", disabled while loading
  - When `OrchestratorDecision.payload.bundle_id` exists → `setPendingDiffs(bundle)` on store
- All styles from `theme.ts`
**Acceptance:** Message sent → user bubble → thinking → agent reply. Narration block renders below reply
when present, in distinct style. Error shows banner.

---

### Step 29 — `feat: build DiffCard — pending diff preview with approve and reject`
**Owner:** Aria
**Touches:** `src/frontend/src/components/ui/DiffCard.tsx`,
`src/frontend/src/components/panels/AIChatPanel.tsx`
**What happens:**
- `DiffCard.tsx`:
  - Shown above chat input when `pendingDiffs !== null` in store
  - Header: `summary` text + diff count badge
  - Expandable list: each `GraphDiff` as a row — `action` badge (ADD_NODE=green, REMOVE=red,
    PATCH=amber, ADD_EDGE=blue; all colours from `theme.ts`) + `reason` text
  - "Approve" (primary) → `approveDiff()` → `applyDiffBundle()` on store → `setPendingDiffs(null)`
  - "Reject" (ghost) → `rejectDiff()` → `setPendingDiffs(null)`
  - Both buttons disabled + spinner on Approve during loading
- `AIChatPanel.tsx` updated: renders `<DiffCard />` above input when `pendingDiffs` exists
- All styles from `theme.ts`
**Acceptance:** After `build_graph` action: DiffCard appears with summary + expandable diff list.
Approve → nodes appear on canvas. Reject → card disappears, graph unchanged.

---

### Step 30 — `feat: animate agent-added nodes appearing on canvas`
**Owner:** Aria
**Touches:** `src/frontend/src/components/nodes/BaseNode.tsx`,
`src/frontend/src/components/canvas/GraphCanvas.tsx`
**What happens:**
- `BaseNode.tsx`: `isNew` → `ring-2 ring-indigo-400 animate-pulse` for 1500ms (store clears flag).
  `agent_generated` → permanent "✦ AI" badge in node header (`text-xs text-indigo-400`).
- `GraphCanvas.tsx`: after `applyDiffBundle()` fires (listen to store change), calls
  `reactFlowInstance.fitView({nodes: newNodeIds, padding: 0.3, duration: 400})`
- New edges from `applyDiffBundle`: `animated: true`, set to `false` after 1500ms via store `setTimeout`
**Acceptance:** Approve diff → nodes pulse briefly → canvas pans/zooms to show them → AI badge permanent.
Animations stop after 1.5s.

---

### Step 31 — `feat: add API key modal and localStorage free-use counter`
**Owner:** Aria
**Touches:** `src/frontend/src/components/ui/ApiKeyModal.tsx`,
`src/frontend/src/hooks/useApiKey.ts`,
`src/frontend/src/api/apiClient.ts`,
`src/frontend/src/components/panels/AIChatPanel.tsx`
**What happens:**
- `useApiKey.ts`:
  - `incrementUseCount()`: reads `parseInt(localStorage.getItem('ac_uses') ?? '0')`, increments, persists
  - `getUseCount()`: returns current count
  - `hasUserKey()`: returns `!!sessionStorage.getItem('ac_user_key')`
  - `setUserKey(key: string)`: `sessionStorage.setItem('ac_user_key', key)` — session-only, cleared on tab close
  - `needsKeyModal()`: `getUseCount() >= FREE_USES_PER_SESSION && !hasUserKey()`
    where `FREE_USES_PER_SESSION = parseInt(import.meta.env.VITE_FREE_USES ?? '3')` (**N = 3**)
- `ApiKeyModal.tsx`:
  - Shown when `needsKeyModal()` is true and user attempts to send a message
  - "You've used your 3 free queries. Enter your OpenAI or Anthropic API key to continue."
  - Text input for API key (type="password") + "Continue" button
  - "Get an Anthropic key" and "Get an OpenAI key" links — official API key pages only
  - On submit: `setUserKey(input)`, dismiss modal, retry the original message
  - **Key is stored in sessionStorage only** — never in localStorage, never logged, never persisted server-side
- `apiClient.ts` updated: appends `X-User-API-Key: sessionStorage.getItem('ac_user_key')` header
  (header injection already stubbed in Step 15 — activate it here)
- `AIChatPanel.tsx`: on send → `incrementUseCount()` → if `needsKeyModal()` → show modal instead of sending
- All styles from `theme.ts`
**Acceptance:** 3 free sends work without a key. 4th send triggers modal. Key entry → modal dismissed →
message retried → `X-User-API-Key` header present in request. Browser refresh → sessionStorage cleared →
key gone (expected behaviour). localStorage use count persists across refreshes.

---

## Phase 7 — Demo Scenario & LLM Config (Steps 32–34)

*Goal: The RAG demo graph is pre-loaded on first start. LLM nodes are fully configurable.
The 5-minute walkthrough works end-to-end.*

---

### Step 32 — `feat: build RAG demo graph JSON and auto-load on first start`
**Owner:** Rex
**Touches:** `data/graphs/demo.json`, `src/backend/storage/graph_store.py`, `src/backend/main.py`
**What happens:**
- `demo.json`: RAG pipeline — 7 nodes, all positioned at y=200, edges defined:
  1. `entry_exit` (entry, config: {mode: "entry", value: "What are the main themes in these documents?"}) → x=100
  2. `document_loader` (source connected from entry value) → x=360
  3. `text_splitter` (documents from loader) → x=620
  4. `embeddings` (chunks from splitter) → x=880
  5. `vector_store` (embeddings from embeddings node; query connected from entry value) → x=1140
  6. `llm_call` (config: model=claude-3-5-haiku-20241022, temperature=0.3, max_tokens=512,
     system_prompt="Answer based on the retrieved context. Be concise.";
     prompt port wired from vector_store results via prompt_template if needed) → x=1400
  7. `entry_exit` (exit, value from llm_call completion) → x=1660
  - All node_id values stable and human-readable (e.g. "doc_loader_1", "splitter_1")
  - `agent_generated: false` on all nodes
- `graph_store.py`: `ensure_demo_graph()` — if `GRAPHS_DIR` is empty or demo not present, copies
  `data/graphs/demo.json` to `{GRAPHS_DIR}/demo.json`
- `main.py` lifespan: calls `ensure_demo_graph()` on startup
**Acceptance:** Fresh server start → `GET /graphs` returns at least `["demo"]`.
Demo graph loads with 7 nodes and correct edges. All positions valid.

---

### Step 33 — `feat: build LLM node config panel — model, temperature, system prompt controls`
**Owner:** Aria
**Touches:** `src/frontend/src/components/panels/NodeEditorPanel.tsx`
**What happens:**
- `NodeEditorPanel.tsx` updated: LLM nodes now show a full config panel (replacing Step 12 placeholder):
  - "Model" select: `claude-3-5-haiku-20241022` / `gpt-4o-mini`
  - "Temperature" range: 0.0–1.0, step 0.1, current value labelled
  - "Max tokens" number input: 64–2048
  - "System prompt" textarea: optional, multi-line, placeholder "You are a helpful assistant."
  - All inputs → `patchNode({config: {...node.config, key: value}})`
- `entry_exit` nodes: editable "value" textarea for entry mode; read-only port label for exit mode
- All styles from `theme.ts`
**Acceptance:** Selecting an LLM node shows all four controls. Temperature slider updates config in store.
System prompt persists across node selections.

---

### Step 34 — `feat: add tokens-used badge on LLM nodes post-execution`
**Owner:** Aria
**Touches:** `src/frontend/src/components/nodes/BaseNode.tsx`
**What happens:**
- `BaseNode.tsx`: LLM nodes with `executionOutputs[node_id]?.output?.tokens_used` show a footer:
  `"~{N} tokens"` — styled as `TYPOGRAPHY.caption + COLOURS.muted`, not prominent
- Badge only visible when `status === "complete"`, hidden at idle and on error
**Acceptance:** Run a graph with an LLM node → token count badge appears on node after completion.
Other node types unaffected.

---

## Phase 8 — Hardening & Polish (Steps 35–37)

*Goal: The demo is bulletproof. Every error state is handled. Build exits clean.*

---

### Step 35 — `feat: add error handling, empty states, and network resilience`
**Owner:** Aria
**Touches:** `src/frontend/src/components/ui/ErrorBanner.tsx`,
`src/frontend/src/components/ui/EmptyState.tsx`, all panel components
**What happens:**
- `ErrorBanner.tsx`: dismissible red banner — icon + message + optional retry button. Used in every panel.
- `EmptyState.tsx`: reusable — icon prop, heading, subtext. Used in palette, chat, canvas.
- Canvas empty state: "Start by dragging a node from the left — or describe a goal in the chat →"
- All loading states: skeleton for layout-shifting areas, spinner for quick operations
- Network offline: `window.addEventListener('offline')` → persistent "Connection lost" banner in top bar
- Global error boundary in `App.tsx`: catches unhandled React errors, shows "Something went wrong — reload?"
- All styles from `theme.ts`
**Acceptance:** Kill backend → "Connection lost" banner. Every panel has a non-blank empty state.
No white areas on any state.

---

### Step 36 — `feat: add onboarding hint bar for first-run experience`
**Owner:** Aria
**Touches:** `src/frontend/src/components/ui/OnboardingHint.tsx`,
`src/frontend/src/components/canvas/GraphCanvas.tsx`
**What happens:**
- `OnboardingHint.tsx`: dismissible banner above canvas.
  "Try dragging a node from the left — or describe your goal in the chat →"
  Dismiss → `localStorage.setItem('ac_hint_dismissed', 'true')`
- Not shown when: `nodes.length > 0` OR `localStorage.getItem('ac_hint_dismissed')` is set
- All styles from `theme.ts`
**Acceptance:** Empty graph → hint visible. Adding a node → hint disappears. Dismiss → hidden on reload.

---

### Step 37 — `feat: final smoke test and README`
**Owner:** Claude
**Touches:** `README.md`
**What happens:**
- Manual end-to-end smoke test — no code changes unless a bug is found in a documentation file:
  1. Fresh start → demo graph loads with 7 nodes
  2. Run the demo graph → execution streams through all nodes
  3. Type "add a node that reverses the LLM output" → agent builds diff → narration renders in chat
     → approve → new node on canvas → AI badge visible → ExplanationPanel opens → run again
  4. Verify 4th chat message triggers API key modal (if ERAN_API_KEY not set)
  5. Verify all four node categories visually distinct
- `README.md`: setup instructions, dev commands (`make install`, `make dev`), env var table,
  5-step demo walkthrough, link to DECISIONS.md for architecture context
**Acceptance:** Full demo scenario runs without console errors or crashes.
README produces a working local setup on a clean clone.

---

## Phase 9 — Deployment (Steps 38–39)

*Goal: AgentCanvas is live at a URL someone can share. FastAPI serves the compiled React build.
Railway handles HTTPS and the SSE stream without buffering.*

---

### Step 38 — `feat: add static file serving for single-service production deployment`
**Owner:** Rex
**Touches:** `src/backend/main.py`, `src/backend/config.py`
**What happens:**
- `config.py`: `FRONTEND_DIST_DIR` already declared (Step 3) — confirm it is present and documented
- `main.py`: after all API routes are registered, conditionally mount StaticFiles:
  ```python
  if settings.FRONTEND_DIST_DIR and Path(settings.FRONTEND_DIST_DIR).exists():
      app.mount("/", StaticFiles(directory=settings.FRONTEND_DIST_DIR, html=True), name="static")
  ```
  - API routes take priority over the static mount — order matters
  - `html=True` enables SPA fallback: any unknown path returns `index.html`
- Confirm `X-Accel-Buffering: no` is present on the SSE `StreamingResponse` (added in Step 20 — verify)
**Acceptance:** `pnpm run build` → set `FRONTEND_DIST_DIR=src/frontend/dist` → start backend →
`GET /` returns React app. `GET /health` still returns 200. `GET /some/unknown/path` returns `index.html`.
→ **HANDOFF to Adam:** Static file serving works. Adam configures Railway to use it.

---

### Step 39 — `feat: Railway deployment config and production environment documentation`
**Owner:** Adam
**Touches:** `.railway.toml`, `Makefile` (additions), `.env.example` (final review)
**What happens:**
- `.railway.toml`:
  ```toml
  [build]
  builder = "NIXPACKS"
  buildCommand = "cd src/frontend && pnpm install && pnpm run build && cd ../../src/backend && pip install uv && uv sync"

  [deploy]
  startCommand = "cd src/backend && uv run uvicorn main:app --host 0.0.0.0 --port $PORT"
  healthcheckPath = "/health"
  healthcheckTimeout = 30

  [[services.envs]]
  FRONTEND_DIST_DIR = "src/frontend/dist"
  ```
- `Makefile` additions: `make production-check` — verifies `FRONTEND_DIST_DIR` is set and `dist/` exists,
  exits non-zero with a clear message if not
- `.env.example` final review: all 8 vars present. Railway note appended:
  "On Railway: set these in the service Variables panel. NEVER commit .env to git.
  ERAN_API_KEY must be set for free-tier demo queries to work."
**Acceptance:** `.railway.toml` is valid TOML. `make build-frontend` (from Step 1) produces `src/frontend/dist/`.
`make production-check` exits 0 when `FRONTEND_DIST_DIR` is set correctly.

---

*End of protocol. 39 steps. 9 phases. Build in order. Ship in one week.*

---

## Phase ownership summary

| Phase | Steps | Owner(s) |
|---|---|---|
| 1 — Infrastructure | 1–4 | Adam (1–2), Rex (3), Aria (4) |
| 2 — Foundation Models | 5–7 | Rex |
| 3 — Canvas & API Shell | 8–15 | Aria (8–12, 15), Rex (13–14) |
| 4 — Teaching Layer | 16–17 | Aria |
| 5 — Execution Engine | 18–21 | Rex (18–20), Aria (21) |
| 6 — Agent Runtime | 22–31 | Nova (22–25), Rex (26–27), Aria (28–31) |
| 7 — Demo & Config | 32–34 | Rex (32), Aria (33–34) |
| 8 — Hardening | 35–37 | Aria (35–36), Claude (37) |
| 9 — Deployment | 38–39 | Rex (38), Adam (39) |

---

## Dependency map — why this order is correct

```
Step 1  (Adam)  Makefile, .env.example       ← every agent knows what env vars exist
Step 2  (Adam)  GitHub Actions CI            ← regressions caught from first commit
Step 3  (Rex)   Backend scaffold             ← prerequisite for everything backend
Step 4  (Aria)  Frontend scaffold            ← prerequisite for everything frontend
         │
Step 5  (Rex)   Graph models                 ← NodeSpec, Graph, PortType: ALL agents depend on these
Step 6  (Rex)   Diff models + narration      ← DiffBundle.narration: Nova populates, Aria renders
Step 7  (Rex)   12-node registry             ← explanation/example/category: Nova + Aria consume
         │
Step 8  (Aria)  Design tokens                ← all Aria steps derive from theme.ts
Step 9  (Aria)  Zustand store               ← isNew flag: ExplanationPanel (Step 16) depends on this
Step 10 (Aria)  Canvas + BaseNode            ← nodes render; category colours from Step 8
Step 11 (Aria)  Node palette                 ← 12 types hardcoded; replaced by API in Step 15
Step 12 (Aria)  Node editor                  ← LLM config placeholder until Step 33
Step 13 (Rex)   Graph storage + API + deps   ← CRUD live; resolve_api_key ready for Step 26
Step 14 (Rex)   Edit mode guard              ← safety layer before any mutation endpoints used
Step 15 (Aria)  Frontend ↔ API wiring        ← live palette + save/load
         │
Step 16 (Aria)  Explanation panel            ← depends on isNew (Step 9) + explanation field (Step 7)
Step 17 (Aria)  Category visual language     ← depends on NodeCategory (Step 7) + theme (Step 8)
         │
Step 18 (Rex)   Sandbox                      ← code node execution
Step 19 (Rex)   Executor                     ← topological sort + input resolution
Step 20 (Rex)   Run endpoint + SSE           ← X-Accel-Buffering header for Railway
Step 21 (Aria)  SSE → canvas                 ← live execution status on nodes
         │
Step 22 (Nova)  Node agent                   ← depends on NodeSpec, GraphDiff (Steps 5–6)
Step 23 (Nova)  Graph-writer + narration     ← two-call: structured diffs + teaching narration
Step 24 (Nova)  Orchestrator                 ← depends on both sub-agents being complete
Step 25 (Nova)  LLM node execution           ← api_key explicit; Nova never touches runner.py
Step 26 (Rex)   LLM in executor + agent API  ← wires Nova's agents into Rex's API layer
Step 27 (Rex)   End-to-end LLM smoke test    ← verifies full stack before UI is built against it
Step 28 (Aria)  Chat panel + narration       ← depends on Step 27 handoff + DiffBundle.narration
Step 29 (Aria)  DiffCard                     ← depends on Step 28 (chat panel houses DiffCard)
Step 30 (Aria)  Node animations              ← depends on applyDiffBundle store action (Step 9)
Step 31 (Aria)  API key modal                ← depends on apiClient header injection (Step 15)
         │
Step 32 (Rex)   RAG demo graph               ← 7 nodes; depends on 12-node registry (Step 7)
Step 33 (Aria)  LLM config panel             ← replaces Step 12 placeholder
Step 34 (Aria)  Tokens badge                 ← depends on NodeOutput.output.tokens_used (Step 5)
         │
Step 35 (Aria)  Error + empty states         ← wraps all panels built in Steps 11–31
Step 36 (Aria)  Onboarding hint              ← final canvas polish
Step 37 (Claude) Smoke test + README         ← no code; depends on everything being built
         │
Step 38 (Rex)   StaticFiles mount            ← single-service production build
Step 39 (Adam)  Railway config               ← depends on Step 38 static serving working
```
