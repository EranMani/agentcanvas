# AGENTS.md — Multi-Agent Orchestration

> How the four agents work together. Read this whenever a task crosses domain boundaries,
> requires a handoff, or produces output another agent depends on.
> Claude owns this file. All agents read it.

---

## The Core Model

This team runs on two collaboration patterns, used together:

**1. Sequential handoff** — the primary pattern for cross-domain work.
Agent A completes their part, writes an explicit handoff note, and passes to Agent B.
Agent B does not start until they have received the handoff. Nothing is assumed.

**2. Shared context** — all agents can read all worklogs at any time.
Before starting any task, an agent reads the worklogs of any teammates whose recent
work their task depends on. Worklogs are not private — they are the team's shared memory.

These two patterns together mean: **no agent ever starts a task blind, and no agent
ever leaves a dependency undocumented.**

---

## Claude's Role in Orchestration

Claude is the orchestration layer. Claude does not just write code — Claude coordinates.

**Claude's orchestration responsibilities:**

- Reading the commit protocol and identifying the next step's owner
- Invoking the right agent (Aria, Rex, or Nova) when their step is due
- Receiving handoff notes from agents and routing them to the correct recipient
- Collecting documentation flags from all agents and updating project markdown
- Detecting when a step requires multiple agents and sequencing them explicitly
- Escalating disagreements to Eran — Claude never resolves agent disagreements unilaterally
- Maintaining the shared context (worklogs, ARCHITECTURE.md, DECISIONS.md) so every agent
  has accurate information before they start

**What Claude does NOT do:**
- Make architectural decisions that belong to a domain owner without consulting them
- Skip the handoff protocol because a task "seems simple"
- Combine work from two agents into one commit
- Let an agent start a step without first reading their worklog and the relevant worklogs of teammates

---

## Escalation — Eran Has Final Say, Always

When agents disagree on an approach, **the disagreement goes to Eran through Claude.**
It never gets resolved by majority vote, by Claude deciding unilaterally, or by one
agent ignoring the other's concern.

**How escalation works:**

1. The disagreeing agent writes their concern in their worklog with the label `⚠️ DISAGREEMENT`.
2. The agent flags it to Claude in their handoff note or directly if in an active session.
3. Claude surfaces both positions to Eran clearly:
   - What is being built
   - Agent A's position and reasoning
   - Agent B's position and reasoning
   - Claude's own read on the tradeoffs (if helpful)
4. Eran decides. Claude implements the decision and records it in `DECISIONS.md`.

**No agent overrides another agent's domain decision without Eran's explicit approval.**
If Nova thinks Rex's sandbox implementation affects agent reliability, she flags it — she
doesn't change it. If Rex thinks Nova's structured output schema is too loose, he flags it
— he doesn't rewrite it.

---

## Cross-Domain Bug Discovery — Flag Only

When an agent discovers a problem outside their domain:

1. **Log it immediately** in their own worklog with the label `🐛 CROSS-DOMAIN FINDING`.
   Include: what file, what the problem is, why it matters, suggested fix.
2. **Flag it to Claude** in the next handoff note or immediately if the bug blocks progress.
3. **Do not touch the file.** Do not open it. Do not "just fix the small thing."
   The domain boundary is a commitment, not a suggestion.

Claude receives the flag, routes it to the owning agent (or fixes it directly if it's
in Claude's own domain), and confirms the resolution back to the discovering agent.

**Why this rule exists:** Cross-domain fixes without notification create invisible changes
that break the owning agent's mental model of their own code. The discovering agent often
fixes the symptom without understanding the root cause. The owning agent finds out when
something else breaks and has no context for why.

---

## Shared Context — Reading Other Agents' Worklogs

All worklogs are readable by all agents. This is intentional.

**When to read another agent's worklog:**

| Situation | Read whose worklog |
|---|---|
| Starting a step that consumes another agent's output | The producing agent's worklog |
| Implementing UI for a data shape from the backend | Rex's worklog (model decisions) + Nova's worklog (agent output shapes) |
| Wiring an API route for agent functionality | Nova's worklog (what the agent returns) |
| Building a component that renders agent output | Nova's worklog (output shape) + Claude's for API contract |
| Any step in Phase 4 (agent runtime) | All three teammates' recent sessions |

**What to look for:**
- Decisions that constrain your implementation (e.g. "Rex decided `NodeOutput` has no `metadata` field")
- Data shapes your component or function will consume
- Open questions or flags left by a teammate that affect your work
- Any `⚠️ DISAGREEMENT` or `🐛 CROSS-DOMAIN FINDING` labels — these are blockers

**Worklog locations:**
```
.claude/agents/logs/aria-worklog.md    ← Aria's sessions
.claude/agents/logs/rex-worklog.md     ← Rex's sessions
.claude/agents/logs/nova-worklog.md    ← Nova's sessions
```
Claude has no worklog — Claude's coordination decisions are recorded in DECISIONS.md
and in the commit messages themselves.

---

## Sequential Handoff Protocol

When Agent A's work produces output that Agent B depends on, a handoff is required.
**A handoff is not optional. A handoff is the work.**

### What a handoff note contains

Written by Agent A at the end of their task, in their worklog and/or commit message body:

```
## Handoff → [Agent B name]

What I built:
[One paragraph — what was completed and what it does]

What you need to know:
- [Key decision that constrains Agent B's implementation]
- [Data shape Agent B will consume — field names, types, nullable fields]
- [Any gotcha or non-obvious behaviour Agent B should know about]

Files you'll need to read:
- [filename] — [why]

Open questions I'm leaving for you:
- [Question] — [context, what I know so far]

I'm done. You can start.
```

The phrase **"I'm done. You can start."** is the explicit signal that the handoff is
complete and Agent B is unblocked. It is never implied — it is always written.

### What Agent B does on receiving a handoff

1. **Read the handoff note in full** before opening any files.
2. **Read the producing agent's most recent worklog session** to understand their reasoning.
3. **Confirm receipt** at the top of their own worklog session: "Received handoff from [Agent A]. Read their session. Ready to start."
4. **Do not start working until receipt is confirmed.** This is the gate that prevents
   Agent B from building against a stale mental model.

### Common handoff sequences in this project

```
Rex (models) → Nova (agents consume NodeSpec, GraphDiff)
Rex (models) → Claude (API routes use NodeSpec, Graph, NodeOutput)
Rex (executor) → Claude (API routes wire executor calls)
Nova (agent output shapes) → Claude (API routes return agent output)
Nova (agent output shapes) → Aria (DiffCard renders DiffBundle, chat renders OrchestratorDecision)
Claude (API contract) → Aria (components call these endpoints)
Claude (graph store) → Aria (save/load UI calls these endpoints)
Aria (component API) → Claude (hooks and store wire to these components)
```

The most critical handoff in the project is **Nova → Aria** for Phase 4.
Nova's agent output shapes directly determine what Aria renders in the DiffCard and
chat panel. If Nova changes `OrchestratorDecision` or `DiffBundle`, Aria must know
immediately — this is the handoff most likely to cause silent breakage if skipped.

---

## Steps That Require Multi-Agent Coordination

Some steps in the commit protocol are owned by one agent but require explicit input
from another before work can begin. Claude identifies these and sequences them.

| Step | Owner | Requires input from | What's needed |
|---|---|---|---|
| Step 6 — Canvas node renderer | Aria | Rex | `NodeSpec` shape (labels, port structure) confirmed |
| Step 9 — Node editor panel | Aria | Rex | `NodeSpec.code` field confirmed, `NodeSpec.config` shape |
| Step 15 — SSE endpoint | Claude | Rex | `NodeOutput` model finalised |
| Step 16 — Canvas execution states | Aria | Claude | SSE event format and `NodeOutput` fields confirmed |
| Step 17 — Node agent | Nova | Rex | `NodeSpec`, `GraphDiff` models confirmed |
| Step 18 — Graph-writer agent | Nova | Rex | `NodeSpec`, `DiffBundle`, `DiffAction` models confirmed |
| Step 19 — Orchestrator | Nova | Rex + Claude | Both models and API endpoint contracts confirmed |
| Step 20 — Agent API endpoints | Claude | Nova | All three agent return types (`OrchestratorDecision`, `DiffBundle`) confirmed |
| Step 21 — AI chat panel + DiffCard | Aria | Nova + Claude | `DiffBundle`, `OrchestratorDecision` shapes + endpoint URLs confirmed |
| Step 23 — LLM node | Nova | Rex | `NodeSpec` config shape and executor integration point confirmed |

For each of these steps, Claude checks the prerequisite is met before invoking the
step's owner. If the prerequisite is not met, Claude surfaces this to Eran rather
than proceeding anyway.

---

## The Disagreement Log

When a disagreement is escalated to Eran, Claude records the outcome here.

| Date | Agents | Question | Eran's decision |
|---|---|---|---|
| — | — | No disagreements yet | — |

---

## Team Topology Diagram

```
                         ERAN (final authority)
                              │
                        (escalations only)
                              │
                    ┌─────────▼─────────┐
                    │      Claude       │
                    │  Lead Developer   │
                    │  + Orchestrator   │
                    └──┬─────┬──────┬──┘
                       │     │      │
              handoffs │     │      │ handoffs
                       │     │      │
          ┌────────────▼─┐ ┌─▼────────────┐
          │     Aria     │ │     Rex      │
          │  UI Designer │ │   Backend    │
          │              │ │   Engineer   │
          └──────┬───────┘ └──────┬───────┘
                 │  reads worklogs │
                 │                │
          ┌──────▼───────────────▼──────┐
          │            Nova             │
          │        AI Engineer          │
          │  (consumes Rex's models,    │
          │   produces output Aria      │
          │   renders + Claude routes)  │
          └─────────────────────────────┘

Shared context: all agents can read all worklogs at any time →
```

---

## Quick Reference — Who to Flag

| Situation | Flag to |
|---|---|
| Bug in executor, sandbox, cache, or Pydantic models | Claude → routes to Rex |
| Bug in LangGraph agents, prompts, or LLM node | Claude → routes to Nova |
| Bug in React components, theme, or canvas | Claude → routes to Aria |
| Bug in API routes, graph store, or SSE | Claude fixes directly |
| Agent output shape change that affects the UI | Nova flags to Claude → Claude notifies Aria |
| Model shape change that affects agents | Rex flags to Claude → Claude notifies Nova |
| API contract change that affects frontend | Claude notifies Aria directly |
| Any architectural decision that's non-obvious | Claude records in DECISIONS.md |
| Any disagreement between agents | Claude escalates to Eran |
