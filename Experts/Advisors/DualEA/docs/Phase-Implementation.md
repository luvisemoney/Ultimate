# Phase Implementation Guide — DualEA System

**Complete roadmap for Phases 1-11 with status, TODOs, and best practices**

---

## Phase Status Overview

- ✅ **Phase 1**: Data & Insights Foundation - COMPLETE
- ✅ **Phase 2**: ML/LSTM Pipeline - COMPLETE
- ✅ **Phase 2a**: PaperEA Execution & Telemetry - COMPLETE
- 🔄 **Phase 3**: LiveEA & Feedback Loop - ACTIVE (hardening in progress)
- ✅ **Phase 4**: Risk & Safety Systems - COMPLETE
- 🔄 **Phase 5**: Dynamic Strategy Selection - PARTIAL (telemetry done, pruning planned)
- 📋 **Phase 6**: Low-Latency Scanner - PLANNED (OnTimer present, centralized scan needed)
- 🔄 **Phase 7**: Monitoring & Telemetry - PARTIAL (basic telemetry done, dashboard planned)
- 📋 **Phase 8**: Adversarial Hardening - PLANNED
- 📋 **Phase 9**: MLOps & Continuous Training - PLANNED
- 📋 **Phase 10**: Multi-Symbol Orchestration - PLANNED
- 📋 **Phase 11**: Performance & Resilience - PLANNED

---

## Phase 1: Data & Insights Foundation

### Status: ✅ COMPLETE

### Implemented Features

**Knowledge Base System**:
- `CKnowledgeBase`: Trade records to `knowledge_base.csv`
- `CFeaturesKB`: Long-format features to `features.csv` with 100MB rotation
- File locking, atomic writes, error handling
- Common Files persistence for Strategy Tester/Demo/Live compatibility

**Insights Generation**:
- `InsightsRebuild.mq5`: One-click insights.json generation from features.csv
- Per-slice analytics: win rate, total trades, avg R-multiple, Sharpe ratio
- Staleness detection and auto-rebuild triggers

**Data Schemas**:
- Documented in `docs/KB-Schemas.md`
- Version tracking for forward compatibility

### Remaining TODOs (Hardening & Ops)

**CI Integration**:
- [ ] Add `kb_check.bat` to CI pipeline
- [ ] Wire `Scripts/ValidateInsights.mq5` to fail on stale insights.json
- [ ] Assert non-empty/missing slices and required coverage

**Headless Operations**:
- [ ] Create `scripts/RunInsightsValidation.ps1` for scheduled validation
- [ ] Create `scripts/ScheduleInsightsValidation.ps1` for Windows Task Scheduler

**Schema Versioning**:
- [ ] Add version field to insights.json
- [ ] Implement compatibility checks in StrategySelector
- [ ] Document version migration paths

**I/O Hardening**:
- [ ] Ensure `FolderCreate("DualEA", FILE_COMMON)` in all writers
- [ ] Robust readers: skip malformed rows, log and continue
- [ ] Prefer `FILE_TXT|FILE_ANSI` flags

**Validator Enhancements**:
- [ ] Expand ValidateInsights to assert non-empty metrics per slice
- [ ] Add configurable thresholds for validation
- [ ] Surface concise validation report

**Ops Docs**:
- [ ] Create operator runbook for KB rebuild/validate flows
- [ ] Document artifact paths in Common Files
- [ ] Add exploration counter reset procedures

### Best Practices

1. **Run InsightsRebuild regularly**: At least weekly, more often during active development
2. **Monitor insights staleness**: Set alerts for insights older than 24 hours in live trading
3. **Validate before deployment**: Always run ValidateInsights before promoting to live
4. **Backup insights.json**: Keep versioned backups for rollback
5. **Feature schema stability**: Avoid breaking changes to features.csv format

---

## Phase 2: ML/LSTM Pipeline

### Status: ✅ COMPLETE

### Implemented Features

**Training Pipeline**:
- `ML/train.py`: TensorFlow/Keras with TimeSeriesSplit validation
- LSTM + Dense classifier architecture
- Yahoo Finance enrichment for market context
- ROC-AUC, Brier score, Expected-R metrics

**Feature Engineering**:
- `ML/features.py`: 50+ technical indicators
- Scaling and normalization
- Feature importance tracking

**Policy Export**:
- `ML/policy_export.py`: Converts trained model to policy.json
- Per-slice probability estimates with confidence thresholds
- SL/TP/lot/trail scaling multipliers
- Provenance metadata (model hash, train window, metrics)

### Remaining TODOs (Ops/Hardening)

**CI Trainer Job**:
- [ ] Run `ML/run_train_and_export.bat` on schedule or data-change trigger
- [ ] Publish policy.json to Common Files automatically
- [ ] Touch policy.reload for hot-reload trigger

**Provenance & Signing**:
- [ ] Include model hash, train window, metrics in policy.json
- [ ] Sign/hash policy.json for integrity verification
- [ ] Keep last-known-good policy for rollback

**Shadow Eval & A/B**:
- [ ] Support dual policies in PaperEA (shadow mode)
- [ ] A/B test policies before LiveEA promotion
- [ ] Track comparative performance metrics

**Calibration & Thresholds**:
- [ ] Generate reliability diagrams and Brier score decomposition
- [ ] Per-slice min_confidence calibration
- [ ] Document acceptance bands for policy promotion

**Monitoring**:
- [ ] Log SHAP/feature importance for drift detection
- [ ] Alert on material feature drift
- [ ] Track prediction distribution shifts

**Rollback Guardrails**:
- [ ] Auto-rollback to last-known-good on parse/plausibility failure
- [ ] Version control for policy.json
- [ ] Deployment history tracking

### Best Practices

1. **Walk-forward validation**: Use TimeSeriesSplit with expanding windows
2. **Track multiple metrics**: ROC-AUC, Brier, Expected-R, calibration
3. **Calibrate probabilities**: Use Platt scaling or isotonic regression
4. **A/B testing**: Always shadow-test new policies in PaperEA first
5. **Feature drift monitoring**: Set up alerts for distribution changes
6. **Provenance tracking**: Every policy should be traceable to training run

---

## Phase 2a: PaperEA Execution & Telemetry

### Status: ✅ COMPLETE

### Implemented Features

**PaperEA_v2 System (2793 lines)**:
- Modular strategies via IStrategy interface (21 active)
- Asset-class registry for symbol-specific strategy selection
- Exploration mode with daily/weekly caps
- NoConstraintsMode for unrestricted data collection
- Policy hot-reload structure (timer-based checking)
- Fallback gating with demo-only restrictions

**Advanced Optimization**:
- AdaptiveSignalOptimizer: ML-enabled signal refinement
- PolicyUpdater: Auto-generates policy.json every 60 minutes
- PositionReviewer: Reviews open positions every 5 minutes
- GateLearningSystem: Hybrid learning (immediate + batch)

**Telemetry**:
- TelemetryStandard wrapper for unified logging
- UnifiedTradeLogger: Daily JSON logs with full lifecycle
- Event-driven logging via EventBus

### Remaining TODOs

**CI Wiring**:
- [ ] Integrate ValidateInsights.mq5 into CI
- [ ] Add kb_check.bat to fail on stale/missing insights
- [ ] Assert required coverage (symbols/TFs/strategies)

**Headless Operations**:
- [ ] scripts/RunInsightsValidation.ps1 for scheduled runs
- [ ] scripts/ScheduleInsightsValidation.ps1 for Task Scheduler
- [ ] Automated insights rebuild triggers

**Ops Docs**:
- [ ] Operator runbook for rebuild/validate flows
- [ ] Document Common Files artifact locations
- [ ] Exploration counter reset procedures

**Telemetry Polish**:
- [ ] Emit concise summaries for insights rebuild/validation
- [ ] Standardize remaining telemetry event keys
- [ ] Dashboard integration (optional)

### Note

Timer-based scanning parity with LiveEA is tracked under Phase 6.

---

## Phase 3: LiveEA & Feedback Loop

### Status: 🔄 ACTIVE (Hardening in Progress)

### Implemented Features

**LiveEA System (1702 lines)**:
- Real broker execution via OrderSend()
- Insights gating with stricter thresholds than PaperEA
- Policy gating with confidence-based filtering
- Risk gates: spread, session, daily loss, drawdown, margin, consecutive losses
- News blackout filtering
- Exploration mode (stricter caps than PaperEA)
- PositionManager integration with correlation sizing

**Feedback Loop**:
- LiveEA logs to same KB as PaperEA
- ML trainer merges Paper+Live data
- Continuous learning cycle established

### Remaining TODOs

**Shadow Mode**:
- [ ] Log candidate decisions without executing
- [ ] Execute only top ML-ranked signals passing min_conf
- [ ] Shadow mode toggle input parameter

**Tighter Gates vs PaperEA**:
- [ ] Document gate threshold differences
- [ ] Validate stricter spread/news/session caps
- [ ] Lower exploration caps (1/2 vs 2/3 in Paper)

**Circuit Breakers**:
- [ ] Enforce max daily loss strictly
- [ ] Session drawdown tracking and limits
- [ ] Margin call halt mechanism

**Per-Minute De-dup** (Phase 6 dependency):
- [ ] One execution per strategy/symbol/TF per minute
- [ ] Deterministic tie-breakers for conflicts
- [ ] De-dup state persistence

**Timer-Scan Parity** (Phase 6):
- [ ] Centralize ScanStrategies() function
- [ ] Consistent OnTick/OnTimer execution paths
- [ ] Per-minute de-dup integration

**Policy Hot-Reload Guardrails**:
- [ ] Rollback to last-known-good on parse failure
- [ ] Plausibility checks before applying new policy
- [ ] Version validation

**PositionManager Integration**:
- [ ] Wire UsePositionManager flag
- [ ] Route sizing/exits through PM when enabled
- [ ] Test correlation dampening floors

### Red-Team Execution Plan (3×3 Cycles)

**Phase 1: Codebase & Requirements Deep Dive**
- Cycle 1: Structural Audit for LiveEA ✅ (COMPLETE)
- Cycle 2: Requirements Mapping (code paths, artifacts) 🔄
- Cycle 3: Risk & Gaps Closure, redesign fragile modules 📋

**Phase 2: Design, Build, Validate**
- Cycle 1: Task decomposition, acceptance criteria 📋
- Cycle 2: Implement fixes, peer review, adversarial tests 📋
- Cycle 3: QA + fuzzing (I/O, races), enforce CI gates 📋

**Phase 3: Polish, Lockdown, Final Scoring**
- Cycle 1: Docs & architecture alignment 📋
- Cycle 2: Code hygiene, refactors, dead-code purge 📋
- Cycle 3: Final scoring + roadmap to 100% maturity 📋

**Next**: Upon completing Phase 3 Cycle 3, begin Phase 2 Cycle 1 (ML/LSTM audit).

---

## Phase 4: Risk & Safety Systems

### Status: ✅ COMPLETE

### Implemented Features

**Circuit Breakers**:
- Daily loss percentage cap
- Drawdown from peak percentage cap
- Consecutive loss counter with cooldown
- Configurable cooldown periods

**News Filtering**:
- CSV-based news calendar support
- Buffer times (before/after event)
- Impact level filtering (Low/Med/High)
- Currency detection for symbol relevance

**Regime Detection**:
- ATR percentile-based volatility classification
- ADX trend strength measurement
- RSI momentum analysis
- Tradeable/non-tradeable regime gating

**Session Management**:
- Trading hours enforcement
- Max trades per session caps
- Daily counter resets

**Spread Validation**:
- Max spread in pips/points
- Real-time spread monitoring
- Spike detection (sudden widening)

**Margin Management**:
- Minimum margin level enforcement
- Stop-on-margin-call option
- Real-time margin monitoring

### TODOs

**Testing**:
- [ ] Run Strategy Tester to trigger each Phase 4 gate
- [ ] Confirm risk4_* telemetry events emit correctly
- [ ] Validate reason strings for all block scenarios

**Telemetry Standardization**:
- [x] risk4_spread events
- [x] risk4_margin events  
- [x] risk4_drawdown events
- [x] risk4_daily_loss events
- [x] risk4_consecutive events

### Best Practices

1. **Test circuit breakers regularly**: Simulate loss scenarios in Strategy Tester
2. **Update news calendar**: Keep CSV current with high-impact events
3. **Monitor regime transitions**: Log when market shifts between regimes
4. **Alert on breaker trips**: Set up notifications for production systems

---

## Phase 5: Dynamic Strategy Selection

### Status: 🔄 PARTIAL (Telemetry Complete, Pruning Planned)

### Implemented Features

**StrategySelector**:
- Performance-based scoring with weighted metrics
- Recency weighting with configurable decay
- Top-N strategy selection
- Per-symbol/timeframe strategy registration

**Cooldown & Auto-Tuning**:
- Underperformance auto-disable
- Automatic re-enable after cooldown
- Dynamic threshold auto-tuning

**Telemetry**:
- [x] p5_refresh: Selector refreshed
- [x] p5_rescore: Strategies rescored
- [x] p5_auto_tune: Thresholds adjusted
- [x] p5_selector_cfg: Configuration changes

### Remaining TODOs (Prioritized)

1. **Selector Wiring Parity** (Both EAs):
   - [ ] OnInit: thresholds, recency overlay, strict thresholds
   - [ ] Per-symbol/TF strategy registration
   - [ ] Logs/telemetry confirmation

2. **Correlation-Aware Pruning**:
   - [ ] Retain diversified subset per symbol/TF
   - [ ] Emit p5_corr telemetry
   - [ ] Cap per symbol/TF

3. **Multi-Timeframe Confirmations**:
   - [ ] Inputs: EnableMTFConfirmations, MTFConfirmTF, MTFConfirmMinScore
   - [ ] Telemetry: p5_mtf
   - [ ] Gate integration

4. **Parameter Stability Tracking**:
   - [ ] Compute stability score
   - [ ] Gate via P5_StabilityGateEnable
   - [ ] Telemetry: p5_stability

5. **Policy Integration for Selection**:
   - [ ] Use ML policy for subset selection/weighting
   - [ ] Beyond neutral scaling
   - [ ] Document and gate safely

6. **Feature/Telemetry Export Parity**:
   - [ ] After exec in both EAs: ATR, spread, TF, trailing params

7. **Telemetry Consistency**:
   - [ ] Standardize p5_* event keys across both EAs
   - [ ] Shadow logging under NoConstraintsMode (PaperEA parity)

8. **Test Plan**:
   - [ ] Backtests (walk-forward)
   - [ ] Forward/demo runs
   - [ ] Monitoring to validate selector behavior

---

## Phase 6: Low-Latency Minutely Scanner

### Status: 📋 PLANNED (OnTimer Present, Centralized Scan Needed)

### Goal

Guarantee both EAs "look" for trades at least every minute, independent of tick arrival.

### Planned Features

**Timer-Based Scanning**:
- Inputs: `TimerScanEnabled` (bool, default true), `TimerScanSeconds` (int, default 60)
- `OnInit()`: Configure `EventSetTimer(TimerScanSeconds)`
- `OnTimer()`: Run centralized `ScanStrategies()` routine

**De-duplication**:
- One execution per strategy/symbol/TF per minute
- Rolling `LastScanMinute` map for de-dup
- Avoid duplicate triggers if ticks also arrive

**Performance Hardening**:
- Pre-create indicator handles (avoid reallocation overhead)
- Cache policy/insights in memory
- Throttle file I/O to timer ticks
- Batch telemetry writes

**LiveEA Enrichment**:
- Optional `EventSetMillisecondTimer(250-1000ms)` for ultra-low-latency
- Gate by CPU budget
- Consume ML outputs for per-slice sizing

### TODOs

- [ ] Implement centralized `ScanStrategies()` function
- [ ] Per-minute de-dup map with cleanup
- [ ] Pre-warm indicator handles in `OnInit()`
- [ ] Test in Strategy Tester with low-tick scenarios
- [ ] Validate de-dup across OnTick/OnTimer paths
- [ ] Monitor scan→gate latency (<250ms SLO)

### Best Practices

1. **Guard OnTimer with re-entrancy flag**: Prevent overlapping scans
2. **Expose TimerScanSeconds overrides**: 30s for aggressive, 60s default
3. **Record scan→gate latency**: Emit to telemetry for SLO tracking
4. **Pre-warm indicator handles**: Refresh on symbol/period change
5. **Centralize gating**: Reusable `EvaluateAndMaybeExecute()` for both OnTick/OnTimer

---

## Phase 7: Monitoring & Telemetry

### Status: 🔄 PARTIAL (Basic Telemetry Done, Dashboard Planned)

### Implemented

- TelemetryStandard wrapper
- EventBus with priority levels
- SystemMonitor with health scoring
- CSV/JSON telemetry export

### Remaining TODOs

**SLOs & Metrics**:
- [ ] Define SLOs: scan→gate latency, missed-opportunity rate
- [ ] Per-reason gating counts
- [ ] Alerts for policy/insights read failures

**Dashboard** (Optional):
- [ ] HTML/JS lightweight dashboard
- [ ] Or Python/Jupyter notebook
- [ ] Per-slice counters and trend lines

**Log Rotation**:
- [ ] Daily/size-based rotation policy
- [ ] Retention policy (30 days)
- [ ] Compression of archived logs

**Alerting**:
- [ ] Policy staleness alerts
- [ ] Insights staleness alerts
- [ ] Circuit breaker trip notifications

---

## Phase 8: Adversarial/Jailbreak Hardening

### Status: 📋 PLANNED

### Goals

- Fuzz file I/O (empty/corrupt/locked files)
- Timing/race tests (low-tick, bar-boundary races)
- Resource pressure tests (large CSVs, slow disk)
- Produce Q&A logs, rebuttals, jailbreak traces

### TODOs

**Fuzzing**:
- [ ] Mutate policy.json/insights.json/CSVs
- [ ] Assert safe fallbacks, halts, or rollbacks
- [ ] No crashes or unsafe behavior

**Timing/Race Tests**:
- [ ] Low-tick periods simulation
- [ ] Bar-boundary race conditions
- [ ] Clock skew scenarios
- [ ] Verify de-dup and single-exec semantics

**Resource Pressure**:
- [ ] Very large CSV files (>500MB)
- [ ] Slow disk I/O simulation
- [ ] Ensure OnTick() remains non-blocking

**Jailbreak Artifacts**:
- [ ] Q&A logs (q&a.md)
- [ ] Expert rebuttals (rebuttals.jsonl)
- [ ] Jailbreak traces (traces.jsonl)
- [ ] Map to files/modules per @/greep protocol

**SafeMode**:
- [ ] Add SafeMode input parameter
- [ ] Force conservative gating on anomalies
- [ ] Use last-known-good caches

---

## Phase 9: MLOps & Continuous Training

### Status: 📋 PLANNED

### Goals

- Data versioning (DVC/Git LFS)
- Model registry with provenance
- Feature/label drift detection
- Scheduled retraining with automated deployment
- Canary deployment with rollback

### TODOs

**Data/Model Versioning**:
- [ ] DVC for features.csv versioning
- [ ] Model registry with metadata
- [ ] Feature schema catalog

**Drift Detection**:
- [ ] Feature distribution monitoring
- [ ] Label distribution monitoring
- [ ] Alert on threshold violations

**Automated Training**:
- [ ] Scheduled retraining pipeline
- [ ] Provenance tracking (model hash, data window, metrics)
- [ ] Reproducible environments (pinned dependencies)

**Deployment**:
- [ ] Acceptance criteria (min ROC-AUC, Brier, uplift vs baseline)
- [ ] Canary deployment to subset of slices
- [ ] Automatic rollback on degradation

**Data Catalog**:
- [ ] Schema versions for features.csv
- [ ] TTL/retention policies
- [ ] Data lineage tracking

---

## Phase 10: Multi-Symbol/TF Orchestration

### Status: 📋 PLANNED (Optional)

### Options

**Option A**: One EA per symbol/TF (simple, robust, recommended)

**Option B**: Single orchestrator scanning portfolio
- Central registry of symbols/TFs
- Per-slice de-dup and CPU budget
- Load shedding to maintain latency SLOs
- Portfolio-level risk budget enforcement

### TODOs (if Option B chosen)

**Orchestrator Implementation**:
- [ ] Per-slice schedule with backpressure
- [ ] Fairness: avoid starving symbols
- [ ] Throttle scanning under CPU load
- [ ] Prioritize LiveEA executions

**Broker API Guards**:
- [ ] Exponential backoff on transient errors
- [ ] Per-symbol error budgets
- [ ] Rate limiting

**Telemetry**:
- [ ] Consistent across all slices
- [ ] Portfolio-level metrics

---

## Phase 11: Performance & Resilience

### Status: 📋 PLANNED

### Goals

- Minimize file I/O in OnTick()
- Pre-allocate buffers, reuse handles
- Cap log verbosity on hot paths
- Watchdog for timer failures
- Safe-mode fallbacks on parse errors

### TODOs

**File I/O Optimization**:
- [ ] Avoid heavy I/O in OnTick()
- [ ] Defer to timer/batched writes
- [ ] Use FILE_SHARE_* flags
- [ ] Rotate logs (daily/size-based)

**Memory Management**:
- [ ] Pre-allocate buffers
- [ ] Reuse indicator handles
- [ ] Cap log verbosity on hot paths

**Watchdog**:
- [ ] Timer watchdog for missed deadlines
- [ ] Re-initialize timer if failures detected

**Re-entrancy Guards**:
- [ ] Critical sections (order placement, persistence writes)
- [ ] Ensure OnDeinit() flushes telemetry atomically

**Log Rotation**:
- [ ] Daily or size-based rotation
- [ ] Compress archives
- [ ] Retention policy (30 days default)

---

## Summary & Next Steps

### Completed Phases

✅ **Phase 1, 2, 2a, 4**: Fully operational
- Data/insights foundation solid
- ML pipeline functional
- PaperEA feature-complete
- Risk systems implemented

### Active Work

🔄 **Phase 3**: LiveEA hardening (3×3 red-team cycles in progress)
🔄 **Phase 5**: Dynamic strategy selection (core done, advanced features planned)
🔄 **Phase 7**: Monitoring (basic telemetry done, dashboard/alerts planned)

### Next Priorities

1. **Complete Phase 3 Cycle 2-3**: LiveEA requirements mapping, gap closure
2. **Phase 6 Implementation**: Centralized scanning, per-minute de-dup
3. **Phase 8 Planning**: Adversarial testing framework design
4. **Phase 9 Planning**: MLOps pipeline design

### Long-Term Vision

- Fully automated training/deployment pipeline (Phase 9)
- Adversarial-hardened system (Phase 8)
- Multi-symbol orchestration (Phase 10)
- Production-grade resilience (Phase 11)

---

**See Also:**
- [Configuration-Reference.md](Configuration-Reference.md) - All input parameters
- [Execution-Pipeline.md](Execution-Pipeline.md) - Detailed execution flow
- [Observability-Guide.md](Observability-Guide.md) - Telemetry and monitoring
- [Policy-Exploration-Guide.md](Policy-Exploration-Guide.md) - Policy/exploration details
- [Appendices.md](Appendices.md) - Red-team artifacts, schemas, CI hooks

