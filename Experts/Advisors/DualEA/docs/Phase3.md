# Phase 3 — Polish, Lockdown, and Final Scoring (DualEA)

This document drives Phase 3 execution across three cycles, with traceability to files and decisions. It consolidates findings from Phase 1–2, finalizes docs, hardens the codebase, and sets a roadmap.

## Scope & Objectives
- Align documentation with actual behavior (architecture, gating, fallback, scaling, exploration, KB I/O).
- Apply code hygiene and consistency across modules.
- Score components for completeness/quality and publish a forward roadmap.

## Artifacts & Modules (Traceability)
- `PaperEA/PaperEA.mq5`: policy gating, default fallback, exploration, scaling application.
- `Include/StrategySelector.mqh`: insights aggregation and `Score()` with strict/non‑strict behavior.
- `Include/TradeManager.mqh`: order execution, SL/TP, trailing.
- `Include/KnowledgeBase.mqh`: CSV schemas and writes.
- `Experts/DualEA/README.md`: repo‑level docs, links, and workflows.
- Policy & Insights files in Common Files: `Common\Files\DualEA\policy.json`, `insights.json`, `knowledge_base*.csv`.

---

## Cycle 1: Docs & Architecture Alignment
- Architecture:
  - Confirm Mermaid diagram matches current data flow (PaperEA ↔ KB ↔ Trainer ↔ policy.json; optional LiveEA).
  - Document the policy reload signal `policy.reload` and timer behavior.
- Default Policy Fallback (recap):
  - Inputs: `DefaultPolicyFallback`, `FallbackWhenNoPolicy`, `FallbackDemoOnly`, `UsePolicyGating`.
  - Loaded state: policy is considered loaded when slices > 0; `min_confidence` is a gating threshold only.
  - Fallback paths and logs:
    - `fallback_no_policy`: no slices present; demo‑only by default; neutral scaling; bypass exploration caps.
    - `fallback_policy_miss`: slices exist but missing exact slice; neutral scaling; bypass exploration caps.
  - Scaling: `ApplyPolicyScaling()` runs only when a valid slice exists; fallback uses neutral scaling.
- Selector behavior:
  - Exact slice: thresholds enforced per `strict_thresholds`. Non‑strict: sample‑size scaling to smooth bootstrap.
  - Fallback 1 (strategy+symbol): strict thresholds respected; non‑strict scaling by `total/th_min_trades`.
  - Fallback 2 (strategy only): aligned to mirror Fallback 1 (strict respected; non‑strict scaled).
- KB Schemas: ensure columns and file locations documented in README are correct.

Deliverables:
- README updated with Default Policy Fallback and a link to this Phase 3 doc.
- This file (Phase3.md) as the canonical Phase 3 spec.

Acceptance:
- Docs clearly describe when fallback triggers, logs emitted, scaling behavior, and exploration interaction.

---

## Cycle 2: Code Hygiene & Consistency
- Naming & structure:
  - Ensure consistent prefixes for log lines: `GATE:`, `FALLBACK:`, `EXPLORE:`, `POLICY:`.
  - Remove dead code/unused inputs; align input names with README.
  - Confirm `NormalizeSymbol()` usage wherever symbol comparisons occur.
- Safety & robustness:
  - Validate file I/O error handling for Common Files (read/write paths exist, header creation).
  - Ensure early returns in gating paths leave consistent state (no partial side‑effects).
- Selector consistency:
  - Confirm Fallback 2 update is in `Include/StrategySelector.mqh` (strict respected; non‑strict scaled).
- Testing hooks (optional):
  - Temporary debug toggles to log `Score()` per decision; remove after QA.

Deliverables:
- Minor refactors where needed; consistent log format; dead code removal tracked in commit messages.

Acceptance:
- Consistent logging, no misleading branches, selectors aligned across fallbacks.

---

## Cycle 3: Final Scoring + Roadmap
- Component scoring (1–5):
  - Policy gating & fallback: 5 if all validation criteria pass and docs complete.
  - Exploration caps persistence: 4–5 depending on backtest coverage.
  - Selector consistency: 4–5 (post‑alignment).
  - TradeManager resilience: 4–5 (based on error handling tests).
  - KB logging completeness: 4–5.
- Roadmap (shortlist):
  - Per‑slice confidence thresholds and weights sourced directly from `policy.json`.
  - Timer‑based policy reload cadence with jitter; debounced file‑watch alternative.
  - LiveEA skeleton with circuit breakers and shared KB.
  - Telemetry CSV/JSON for monitoring (latency, SL moves, error rates).

Deliverables:
- Scoring notes and a prioritized backlog (below).

Acceptance:
- Scoring documented with rationale; backlog items actionable and linked to modules.

---

## Phase 2 Validation Checklist (for sign‑off)
- Fallbacks trigger only on `fallback_no_policy` (no slices) or `fallback_policy_miss` (slice absent).
- Fallbacks: neutral scaling, do not increment exploration counters.
- Clear log lines for fallback vs explore vs gated.
- Policy loaded state tied to slice presence, not `min_confidence`.
- Selector Fallback 2 mirrors Fallback 1 (strict respected; non‑strict scaled).

---

## Jailbreak Findings Trace (from Phase 1–2)
- `PaperEA.mq5` — `Policy_Load()`: set `g_policy_loaded = (ArraySize(g_pol_strat)>0)` to avoid false fallbacks when `min_confidence=0.0`.
- `StrategySelector.mqh` — `Score()` Fallback 2: aligned thresholds/scaling to avoid hard zero during bootstrap in non‑strict mode.

---

## Appendix: Log Examples
- Fallback no policy: `FALLBACK: no policy loaded -> neutral scaling used for <strat> on <symbol>/<tf> demo=<true|false>`
- Fallback policy miss: `FALLBACK: policy slice missing -> neutral scaling used for <strat> on <symbol>/<tf> demo=<true|false>`
- Explore allow: `GATE: explore allow <strat> on <symbol>/<tf> ... (day=d/D, week=w/W)`
