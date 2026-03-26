# Mira — Product Manager Worklog

> All product observations, inter-agent suggestions, and session notes live here.
> Claude reads this log to track Mira's product input and route it appropriately.

---

## Session Index

| Date | Session | Status | Key Output |
|---|---|---|---|
| 2026-03-25 | Product direction — teaching + RAG demo | ✅ Done | 4 decisions logged in DECISIONS.md |

---

## Session 001 — 2026-03-25
### Product Direction: Teaching-First + RAG Pipeline Milestone

**Triggered by:** Eran raised the idea of making AgentCanvas both a learning/teaching
platform and a builder — showing LangChain/LangGraph modules as nodes with explanations
and examples. Claude summarised the idea and brought me in.

**The product question I was asked to answer:**
1. Is this the right direction? Any concerns?
2. Which nodes to prioritise for v1?
3. How should the teaching experience feel to a developer opening the product for the first time?

---

**My take on the direction:**
Strong. The gap is real — LangChain/LangGraph documentation is technically thorough and
experientially terrible. A canvas where each node is simultaneously a concept, running
code, and annotated example is a genuinely better learning experience than docs.

**Framing correction I proposed:**
Don't position this as an "interactive tutorial." Position it as: *you are building, and
understanding arrives with you.* The developer who wants a RAG pipeline today — not in
six months — opens this, describes their goal, the AI builds the graph, each node explains
itself as it lands, they have a working prototype in fifteen minutes. Learning is a side
effect of doing.

**v1 node set I proposed (12 nodes):**
LLM Call, Prompt Template, Document Loader, Text Splitter, Embeddings,
Vector Store/Retriever, Output Parser, Conditional Router, Memory/Chat History,
Tool/Function Call, Human-in-the-Loop Checkpoint, Graph Entry/Exit.
Output Parser is first cut if scope requires it.

**Teaching experience feel:**
Explanation panel opens automatically when AI places a node (3–5 seconds), then collapses
unless engaged. Three questions answered per node: what does it do? when would you use it?
minimal runnable example. No walls of text. Developers who know it skip it; developers
who don't get exactly what they need.

**RAG pipeline as first demo:**
Endorsed strongly. It's universally recognised, it's becoming infrastructure for every
company, and watching the AI assemble it from plain language is the "I need this" moment
for the target audience.

**Concern I raised that hadn't been flagged:**
The explanation content is a product. If AI-generated at runtime — inconsistent quality.
Recommendation: hardcoded content, reviewed and approved by Eran. The explanation panel
is the product's voice.

---

**Decisions logged in DECISIONS.md:**
- DEC-001: Teaching-first product direction
- DEC-002: RAG pipeline as first milestone demo
- DEC-003: Node explanation tone (senior AI engineer voice)
- DEC-004: v1 node set (12 nodes)

---

**Inter-agent suggestions logged for Claude to route:**

💡 Suggestion → Nova
What I noticed: the graph-writer agent's chat narration is currently designed to describe
what it's doing ("adding Embeddings node"). That's not enough for the teaching use case.
Why it matters to the user: the narration IS the learning experience. A user who doesn't
know what an Embeddings node does should understand it from watching the AI place it.
My suggestion: Nova should design the graph-writer's narration to explain *why* each node
is being added at that point in the pipeline — not just what. Example: "I'm adding an
Embeddings node here because we need to convert the documents to vectors before retrieval —
this is what makes semantic search possible rather than keyword matching."
I'd love your thoughts.

💡 Suggestion → Aria
What I noticed: all nodes currently share the same visual treatment. When the canvas
has 8–12 different node types, the user needs to read every label to understand the
pipeline structure.
Why it matters to the user: comprehension before reading. A colour or icon grouping by
category (retrieval nodes, generation nodes, control flow nodes) lets the developer read
the pipeline's shape at a glance.
My suggestion: design a node category visual language — subtle, not garish — that groups
nodes by function. Retrieval nodes (Document Loader, Text Splitter, Embeddings, Vector Store)
in one family; generation nodes (LLM Call, Prompt Template, Output Parser) in another;
control flow (Conditional Router, Human-in-the-Loop, Entry/Exit) in a third.
I'd love your thoughts.

---

✨ To Claude: the 8–12 node constraint was exactly the right product instinct. Protecting
demo quality over feature breadth at this stage is the correct call. Well reasoned.
