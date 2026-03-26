# Engineering Tasks & Backlog

Out-of-protocol tasks logged during active development.
Things discovered mid-step that don't belong in the current commit
but must not be forgotten.

**Status:** `[ ]` Open · `[~]` In Progress · `[x]` Done

---

## Task Index

| ID | Status | Title | Area | Raised by |
|---|---|---|---|---|
| T-001 | [ ] | Nova: research LangChain modules for RAG node execution | Backend / Nova | Eran |
| T-002 | [ ] | Write and approve 12-node explanation content | Content / Nova + Claude | Eran |

---

## Open Tasks

*Tasks are added here as they are discovered during development.*
*Each task includes: what needs to be done, why it was deferred, and when it should be addressed.*

---

### T-001 — Nova: research LangChain modules for RAG node execution
**Raised by:** Eran
**Area:** Backend / Nova
**Do before:** Step 18 (executor) — findings must inform how retrieval node types are implemented

**What:** Nova researches which LangChain/LangChain-community modules map directly to the 12-node
registry types — particularly the RAG chain: Document Loader, Text Splitter, Embeddings, Vector Store.
Focus on what is already available and usable without custom code:
- `langchain_community.document_loaders` — which loaders are practical for a demo?
- `langchain.text_splitter` / `langchain_text_splitters` — RecursiveCharacterTextSplitter defaults
- `langchain_openai.OpenAIEmbeddings` / `langchain_anthropic` equivalents
- `langchain_community.vectorstores.Chroma` — Chroma is the target vector store (Eran's call)
- How these wire together in a LangChain RAG chain vs individually as nodes

**Why deferred:** Node executor (Step 19) raises NotImplementedError for all non-code/LLM types.
Nova's research shapes what Rex implements in the executor for those types.

**Output:** Nova writes a findings note in her worklog. Claude routes relevant decisions to Rex
before Step 18. Any new dependencies flagged to Adam for `.env.example` / `pyproject.toml`.

---

### T-002 — Write and approve 12-node explanation content
**Raised by:** Eran
**Area:** Content — Nova + Claude write, Mira reviews, Eran approves
**Do before:** Step 16 (ExplanationPanel) — Aria needs real content, not placeholders

**What:** Write the `explanation` and `example` fields for all 12 node types in the registry.
Voice: senior AI engineer, not documentation (DEC-003). Three things per node:
what it does, when to use it, what will quietly break if you get it wrong.
Example format: `explanation` = 2–4 sentences in that voice. `example` = minimal runnable snippet
or config that shows the node working, not just its signature.

**Process:**
1. Nova drafts all 12 — she knows the AI engineering context best
2. Claude reviews for consistency and teaching voice
3. Mira reviews for user framing ("would a developer opening this for the first time understand it?")
4. Eran approves — final say on the product's voice

**Why deferred:** Rex puts placeholder text in Step 7. Real content can be written in parallel
with Steps 8–15 (canvas + API shell) without blocking the build.

---

## Done Tasks

*Completed tasks moved here for record-keeping.*
