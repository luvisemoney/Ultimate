# DualEA Action Framework — Pre-Implementation Plan

Purpose: define a rigorous, end-to-end framework for adding missing DualEA capabilities (from PaperEA to LiveEA) before touching code. This follows a 3 Phases × 3 Cycles model with explicit deliverables, risks, acceptance criteria, and rollback.

Related docs:
- `./DualEA_Lifecycle_Handbook.md`
- `./Operations.md`
- `./PaperEA_README.md`, `./LiveEA_README.md`

---

## Phase 1 — Codebase & Requirements Deep Dive

### Cycle 1: Structural Audit (Jailbreak permitted)
- Scope: `../PaperEA/PaperEA.mq5`, `../LiveEA/LiveEA.mq5`, `../Include/*`, `../ML/*`.
- Actions:
  - Inventory gating paths: strategy → policy → insights → execution.
  - Trace file I/O and timers: `CheckPolicyReload()`, `CheckInsightsReload()`, `Insights_IsStale()`.
  - Identify extension points for: circuit breakers, session filter, news filter, PositionManager, correlation, vol sizing, regime.
- Deliverables:
  - Audit map (diagram) + list of insertion points per feature.
  - Risk log: side-effects, perf hot paths, shared state.

### Cycle 2: Requirements Mapping
- Map gaps vs target (from EscapeEA features):
  - Circuit breakers (daily loss, DD, cooldown).
  - Session/time windows.
  - News impact filter.
  - Position Manager (scaling, exits, clustering, per-symbol caps).
  - Correlation-aware exposure.
  - Volatility-based position sizing.
  - Regime detection hooks.
  - Promotion gate (mandatory paper success criteria).
  - Monitoring/analytics surfaces.
- Deliverables:
  - Spec one-pagers per feature with inputs, data flow, telemetry, and failure modes.

### Cycle 3: Risk & Gaps Closure
- Threat modeling: file-based races, stale artifacts, partial reloads.
- Decide default-safe behavior for LiveEA (fail-closed vs fail-open per feature).
- Deliverables:
  - Mitigations + rollback levers per feature.
  - Updated lifecycle with control gates.

---

## Phase 2 — Design, Build, Validate

### Cycle 1: Task Decomposition
- Create work items with IDs, deps, and DoD:
  - FR-01 Circuit Breakers d
  - FR-02 Session Filter d
  - FR-03 News Filter d
  - FR-04 Position Manager (v1 toggle + exits) d
  - FR-05 Correlation Exposure Caps d
  - FR-06 Volatility Position Sizing d
  - FR-07 Regime Detector Stub d
  - FR-08 Promotion Gate Criteria & Evaluator Script d
  - FR-09 Telemetry Standardization + Ops Views d
  - FR-10 Performance: event batching/log throttling d
- Deliverables: backlog with effort, risk, owner, and sequencing.

### Cycle 2: Code + Peer Review (to be executed later)
- Definition of Ready to Implement (per item):
  - Inputs defined with ranges and defaults.
  - Telemetry events standardized (`gate:*`, `exec:*`, `cb:*`).
  - Failure/rollback behavior specified.
- Code guidelines:
  - Feature flags: `Use*` inputs, default-off for LiveEA where risky.
  - Shared include modules under `../Include/`.

### Cycle 3: QA + Fuzzing (to be executed later)
- Tests per feature: unit-like MQL stubs, deterministic sims, and log assertions.
- Fuzz: input ranges, missing files, reload storms, high-tick rates.
- Deliverables: test checklist + pass/fail logs.

---

## Phase 3 — Polish, Lockdown, Final Scoring

### Cycle 1: Docs & Architecture Alignment
- Update `DualEA_Lifecycle_Handbook.md` with new controls.
- Add operator runbooks for each feature.

### Cycle 2: Code Hygiene & Consistency
- Consistent input names, enums, and log tags.
- Remove dead code, centralize shared helpers.

### Cycle 3: Final Scoring + Roadmap
- Score each feature on correctness, safety, observability, performance.
- Decide next iteration priorities.

---

## Action Backlog (Pre-Implementation Specs)

- FR-01 Circuit Breakers
  - Inputs: `UseCircuitBreakers`, `DailyLossLimit`, `DailyDrawdownLimit`, `CooldownMinutes`.
  - Behavior: block new entries; allow exits; emit `cb:trigger` with metrics.
  - Telemetry: `cb:check`, `cb:trigger`, `cb:cooldown_end`.
  - DoD: unit sims + day rollover tests.

- FR-02 Session/Window Filter
  - Inputs: `UseSessionFilter`, `SessionTZ`, `SessionWindows` (e.g., HH:MM-HH:MM per weekday).
  - Behavior: pre-gate block; overrideable by `NoConstraintsMode`.
  - DoD: windows honored; DST/tz edge cases documented.

- FR-03 News Filter
  - Inputs: `UseNewsFilter`, `ImpactLevelMin`, `PreLockoutMin`, `PostLockoutMin`.
  - Behavior: block around events per symbol/currency; offline safe fallback.
  - DoD: replay test with synthetic events.

- FR-04 Position Manager (v1)
  - Inputs: `UsePositionManager`, `ExitProfile` (Aggressive/Moderate/Conservative), `ClusterMinPts`, `PerSymbolMax`.
  - Behavior: centralized exits, clustering avoidance, scaling hooks.
  - DoD: backtest diffs vs baseline; safe on/off toggle.

- FR-05 Correlation Exposure Caps
  - Inputs: `UseCorrelationCaps`, `CorrLookbackDays`, `MaxGroupExposure`.
  - Behavior: compute simple correlation matrix from KB/returns; cap grouped exposure.
  - DoD: deterministic calc and cap enforcement tests.

- FR-06 Volatility Position Sizing
  - Inputs: `UseVolSizing`, `ATRPeriod`, `RiskPerTrade`.
  - Behavior: lot sizing inversely proportional to ATR; interacts with policy scaling.
  - DoD: consistent sizes across regimes; caps respected.

- FR-07 Regime Detector Stub
  - Inputs: `UseRegime`, `RegimeMethod` (trend/range/volatile via ADX/ATR/HHLL).
  - Behavior: tag regime in telemetry; optional gating modifier.
  - DoD: regime tags stable; no execution regressions when off.

- FR-08 Promotion Gate & Evaluator
  - Inputs: thresholds (min trades, hit-rate, expectancy, max DD, Sharpe).
  - Artifact: `Scripts/DualEA/AssessPromotion.mq5` outputs `promotion_report.txt` pass/fail.
  - DoD: reproducible on recent logs.

- FR-09 Telemetry Standardization & Ops Views
  - Spec: event schema, fields, severity; rotate/size bounds.
  - Optional: simple Python/CSV notebooks under `../ML/ops/` for dashboards.

- FR-10 Performance
  - Event batching for high-tick, log throttling, timer cadence review.
  - DoD: CPU/memory profile under stress.

---

## Control Gates (Before Coding)
- Gate A: Specs complete (inputs, flow, telemetry, rollback) for FR-01..FR-10.
- Gate B: Test plans defined; simulators/log assertions ready.
- Gate C: Security + fail-safe review for LiveEA defaults.

---

## Jailbreak Traces (Logging Plan)
- For each feature, maintain a trace section documenting:
  - Violations attempted (e.g., forced reload storms, corrupted files).
  - Observed behavior and telemetry evidence.
  - Fixes or design changes.

---

## Ownership & Sequencing (Draft)
- Wave 1 (risk first): FR-01, FR-02, FR-08.
- Wave 2 (exposure/positioning): FR-04, FR-05, FR-06.
- Wave 3 (context and perf): FR-03, FR-07, FR-09, FR-10.

Notes: All features default-off in LiveEA until validated in PaperEA.
