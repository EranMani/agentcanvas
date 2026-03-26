# Design Decisions

Non-obvious choices made during development — what was decided, why, and what was rejected.
Claude owns this file. All agents flag entries; Claude writes them.

Format: `DEC-XXX — [Title]`

> This file is populated in real time as decisions are made during development.

---

## DEC-001 — Teaching-first product direction

**Decision:** AgentCanvas is both a builder and a teacher. Every node is simultaneously
a runnable component and an educational artifact — it carries an explanation and a minimal
working example. Learning is a side effect of building, not a prerequisite for it.

**Rationale:** LangChain and LangGraph are powerful but notoriously hard to get into.
Documentation is fragmented; examples are abstract. A visual canvas where each node
explains itself — in the voice of a senior AI engineer, not a documentation bot — collapses
the gap between "reading about it" and "using it." The target user is a developer who
wants to build a RAG pipeline or agent loop today, not study for six months first.

**Raised by:** Eran. Shaped in discussion with Mira.

**Rejected framing:** "Interactive tutorial" — this framing makes learning the goal and
building the reward at the end. The correct framing is: you are building, and understanding
arrives with you.

---

## DEC-002 — RAG pipeline as the first milestone demo

**Decision:** The first complete graph the AI agent builds on the canvas is a working
RAG pipeline: Document Loader → Text Splitter → Embeddings → Vector Store → LLM Call
with retrieved context.

**Rationale:** RAG is becoming infrastructure, not a feature — every company with internal
data will need it. The pattern is universally recognised by the target audience (developers).
Watching the AI assemble this graph from a plain-language description, with each node
explaining itself as it lands, is the moment that makes people think "I need this for
my company." It is also a complete, meaningful, runnable result — not a toy example.

**Raised by:** Eran and Mira.

**Implication for the build:** The node set, the graph-writer agent's output, and the
explanation panel UI must all be ready together for this milestone to land. It is not
a backend milestone or a frontend milestone — it is a full-stack moment.

---

## DEC-003 — Node explanation tone: senior AI engineer, not documentation

**Decision:** Node explanation content is written in the voice of a senior AI engineer
giving genuine advice — conversational, specific, opinionated where appropriate. It is
not documentation copy.

**Rationale:** The difference is substantial. Documentation says what something is.
A senior engineer says what you need to know to use it well — including the thing that
will quietly break your application if you get it wrong. That voice builds trust and
makes users feel like they have someone experienced in the room with them.

**Example of the wrong tone:** "TextSplitter divides documents into chunks of a specified
size with optional overlap."

**Example of the right tone:** "The chunk size is the thing that will quietly ruin your
retrieval quality if you get it wrong — most people set it too large and then wonder why
their answers are vague. Start at 500 tokens with a 50-token overlap and adjust from there."

**Raised by:** Eran. Each node explanation must be reviewed and approved by Eran before
the demo. This content is the product's voice — it cannot be AI-generated filler.

---

## DEC-005 — Demo API key model: Eran's key with session-based user key fallback

**Decision:** The demo uses a two-tier API key model:
1. Eran's OpenAI key (from deployment env) is used for the first **3** uses per browser session
   (tracked in localStorage — no server-side storage)
2. After N uses, a modal prompts the user to enter their own OpenAI or Anthropic API key
3. User-provided keys are held in browser session memory only — sent via `X-User-API-Key`
   request header per call, never persisted server-side
4. IP-based rate limiting (FastAPI `slowapi`) as a backstop against localStorage-clearing abuse

**Rationale:** Gives users enough free experience to understand the product without
building a user auth system (v2 scope). No database, no encrypted key storage, no
Alembic — consistent with demo non-negotiables. Eran loads his OpenAI account with
a fixed budget; low N keeps costs proportional to real interest.

**Upgrade path:** When the demo attracts enough attention, v2 adds GitHub OAuth,
PostgreSQL usage tracking, encrypted key storage, and a proper freemium quota system.

**Raised by:** Eran.

**Implementation owners:**
- Rex: `X-User-API-Key` header resolution in API routes, `slowapi` IP rate limiting
- Aria: localStorage N-use counter, post-N modal UI, header injection in API client
- Adam: Eran's key as deployment secret (never in code), HTTPS enforced in deployment
- Nova: LLM calls use whichever key Rex's route layer resolves — no agent-level change needed

---

## DEC-004 — v1 node set: 12 nodes covering core AI application patterns

**Decision:** The v1 node set contains exactly 12 nodes, selected by frequency of
appearance in real AI applications and explanation value (nodes that are confusing in
docs benefit most from this product).

**Node set:**
1. LLM Call
2. Prompt Template
3. Document Loader
4. Text Splitter
5. Embeddings
6. Vector Store / Retriever
7. Output Parser
8. Conditional Router
9. Memory / Chat History
10. Tool / Function Call
11. Human-in-the-Loop Checkpoint
12. Graph Entry / Exit

**Rationale:** "All available parts of LangChain" is a scope trap. These 12 cover the
most common patterns (RAG, agents, conversational apps, conditional routing) and together
tell a complete story on the canvas. Output Parser is the first candidate for cuts if
scope pressure requires it.

**Raised by:** Mira.

**Implication for Rex:** The node registry schema must include `explanation` (string) and
`example` (runnable code string) fields per node type.

**Implication for Nova:** The graph-writer agent narration must be written in teaching
voice — not just "adding Embeddings node" but explaining *why* that node is being added
at that point in the pipeline.

**Implication for Aria:** Nodes should have a visual language — colour or icon grouping
by category (retrieval, generation, control flow) — so the pipeline structure is readable
at a glance before a single label is read.
