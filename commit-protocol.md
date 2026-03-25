# Commit Protocol — AI-Native Node Graph Platform

**38 atomic commits across 7 phases.**
Every step is owned by exactly one agent.
No step touches another agent's domain files.
Steps are ordered so every dependency is built before it is consumed.
Execute in order. No combining. No skipping.

---

## Ownership at a glance

| Agent | Owns | Commit signature |
|---|---|---|
| **Claude** | API routes, graph store, Zustand store, integration wiring, all project markdown | `Co-Authored-By: Claude <claude@anthropic.com>` |
| **Rex** | Pydantic models, executor, sandbox, cache, node type registry | `Co-Authored-By: Rex <rex.nodegraph@gmail.com>` |
| **Nova** | LangGraph agents, prompts, agent tools, LLM node execution | `Co-Authored-By: Nova <nova.nodegraph@gmail.com>` |
| **Aria** | React components, design tokens, page layouts | `Co-Authored-By: Aria <aria.nodegraph@gmail.com>` |

**Hard rule:** If a step's target files include anything outside the owner's domain —
stop, flag to Eran, do not proceed. Never fix a domain violation by having an agent
touch files they don't own.

---

## Handoff markers

Each step that produces output another agent depends on ends with a `→ HANDOFF` line
naming the receiving agent and what they now have access to. The receiving agent
does not start their dependent step until they have read the producing agent's
worklog session and written receipt confirmation in their own.

---

## Phase 1 — Foundation Models & Scaffolding (Steps 1–6)

*Goal: Both servers start. The core data models exist. No UI, no logic yet.*
*Rex's models land before anyone else writes a line that uses them.*

---

### Step 1 — `chore: initialize python backend with fastapi, uv, and settings`
**Owner:** Claude
**Touches:** `src/backend/pyproject.toml`, `src/backend/main.py`, `src/backend/config.py`, `src/backend/.env.example`
**What happens:**
- `uv init src/backend`
- `uv add fastapi uvicorn pydantic pydantic-settings python-dotenv`
- `config.py`: `class Settings(BaseSettings)` — `LLM_PROVIDER`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GRAPHS_DIR`
- `main.py`: bare FastAPI app, CORS for `http://localhost:5173`, `GET /health → {"status": "ok"}`
**Acceptance:** `uv run uvicorn main:app --reload` starts. `/health` returns 200.

---

### Step 2 — `chore: initialize react frontend with vite, typescript, and tailwind`
**Owner:** Claude
**Touches:** `src/frontend/package.json`, `src/frontend/vite.config.ts`, `src/frontend/tsconfig.json`, `src/frontend/tailwind.config.ts`, `src/frontend/index.html`, `src/frontend/src/main.tsx`, `src/frontend/src/App.tsx`
**What happens:**
- `pnpm create vite src/frontend --template react-ts`
- `pnpm add -D tailwindcss postcss autoprefixer`
- `npx tailwindcss init -p`
- `App.tsx`: `<div className="w-screen h-screen bg-gray-950 text-white">hello</div>`
**Acceptance:** `pnpm run dev` starts. Browser shows dark screen with "hello". No console errors.

> Steps 1–2 are both Claude. These are build-system scaffolds — no domain logic yet.
> Rex, Nova, and Aria cannot start until these exist.

---

### Step 3 — `feat: define PortType enum and all graph pydantic models`
**Owner:** Rex
**Touches:** `src/backend/models/__init__.py`, `src/backend/models/graph.py`
**What happens:**
- `PortType(str, Enum)`: `STRING`, `NUMBER`, `BOOLEAN`, `ANY`, `PROMPT`, `COMPLETION`, `JSON`
- `Port(BaseModel)`: `name`, `type: PortType`, `required: bool = True`, `default: Any = None`
- `NodeSpec(BaseModel)`: `node_id`, `node_type`, `label`, `inputs: list[Port]`, `outputs: list[Port]`, `code: str | None`, `config: dict`, `input_hash: str | None`, `cached_output: dict | None`, `agent_generated: bool`, `position: dict[str, float]`
- `Edge(BaseModel)`: `edge_id`, `source_node`, `source_port`, `target_node`, `target_port`
- `GraphState(str, Enum)`: `EDIT = "edit"`, `RUN = "run"`
- `Graph(BaseModel)`: `graph_id`, `name`, `state: GraphState`, `nodes: list[NodeSpec]`, `edges: list[Edge]`, `created_at`, `updated_at`
- `NodeOutput(BaseModel)`: `node_id`, `status: Literal["running","complete","error","skipped"]`, `output: dict | None`, `error: str | None`, `cached: bool`, `duration_ms: int | None`
**Acceptance:** `python -c "from models.graph import Graph, NodeOutput"` imports cleanly.
→ **HANDOFF to Nova, Claude, Aria:** `NodeSpec`, `Graph`, `Edge`, `GraphState`, `NodeOutput` are finalised. Read Rex's worklog before any step that uses these models.

---

### Step 4 — `feat: define GraphDiff, DiffBundle, and OrchestratorDecision models`
**Owner:** Rex
**Touches:** `src/backend/models/diff.py`
**What happens:**
- `DiffAction(str, Enum)`: `ADD_NODE`, `REMOVE_NODE`, `PATCH_NODE`, `ADD_EDGE`, `REMOVE_EDGE`
- `GraphDiff(BaseModel)`: `action: DiffAction`, `payload: dict[str, Any]`, `agent: str`, `reason: str`
- `DiffBundle(BaseModel)`: `bundle_id: str`, `diffs: list[GraphDiff]`, `summary: str`
- `OrchestratorDecision(BaseModel)`: `action: Literal["fix_node","build_graph","respond"]`, `payload: dict`, `response: str`
**Acceptance:** Invalid `DiffAction` raises `ValidationError`. `DiffBundle` with empty diffs list is valid.
→ **HANDOFF to Nova, Claude, Aria:** All agent I/O shapes are locked. Nova builds agents that return these. Claude builds API routes that handle them. Aria renders them. No field changes after this commit without Eran's approval.

---

### Step 5 — `feat: define node type registry with built-in node specs`
**Owner:** Rex
**Touches:** `src/backend/nodes/__init__.py`, `src/backend/nodes/types.py`, `src/backend/nodes/registry.py`
**What happens:**
- `NodeTypeDefinition(BaseModel)`: `node_type`, `label`, `description`, `default_inputs: list[Port]`, `default_outputs: list[Port]`, `has_code: bool`, `icon: str`
- `REGISTRY: dict[str, NodeTypeDefinition]` — four entries:
  - `code`: inputs=[`data: ANY`], outputs=[`result: ANY`], `has_code=True`
  - `llm`: inputs=[`prompt: PROMPT`, `system: STRING(required=False)`], outputs=[`completion: COMPLETION`, `tokens_used: NUMBER`], `has_code=False`
  - `input`: inputs=[], outputs=[`value: ANY`], `has_code=False`
  - `output`: inputs=[`value: ANY`], outputs=[], `has_code=False`
- `def get_node_type(node_type: str) -> NodeTypeDefinition` — raises `KeyError` with message listing available types
- `def list_node_types() -> list[NodeTypeDefinition]`
**Acceptance:** `list_node_types()` returns 4. `get_node_type("unknown")` raises descriptive `KeyError`.
→ **HANDOFF to Nova, Claude, Aria:** Registry locked. Nova's graph-writer uses `list_node_types()` for context. Claude exposes it via API. Aria renders it in the palette.

---

### Step 6 — `feat: create design token system and three-panel editor shell`
**Owner:** Aria
**Touches:** `src/frontend/src/theme.ts`, `src/frontend/src/pages/Editor.tsx`, `src/frontend/src/App.tsx`
**What happens:**
- `theme.ts`: `COLOURS`, `TYPOGRAPHY`, `SPACING`, `RADIUS`, `SHADOW`, `NODE_STYLES`, `PANEL_STYLES` — every visual constant for the project. No Tailwind strings in any other file.
- `Editor.tsx`: three empty panels — left sidebar (`w-64 bg-gray-900 border-r border-gray-800`), canvas (`flex-1 bg-gray-950`), right panel (`w-80 bg-gray-900 border-l border-gray-800`)
- `App.tsx` renders `<Editor />`
**Acceptance:** `pnpm run dev` shows three-panel dark layout. No errors.
→ **HANDOFF to Aria (self):** Token system established. All subsequent Aria steps use `theme.ts` — zero hardcoded Tailwind strings in components.

---

## Phase 2 — Canvas, Store & API Shell (Steps 7–12)

*Goal: Nodes exist on a canvas. The store manages state. The API saves and loads graphs.*

---

### Step 7 — `feat: implement zustand graph store with node and edge state`
**Owner:** Claude
**Touches:** `src/frontend/src/store/graphStore.ts`, `src/frontend/src/store/types.ts`
**What happens:**
- `store/types.ts`: TypeScript mirrors of Rex's models — `NodeSpec`, `Edge`, `Graph`, `GraphState`, `NodeOutput`, `DiffBundle`, `OrchestratorDecision`, `GraphDiff`, `DiffAction`
- `graphStore.ts` (Zustand): state — `nodes`, `edges`, `graphState: 'edit'|'run'`, `selectedNodeId: string | null`, `pendingDiffs: DiffBundle | null`, `executionOutputs: Record<string, NodeOutput>`
- Actions: `addNode`, `removeNode`, `patchNode` (partial update by `node_id`), `addEdge`, `removeEdge`, `setGraphState`, `setSelectedNode`, `setPendingDiffs`, `applyDiffBundle` (processes each diff type in order — ADD_NODE before ADD_EDGE), `rejectDiffBundle`, `setNodeOutput`, `loadGraph` (replaces all state from a Graph object)
- `applyDiffBundle`: sets `agent_generated: true` on all ADD_NODE nodes, sets `isNew: true` (cleared after 1500ms via `setTimeout`)
**Acceptance:** `addNode()` → node in store. `removeNode()` → gone. `applyDiffBundle({ADD_NODE, ADD_EDGE})` adds node then edge in one call. `graphState` starts `'edit'`.
→ **HANDOFF to Aria:** Store is ready. All components import `useGraphStore()`. `isNew` flag is handled — Aria just reads it in `BaseNode.tsx`.

---

### Step 8 — `feat: build react flow canvas with typed port handles and connection validation`
**Owner:** Aria
**Touches:** `src/frontend/src/components/canvas/GraphCanvas.tsx`, `src/frontend/src/components/nodes/BaseNode.tsx`, `src/frontend/src/components/nodes/PortHandle.tsx`
**What happens:**
- `pnpm add @xyflow/react`
- `GraphCanvas.tsx`: `<ReactFlow>` with `snapToGrid`, `Background`, `Controls`, `MiniMap`. Reads `nodes`, `edges` from store. `onNodesChange`/`onEdgesChange` dispatch to store. `onNodeClick` calls `setSelectedNode`. `isValidConnection` enforces port type rules.
- `PortHandle.tsx`: React Flow `Handle` — coloured dot per `PortType` from `theme.ts`. `data-port-type` attribute on each handle.
- `BaseNode.tsx`: node header (type badge + label), input handles left, output handles right. Reads `executionOutputs[node_id]` for status ring. Reads `isNew` for pulse animation. Reads `agent_generated` for "✦ AI" badge.
- Port compatibility: `ANY` ↔ anything. `PROMPT` ↔ `PROMPT` only. `COMPLETION` ↔ `COMPLETION` or `ANY`. Others match by exact type.
- All styles from `theme.ts`
**Acceptance:** Canvas renders. Dummy node in store appears on canvas. Incompatible port connection attempt shows red ✕ and does not create an edge.

---

### Step 9 — `feat: build node palette sidebar with drag-to-canvas`
**Owner:** Aria
**Touches:** `src/frontend/src/components/panels/NodePalette.tsx`
**What happens:**
- Hardcoded node type list matching Rex's registry (4 types: code, llm, input, output) — replaced with live API in Step 12
- One draggable card per type: icon, label, description. `onDragStart` sets `nodeType` in event data.
- `GraphCanvas.tsx` `onDrop`: reads `nodeType`, calls `addNode()` with new `NodeSpec` at drop position. Port definitions copied from registry shape.
- Empty state: "Drag a node onto the canvas to start building"
- All styles from `theme.ts`
**Acceptance:** Dragging "Code" card onto canvas creates a code node at the drop position.

---

### Step 10 — `feat: build node editor panel with monaco code editor`
**Owner:** Aria
**Touches:** `src/frontend/src/components/panels/NodeEditorPanel.tsx`
**What happens:**
- `pnpm add @monaco-editor/react`
- Right panel shows this component when `selectedNodeId` is set
- Editable label at top: `<input>` → calls `patchNode({label: value})`
- Code nodes: Monaco editor bound to `node.code`, `onChange` → `patchNode({code: value})`. Python language, dark theme, `fontSize: 13`, no minimap.
- LLM nodes: "Config available after Step 32" placeholder
- Input/output nodes: read-only label showing port name
- Empty state: "Select a node to edit" when nothing selected
- All styles from `theme.ts`
**Acceptance:** Clicking a code node opens Monaco. Typing updates the node. Clicking an LLM node shows the placeholder.

---

### Step 11 — `feat: implement graph storage and all REST graph endpoints`
**Owner:** Claude
**Touches:** `src/backend/storage/__init__.py`, `src/backend/storage/graph_store.py`, `src/backend/api/__init__.py`, `src/backend/api/routes.py`, `src/backend/main.py`
**What happens:**
- `graph_store.py`: `save_graph`, `load_graph`, `list_graphs`, `delete_graph` — reads/writes `{GRAPHS_DIR}/{graph_id}.json`
- `routes.py`: `GET /graphs`, `GET /graphs/{id}`, `POST /graphs`, `PUT /graphs/{id}`, `DELETE /graphs/{id}`, `GET /node-types` (calls `list_node_types()` from Rex's registry)
- `main.py`: `app.include_router(router)`
**Acceptance:** `POST /graphs` creates a file. `GET /graphs/{id}` returns same graph. `GET /node-types` returns 4 entries.

---

### Step 12 — `feat: wire frontend save/load and node palette to live API`
**Owner:** Claude
**Touches:** `src/frontend/src/api/graphApi.ts`, `src/frontend/src/hooks/useGraphSync.ts`, `src/frontend/src/pages/Editor.tsx`, `src/frontend/src/components/panels/NodePalette.tsx`
**What happens:**
- `graphApi.ts`: typed fetch wrappers — `saveGraph`, `loadGraph`, `listGraphs`, `listNodeTypes`
- `useGraphSync.ts`: `useSaveGraph()` and `useLoadGraph()` hooks
- `Editor.tsx` top bar: "Save" button, "Load" dropdown, graph name displayed
- `NodePalette.tsx` updated: `useEffect` calls `listNodeTypes()`, replaces hardcoded list from Step 9
- URL sync: graph ID in `?g=` query param
**Acceptance:** Save → reload → graph reappears. Palette populated from live API.

---

## Phase 3 — Execution Engine (Steps 13–18)

*Goal: Node code executes safely. Results stream live to the canvas.*
*Rex builds the full execution stack. Claude wires the API. Aria connects the UI.*
*Nova is not involved in Phase 3.*

---

### Step 13 — `feat: implement restrictedpython sandbox for safe node code execution`
**Owner:** Rex
**Touches:** `src/backend/executor/__init__.py`, `src/backend/executor/sandbox.py`
**What happens:**
- `execute_code_node(code: str, inputs: dict[str, Any]) -> dict[str, Any]`
- RestrictedPython compiles and runs in restricted environment. `inputs` available as variable. Code must assign `outputs` dict.
- Blocked: `import os`, `import sys`, `open()`, `__import__`, `exec`, `eval`, any `__builtins__` override
- `SandboxViolation(message: str)` exception for all violations — message names the blocked operation
- 10-second timeout via `threading.Timer` → `TimeoutError("Node execution exceeded 10s")`
**Acceptance:** `outputs = {"x": inputs["n"] * 2}` works. `import os` raises `SandboxViolation`. 15-second sleep raises `TimeoutError`.

---

### Step 14 — `feat: implement input hash cache utilities`
**Owner:** Rex
**Touches:** `src/backend/executor/cache.py`
**What happens:**
- `compute_input_hash(inputs: dict) -> str` — SHA-256 of `json.dumps(inputs, sort_keys=True, default=str)`
- `should_use_cache(node: NodeSpec, inputs: dict) -> bool` — `True` only if both hash matches AND `cached_output` is not `None`
- `update_node_cache(node: NodeSpec, inputs: dict, output: dict) -> NodeSpec` — returns updated `NodeSpec` with new hash and cached output
**Acceptance:** Same inputs → same hash. Changed input → different hash. `should_use_cache` is `False` when `cached_output` is `None` even if hash matches.

---

### Step 15 — `feat: implement topological sort executor with caching and input resolution`
**Owner:** Rex
**Touches:** `src/backend/executor/runner.py`
**What happens:**
- `topological_sort(graph: Graph) -> list[NodeSpec]` — Kahn's algorithm. `ValueError("Cycle detected involving: {ids}")` on cycle.
- `resolve_inputs(node: NodeSpec, graph: Graph, completed_outputs: dict) -> dict` — walks edges to resolve each input port's value from upstream outputs
- `async def execute_graph(graph: Graph) -> AsyncIterator[NodeOutput]`:
  - Topological sort → for each node: `resolve_inputs` → check `should_use_cache` → if hit: `yield NodeOutput(status="skipped", cached=True)` → else: `yield NodeOutput(status="running")` → execute → `yield NodeOutput(status="complete")` or `NodeOutput(status="error")`
  - `code` nodes: calls `execute_code_node()` from sandbox
  - `input` nodes: passes through `config.get("value", "")` as `{"value": ...}`
  - `output` nodes: yields its input value as output (terminal — no further processing)
  - `llm` nodes: raises `NotImplementedError("LLM node support added in Step 23")` — placeholder only
**Acceptance:** 3-node graph (input→code→output) executes in order. B receives A's output. Second run with same inputs: code node skipped. Cycle detection works.
→ **HANDOFF to Claude:** `execute_graph()` async iterator is the integration point. Claude calls it from the SSE endpoint in Step 16.

---

### Step 16 — `feat: add graph run endpoint and SSE execution streaming`
**Owner:** Claude
**Touches:** `src/backend/api/routes.py`, `src/backend/api/sse.py`
**What happens:**
- `sse.py`: `format_sse(data: dict) -> str` — `"data: {json}\n\n"`
- `routes.py` additions:
  - `POST /graphs/{graph_id}/run` — loads graph, sets `state=RUN`, saves, stores `execute_graph()` iterator in `ACTIVE_RUNS: dict[str, AsyncIterator]`, returns `{run_id}`
  - `GET /runs/{run_id}/stream` — `StreamingResponse` iterates the stored iterator, yields each `NodeOutput` as SSE. Final event: `{"event":"complete","run_id":"..."}`. On completion: sets `state=EDIT`, saves graph with updated `input_hash`/`cached_output` on each node.
  - `POST /runs/{run_id}/cancel` — removes from `ACTIVE_RUNS`, sets graph `state=EDIT`
**Acceptance:** `POST /run` → `run_id`. `GET /stream` yields one event per node. Stream closes after completion. Graph returns to EDIT.

---

### Step 17 — `feat: connect SSE stream to canvas with live node status rendering`
**Owner:** Aria
**Touches:** `src/frontend/src/hooks/useExecution.ts`, `src/frontend/src/components/nodes/BaseNode.tsx`, `src/frontend/src/pages/Editor.tsx`
**What happens:**
- `useExecution.ts`: `useRunGraph(graphId)` hook
  - `POST /run` → `run_id`
  - `EventSource` on `GET /runs/{run_id}/stream`
  - Each event → `setNodeOutput(nodeId, output)` on store
  - `event=complete` → `setGraphState('edit')`
  - Returns `{runGraph, isRunning, cancelRun, error}`
- `BaseNode.tsx` execution state rendering (reads `executionOutputs[node_id]`):
  - no output → grey ring (idle)
  - `running` → blue ring + `animate-pulse`
  - `complete` → green ring
  - `error` → red ring + red error tooltip on hover
  - `skipped` → grey ring + "↩ cached" badge
- `Editor.tsx` top bar: "Run" button → `runGraph()`. "Cancel" button visible during run. "Running…" label + spinner while active. Both disabled correctly.
- All styles from `theme.ts`
**Acceptance:** Run lights up nodes in order. Errors show red. Cached nodes show "↩ cached". Cancel works.

---

### Step 18 — `feat: add RUN mode guard — reject mutations during active execution`
**Owner:** Claude
**Touches:** `src/backend/api/routes.py`
**What happens:**
- FastAPI dependency `require_edit_mode(graph_id)` — raises `HTTPException(409, "Graph is currently running")` if `graph.state == GraphState.RUN`
- Applied to: `PUT /graphs/{id}`, `POST /graphs/{id}/diffs/*/approve`, `POST /graphs/{id}/chat`, second `POST /graphs/{id}/run`
**Acceptance:** `PUT` during RUN → 409. Second `POST /run` → 409.

---

## Phase 4 — Agent Runtime (Steps 19–27)

*Goal: Agents write code. Agents build graphs. The self-modifying loop works.*
*Nova builds all agents first (Steps 19–22). Rex integrates LLM into executor (Step 23).*
*Claude wires the API (Step 24). Aria builds the UI last (Steps 25–27).*
*This ordering is strict — do not reorder.*

---

### Step 19 — `feat: implement node agent — fixes failed node code via PATCH_NODE diff`
**Owner:** Nova
**Touches:** `src/backend/agents/__init__.py`, `src/backend/agents/prompts/__init__.py`, `src/backend/agents/prompts/node_agent.py`, `src/backend/agents/node_agent.py`
**What happens:**
- `prompts/node_agent.py`: system prompt structured as role → task → constraints → output format. Constraints: "Do NOT change port names", "Do NOT add imports that weren't in the original code", "Return ONLY the corrected Python, nothing else". Includes one concrete few-shot example.
- `node_agent.py`: LangGraph state machine
  - State: `{node: NodeSpec, error: str, graph_context: str, result: GraphDiff | None, attempts: int}`
  - Flow: `read_context` → `generate_fix` → `validate_fix` → (retry once on failure) → `END`
  - `generate_fix`: LLM with `.with_structured_output(GraphDiff)`
  - `validate_fix`: checks `action == PATCH_NODE`, checks `payload["node_id"]` matches, Python `compile()` check on new code, port name unchanged check
  - Max 1 retry. On second failure: returns error `GraphDiff(reason="Agent could not produce a valid fix after 2 attempts: {error}")`
- `async def fix_node(node: NodeSpec, error: str, graph: Graph) -> GraphDiff`
**Acceptance:** Node with `outputs = {"x": undefined_var}` → diff with corrected code. `compile(diff.payload["code"])` passes. Port names unchanged.
→ **HANDOFF to Nova (self → Step 20):** Pattern established. Graph-writer follows same LangGraph structure.

---

### Step 20 — `feat: implement graph-writer agent — builds pipelines from plain-language intent`
**Owner:** Nova
**Touches:** `src/backend/agents/prompts/graph_writer.py`, `src/backend/agents/graph_writer.py`
**What happens:**
- `prompts/graph_writer.py`: system prompt with constraints: "ONLY use node_types from the provided list", "NEVER invent port names — use only ports from the node type definition", "max 8 nodes", "x positions spaced 260px apart, all same y=200". One complete few-shot example showing input→code→output for "double a number".
- `graph_writer.py`: LangGraph state machine
  - State: `{intent, current_graph, available_types, result: DiffBundle | None}`
  - Flow: `build_context` → `generate_bundle` → `validate_bundle` → `END`
  - `build_context`: formats `available_types` as compact JSON (node_type, description, input/output port names+types only — not full `NodeTypeDefinition`)
  - `generate_bundle`: LLM with `.with_structured_output(DiffBundle)`
  - `validate_bundle`: every `ADD_NODE` — `node_type` in registry; every port reference — port name exists on that type; every `ADD_EDGE` — both node IDs present in bundle's ADD_NODEs; assigns sequential x positions (260px apart, y=200)
  - Returns validated `DiffBundle` or error bundle
- `async def build_graph(intent: str, current_graph: Graph, available_types: list) -> DiffBundle`
**Acceptance:** `intent="read a number, double it, output the result"` → `DiffBundle` with 3 ADD_NODE + 2 ADD_EDGE diffs. All port names valid. Positions spaced correctly.
→ **HANDOFF to Nova (self → Step 21):** Both sub-agents ready. Orchestrator can now delegate.

---

### Step 21 — `feat: implement orchestrator agent — reads graph state and delegates`
**Owner:** Nova
**Touches:** `src/backend/agents/prompts/orchestrator.py`, `src/backend/agents/orchestrator.py`, `src/backend/agents/tools.py`
**What happens:**
- `tools.py`: pure formatting functions (not LLM tools — these are context builders)
  - `format_graph_summary(graph: Graph) -> str` — compact text: node list with types, edge list as "A.port → B.port"
  - `format_execution_summary(outputs: list[NodeOutput]) -> str` — node → status, error message if any
- `prompts/orchestrator.py`: role, decision rules: `fix_node` if error nodes + user implies fix; `build_graph` if user describes structural change; `respond` otherwise. `response` field always required.
- `orchestrator.py`: LangGraph state machine
  - State: `{graph, user_message, execution_history, decision: OrchestratorDecision | None}`
  - Flow: `summarise_context` → `decide` → `END`
  - `summarise_context`: calls both format functions, assembles context string
  - `decide`: LLM with `.with_structured_output(OrchestratorDecision)`
  - `response` always a human-readable sentence explaining the action taken
- `async def run_orchestrator(graph: Graph, user_message: str, execution_history: list[NodeOutput]) -> OrchestratorDecision`
**Acceptance:** Failed node + "fix it" → `action="fix_node"`. "Add a JSON formatter" → `action="build_graph"`. "What does this do?" → `action="respond"`.
→ **HANDOFF to Claude:** All three agents have stable async signatures: `fix_node() -> GraphDiff`, `build_graph() -> DiffBundle`, `run_orchestrator() -> OrchestratorDecision`. Claude wires these in Step 24.
→ **HANDOFF to Aria:** `DiffBundle` and `OrchestratorDecision` shapes are locked. Aria builds DiffCard (Step 26) and chat panel (Step 25) against these exact models. Read Nova's worklog for Steps 19–21 before starting Step 25.

---

### Step 22 — `feat: implement LLM node execution — calls AI provider from within the graph`
**Owner:** Nova
**Touches:** `src/backend/nodes/llm_node.py`
**What happens:**
- `async def execute_llm_node(node: NodeSpec, inputs: dict[str, Any]) -> dict[str, Any]`
  - Reads `node.config`: `model`, `temperature` (default 0.7), `max_tokens` (default 512)
  - Reads `inputs["prompt"]` (required), `inputs.get("system", "")` (optional)
  - `anthropic` → `AsyncAnthropic().messages.create(...)`; `openai` → `AsyncOpenAI().chat.completions.create(...)`
  - Returns `{"completion": text, "tokens_used": total_tokens}`
  - Error cases return error strings, never raise: missing key → `{"error": "API key not configured..."}`, rate limit → `{"error": "Rate limit..."}`, timeout after 30s → `{"error": "LLM call timed out..."}`
**Acceptance:** Valid prompt → `{"completion": "...", "tokens_used": N}`. Missing API key → error string (no exception raised). Provider selected from `settings.LLM_PROVIDER`.
→ **HANDOFF to Rex:** `execute_llm_node()` is ready. Rex integrates it into the runner in Step 23.

---

### Step 23 — `feat: integrate LLM node into execution runner`
**Owner:** Rex
**Touches:** `src/backend/executor/runner.py`
**What happens:**
- `runner.py` updated: `elif node.node_type == "llm": output = await execute_llm_node(node, resolved_inputs)`
- Removes the `NotImplementedError` placeholder from Step 15
- LLM nodes bypass cache (`should_use_cache` returns `False` for `llm` type — LLM outputs are non-deterministic)
- Import added at top of `runner.py`: `from ..nodes.llm_node import execute_llm_node`
**Acceptance:** input→llm→output graph runs end-to-end. LLM completion flows to output node. LLM node is never skipped even on second run.

---

### Step 24 — `feat: add agent API endpoints — chat, diff approve, diff reject`
**Owner:** Claude
**Touches:** `src/backend/api/routes.py`
**What happens:**
- Module-level `PENDING_DIFFS: dict[str, DiffBundle]` and `RUN_HISTORY: dict[str, list[NodeOutput]]` (populated by the SSE stream after each run)
- `POST /graphs/{graph_id}/chat`:
  - Loads graph + execution history from `RUN_HISTORY`
  - `run_orchestrator(graph, message, history)` → `OrchestratorDecision`
  - If `action=="fix_node"`: `fix_node(failed_node, error, graph)` → single-diff `DiffBundle` → stored in `PENDING_DIFFS`, `bundle_id` added to `OrchestratorDecision.payload`
  - If `action=="build_graph"`: `build_graph(message, graph, list_node_types())` → `DiffBundle` → stored in `PENDING_DIFFS`, `bundle_id` added to payload
  - Returns `OrchestratorDecision`
- `POST /graphs/{graph_id}/diffs/{bundle_id}/approve`:
  - Validates: `ADD_NODE` → schema check; `ADD_EDGE` → port type compatibility
  - Applies diffs in order: all `ADD_NODE` first, then `ADD_EDGE`, then `PATCH_NODE`, then `REMOVE_*`
  - Saves graph + version snapshot (calls Step 28 helper — added later, stubbed for now)
  - Returns updated `Graph`
- `DELETE /graphs/{graph_id}/diffs/{bundle_id}` → removes from `PENDING_DIFFS`, 204
- Both mutation endpoints use `require_edit_mode`
**Acceptance:** `/chat` with "double the input" → response + bundle_id. `/approve` adds nodes to graph. `/approve` with mismatched port types → 422. `/reject` → 204.
→ **HANDOFF to Aria:** All agent endpoints are live. Endpoint paths, request bodies, and response shapes are locked. Read this step's session before starting Steps 25–27.

---

### Step 25 — `feat: build AI chat panel with message history and agent response rendering`
**Owner:** Aria
**Touches:** `src/frontend/src/components/panels/AIChatPanel.tsx`, `src/frontend/src/api/agentApi.ts`
**What happens:**
- `agentApi.ts`: `sendMessage(graphId, message) -> OrchestratorDecision`, `approveDiff(graphId, bundleId) -> Graph`, `rejectDiff(graphId, bundleId) -> void`
- `AIChatPanel.tsx`:
  - Message list: user bubbles (right, indigo), agent replies (left, gray) with "✦" avatar
  - `OrchestratorDecision.response` is the agent's text
  - Loading: "Agent is thinking…" with 3 pulsing dots (staggered `animate-pulse`)
  - Error: red `ErrorBanner` with retry
  - Empty: "Describe a goal and the agent will build it for you →"
  - Input: text field + "Send" button, disabled while loading
  - Shown in right panel when no node selected
- When `OrchestratorDecision.payload.bundle_id` exists: calls `setPendingDiffs()` on store
- All styles from `theme.ts`
**Acceptance:** Message → user bubble → "thinking…" → agent reply. Error shows banner. Empty panel shows hint.

---

### Step 26 — `feat: build DiffCard component — pending diff preview with approve/reject`
**Owner:** Aria
**Touches:** `src/frontend/src/components/ui/DiffCard.tsx`, `src/frontend/src/components/panels/AIChatPanel.tsx`
**What happens:**
- `DiffCard.tsx`:
  - Shown above chat input when `pendingDiffs !== null` in store
  - Header: `summary` + diff count badge
  - Expandable list: each `GraphDiff` as a row — `action` badge (ADD=green, REMOVE=red, PATCH=amber, colour from `theme.ts`) + `reason` text
  - "Approve" (primary) → `approveDiff()` → `applyDiffBundle()` on store → `setPendingDiffs(null)`
  - "Reject" (ghost) → `rejectDiff()` → `setPendingDiffs(null)`
  - Loading: both buttons disabled, spinner on Approve
  - Designed to feel like a smart assistant confirming a plan — calm, clear, not alarming
- `AIChatPanel.tsx` updated: renders `<DiffCard />` above input when `pendingDiffs` exists
- All styles from `theme.ts`
**Acceptance:** After "build_graph" action: DiffCard appears with summary + expandable list. Approve → nodes appear on canvas. Reject → card disappears.

---

### Step 27 — `feat: animate agent-added nodes appearing on canvas`
**Owner:** Aria
**Touches:** `src/frontend/src/components/nodes/BaseNode.tsx`, `src/frontend/src/components/canvas/GraphCanvas.tsx`
**What happens:**
- `BaseNode.tsx`: reads `isNew` from node data (set by store's `applyDiffBundle` in Step 7). `isNew` → `ring-2 ring-indigo-400 animate-pulse` for 1500ms, then clears. `agent_generated` → permanent "✦ AI" badge in node header (`text-xs text-indigo-400`).
- `GraphCanvas.tsx`: after `applyDiffBundle()` fires (listen to store change), calls `reactFlowInstance.fitView({nodes: newNodeIds, padding: 0.3, duration: 400})`
- New edges: `animated: true` prop on edges created by `applyDiffBundle`, set to `false` after 1500ms via store `setTimeout`
**Acceptance:** Approve a diff → nodes pulse briefly → canvas pans to show them → AI badge visible permanently. Animations stop after 1.5s.

---

## Phase 5 — Version History (Steps 28–30)

*Goal: Every approved diff is snapshotted. Users can roll back to any previous state.*

---

### Step 28 — `feat: add version snapshot storage and version endpoints`
**Owner:** Claude
**Touches:** `src/backend/storage/graph_store.py`, `src/backend/api/routes.py`
**What happens:**
- `graph_store.py` additions:
  - `save_version_snapshot(graph_id, graph, summary, agent)` → writes `{GRAPHS_DIR}/{graph_id}/versions/{timestamp}.json` + `{timestamp}.meta.json`
  - `list_versions(graph_id) -> list[VersionMeta]` → sorted newest-first, max 20
  - `load_version(graph_id, version_id) -> Graph`
- `VersionMeta(BaseModel)`: `version_id`, `summary`, `agent`, `created_at`
- `routes.py` additions: `GET /graphs/{id}/versions`, `POST /graphs/{id}/versions/{vid}/restore`
- `approve_diff` endpoint updated: calls `save_version_snapshot(graph_id, current_graph, bundle.summary, diff.agent)` before applying diffs (saves the state before the change)
**Acceptance:** 3 approvals → 3 version entries. Restore returns the graph as it was before that diff.

---

### Step 29 — `feat: build version history panel — timeline with restore`
**Owner:** Aria
**Touches:** `src/frontend/src/components/panels/VersionHistoryPanel.tsx`, `src/frontend/src/api/graphApi.ts`
**What happens:**
- `graphApi.ts` additions: `listVersions(graphId)`, `restoreVersion(graphId, versionId) -> Graph`
- `VersionHistoryPanel.tsx`:
  - Shown when "History" (clock) icon in top bar is clicked — replaces right panel content
  - List of version cards: relative timestamp, summary, "✦ AI" badge if `agent !== null`
  - "Restore" button → confirmation dialog: "Restore to this version? This replaces your current graph." → on confirm: `restoreVersion()` → dispatches to store `loadGraph()` action
  - Loading: skeleton cards
  - Empty: "No history yet — approve an agent edit to create a snapshot"
- All styles from `theme.ts`
**Acceptance:** History shows versions newest-first. Restore with confirmation reloads graph on canvas.

---

### Step 30 — `feat: wire version restore to graph store`
**Owner:** Claude
**Touches:** `src/frontend/src/hooks/useGraphSync.ts`, `src/frontend/src/pages/Editor.tsx`
**What happens:**
- `useGraphSync.ts` additions: `useRestoreVersion(graphId)` — calls `restoreVersion()` API, calls `store.loadGraph(graph)` on success, triggers `reactFlowInstance.fitView()`
- `VersionHistoryPanel.tsx` updated to use this hook
- `Editor.tsx`: "History" button toggles a `showHistory` state, conditionally renders `VersionHistoryPanel` in the right panel slot
**Acceptance:** Restoring a version replaces all canvas nodes instantly. `fitView()` adjusts zoom.

---

## Phase 6 — Demo Scenario & LLM Config UI (Steps 31–33)

*Goal: The demo graph is pre-loaded. LLM nodes are fully configurable. End-to-end works.*

---

### Step 31 — `feat: build demo graph JSON and auto-load on first start`
**Owner:** Claude
**Touches:** `data/graphs/demo.json`, `src/backend/storage/graph_store.py`, `src/backend/main.py`
**What happens:**
- `demo.json`: input node → code node (strips whitespace + counts words) → llm node (prompt: "Summarize in one sentence: {input}") → output node. All positions, edges, config set.
- `graph_store.py`: `ensure_demo_graph()` — if `GRAPHS_DIR` empty, copies `demo.json` to `{GRAPHS_DIR}/demo.json`
- `main.py` lifespan: calls `ensure_demo_graph()` on startup
**Acceptance:** Fresh clone → server start → `GET /graphs` returns `["demo"]`. Demo graph loads with 4 nodes and 3 edges.

---

### Step 32 — `feat: build LLM node config panel — model, temperature, system prompt controls`
**Owner:** Aria
**Touches:** `src/frontend/src/components/panels/NodeEditorPanel.tsx`
**What happens:**
- `NodeEditorPanel.tsx` updated: LLM nodes now show a proper config panel (replacing the Step 10 placeholder)
  - "Model" select: `claude-3-5-haiku-20241022` / `gpt-4o-mini`
  - "Temperature" range: 0.0–1.0, step 0.1
  - "Max tokens" number: 64–2048
  - "System prompt" textarea: optional, multi-line
  - All inputs → `patchNode({config: {...node.config, key: value}})`
- Input node: editable "value" field → `patchNode({config: {value: ...}})`
- Output node: read-only display of its input port label
- All styles from `theme.ts`
**Acceptance:** LLM node config panel renders with all four controls. Changing temperature updates node config in store.

---

### Step 33 — `feat: add tokens-used badge on LLM nodes post-execution`
**Owner:** Aria
**Touches:** `src/frontend/src/components/nodes/BaseNode.tsx`
**What happens:**
- `BaseNode.tsx`: LLM nodes with `executionOutputs[node_id]?.output?.tokens_used` show a footer badge: "~42 tokens"
- Styled as `TYPOGRAPHY.caption` + `COLOURS.muted` — informational, not prominent
- Badge only visible when `status === "complete"`, hidden at idle
**Acceptance:** Running a graph with an LLM node shows token count on the node after completion.

---

## Phase 7 — Hardening & Polish (Steps 34–38)

*Goal: The demo is bulletproof. Every error state is handled. Builds clean.*

---

### Step 34 — `feat: add error handling, empty states, and network resilience across all panels`
**Owner:** Aria
**Touches:** `src/frontend/src/components/ui/ErrorBanner.tsx`, `src/frontend/src/components/ui/EmptyState.tsx`, all panel components
**What happens:**
- `ErrorBanner.tsx`: dismissible red banner — icon + message + optional retry button. Used in every panel for API errors.
- `EmptyState.tsx`: reusable — icon prop, heading, subtext. Used in palette, chat, history, canvas.
- Canvas empty state: "Start by dragging a node from the left — or describe a goal in the chat →"
- All loading states: skeleton where layout would shift, spinner for quick operations
- Network offline: `window.addEventListener('offline')` → persistent "Connection lost" banner in top bar
- Global error boundary in `App.tsx`: catches crashes, shows reload option
- All styles from `theme.ts`
**Acceptance:** Kill backend → "Connection lost" banner. Every panel has an empty state. No blank white areas anywhere.

---

### Step 35 — `feat: add keyboard shortcuts and panel collapse controls`
**Owner:** Aria
**Touches:** `src/frontend/src/hooks/useKeyboard.ts`, `src/frontend/src/pages/Editor.tsx`
**What happens:**
- `useKeyboard.ts`: `Cmd/Ctrl+S` → save. `Cmd/Ctrl+R` → run (if not already running). `Backspace`/`Delete` → remove selected node (when not focused in Monaco or an `<input>`). `Escape` → deselect node.
- `Editor.tsx`: collapse buttons on panel edges. Collapsed → `w-0 overflow-hidden`. `transition-all duration-200`. Chevron icon rotates 180° when collapsed.
- All styles from `theme.ts`
**Acceptance:** Keyboard shortcuts work as specified. Panels collapse and expand smoothly.

---

### Step 36 — `feat: add onboarding hint bar for first-run experience`
**Owner:** Aria
**Touches:** `src/frontend/src/components/ui/OnboardingHint.tsx`, `src/frontend/src/components/canvas/GraphCanvas.tsx`
**What happens:**
- `OnboardingHint.tsx`: dismissible banner above canvas. "Drag a node from the left to start — or describe your goal in the chat →". Dismiss sets `localStorage.setItem('hint_dismissed','true')`.
- Not shown if `nodes.length > 0` or previously dismissed.
- All styles from `theme.ts`
**Acceptance:** Empty graph → hint visible. Adding a node → hint disappears. Dismiss → hidden on reload.

---

### Step 37 — `feat: final integration smoke test and README`
**Owner:** Claude
**Touches:** `README.md`, `src/backend/api/routes.py`, `src/backend/storage/graph_store.py`
**What happens:**
- Manual end-to-end smoke test: load demo → run → watch execution → type "add a node that uppercases the output" → approve diff → run again → verify new node runs
- Any wiring bugs found during smoke test fixed in this step (in Claude's domain files only)
- `README.md`: setup instructions, dev commands, 5-step demo walkthrough, env var table
- `.env.example` reviewed — all required vars documented
**Acceptance:** Full demo scenario runs without console errors. README is accurate and complete.

---

### Step 38 — `feat: final visual audit — build check, token audit, state coverage`
**Owner:** Aria
**Touches:** All `src/frontend/src/components/**`, `src/frontend/src/pages/Editor.tsx`
**What happens:**
- `pnpm run build` — must exit 0 with zero TypeScript errors
- Visual audit checklist:
  - Every node type renders correctly at: idle, selected, running, complete, error, cached, agent-generated
  - Every panel has: loading state, empty state, error state
  - DiffCard renders cleanly at 1, 5, and 8 diffs
  - "✦ AI" badge visible on all agent-generated nodes
  - All transition durations consistent with `TRANSITIONS` tokens
  - Zero hardcoded Tailwind strings — every class string traced to `theme.ts`
**Acceptance:** `pnpm run build` exits 0. All node states render correctly. All panels have designed states. Zero hardcoded strings.

---

*End of protocol. 38 steps. 7 phases. Build in order. Ship in one week.*

---

## Dependency map — why this order is correct

```
Step 1  (Claude)  Backend scaffold       ← prerequisite for everything backend
Step 2  (Claude)  Frontend scaffold      ← prerequisite for everything frontend
         │
Step 3  (Rex)     Graph models           ← ALL agents depend on NodeSpec, Graph, NodeOutput
Step 4  (Rex)     Diff models            ← Nova, Claude, Aria all depend on DiffBundle, OrchestratorDecision
Step 5  (Rex)     Node registry          ← Nova needs list_node_types(), Claude exposes it, Aria renders it
         │
Step 6  (Aria)    Tokens + shell         ← Needs Steps 1–2 running. Blocks all Aria component work.
Step 7  (Claude)  Zustand store          ← Needs Steps 3–4 types. Blocks all Aria component work.
Step 8  (Aria)    Canvas + BaseNode      ← Needs store (7), NodeSpec shape (3)
Step 9  (Aria)    Node palette           ← Needs canvas (8), registry shape (5)
Step 10 (Aria)    Node editor panel      ← Needs store (7), NodeSpec.code (3)
Step 11 (Claude)  Storage + API shell    ← Needs models (3–4), registry (5)
Step 12 (Claude)  Save/load wiring       ← Needs API (11), store (7)
         │
Step 13 (Rex)     Sandbox                ← No dependencies
Step 14 (Rex)     Cache                  ← Needs NodeSpec (3)
Step 15 (Rex)     Runner                 ← Needs sandbox (13), cache (14), models (3–4)
Step 16 (Claude)  SSE endpoint           ← Needs runner (15), routes (11)
Step 17 (Aria)    Execution UI           ← Needs SSE (16), store (7), BaseNode (8)
Step 18 (Claude)  RUN mode guard         ← Needs routes (11), GraphState (3)
         │
Step 19 (Nova)    Node agent             ← Needs diff models (4), registry (5)
Step 20 (Nova)    Graph-writer agent     ← Needs diff models (4), registry (5)
Step 21 (Nova)    Orchestrator           ← Needs node agent (19), graph-writer (20)
Step 22 (Nova)    LLM node execution     ← Needs NodeSpec (3), config (1)
Step 23 (Rex)     LLM → runner           ← Needs runner (15), LLM node (22)
Step 24 (Claude)  Agent API endpoints    ← Needs all 3 agents (19–21), routes (11), guard (18)
Step 25 (Aria)    Chat panel             ← Needs agent API (24), store (7)
Step 26 (Aria)    Diff card              ← Needs chat panel (25), DiffBundle shape (4)
Step 27 (Aria)    Node animations        ← Needs store isNew flag (7), BaseNode (8)
         │
Step 28 (Claude)  Version snapshots      ← Needs storage (11), approve endpoint (24)
Step 29 (Aria)    Version history UI     ← Needs version API (28)
Step 30 (Claude)  Restore wiring         ← Needs version API (28), store loadGraph (7)
         │
Step 31 (Claude)  Demo graph             ← Needs full execution stack (15–23)
Step 32 (Aria)    LLM config UI          ← Needs node editor (10), NodeSpec.config (3)
Step 33 (Aria)    Token badge            ← Needs execution UI (17), LLM node (22–23)
         │
Step 34 (Aria)    Error states           ← Needs all panels (8–33)
Step 35 (Aria)    Keyboard shortcuts     ← Needs full editor
Step 36 (Aria)    Onboarding hint        ← Needs canvas (8), store (7)
Step 37 (Claude)  Final integration      ← Everything complete
Step 38 (Aria)    Build check + audit    ← Everything complete
```

---

## Timeline

| Day | Steps | Owner focus | Goal |
|---|---|---|---|
| Day 1 | 1–6 | Claude + Rex + Aria | Servers start. All models locked. Token system live. |
| Day 2 | 7–12 | Claude + Aria | Canvas works. Nodes drag. Save/load live. |
| Day 3 | 13–18 | Rex + Claude + Aria | Code runs. Results stream. Canvas lights up. |
| Day 4 | 19–22 | Nova | All three agents + LLM node built and tested. |
| Day 5 | 23–27 | Rex + Claude + Aria | LLM integrated, agent API live, chat panel + diff card. |
| Day 6 | 28–33 | Claude + Aria | Version history, demo graph, LLM config UI. |
| Day 7 | 34–38 | Aria + Claude | Polish, error states, keyboard shortcuts, build check. |
