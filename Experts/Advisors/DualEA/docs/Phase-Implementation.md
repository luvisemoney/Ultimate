# Phase Implementation Guide — DualEA System

**Complete roadmap from Phase 1 through Phase 11**

---

## Implementation Status Summary

| Phase | Status | Completion |
|-------|--------|------------|
| Phase 1: Data & Insights Foundation | ✅ Complete | 100% |
| Phase 2: ML/LSTM Pipeline | ✅ Complete | 100% |
| Phase 2a: PaperEA Execution | ✅ Complete | 100% |
| Phase 3: LiveEA & Feedback | ✅ Complete | 95% (hardening in progress) |
| Phase 4: Risk & Safety | ✅ Complete | 100% |
| Phase 5: Dynamic Strategy Selection | 🔄 In Progress | 70% |
| Phase 6: Low-Latency Scanner | 🔄 Planned | 30% |
| Phase 7: Monitoring & Telemetry | 🔄 In Progress | 80% |
| Phase 8: Adversarial Hardening | 📋 Planned | 10% |
| Phase 9: MLOps & Continuous Training | 📋 Planned | 20% |
| Phase 10: Multi-Symbol Orchestration | 📋 Planned | 0% |
| Phase 11: Performance & Resilience | 📋 Planned | 40% |

---

## Phase 1: Data & Insights Foundation ✅

**Goal**: Establish robust data collection and insights generation.

### Implemented Features

**Knowledge Base (CKnowledgeBase)**:
- ✅ Trade logging to `knowledge_base.csv`
- ✅ Event logging to `knowledge_base_events.csv`
- ✅ File locking for concurrent access
- ✅ Automatic directory creation

**Features Export (CFeaturesKB)**:
- ✅ Long-format CSV export for ML training
- ✅ 50+ features per trade
- ✅ Automatic 100MB rotation with compression
- ✅ Schema versioning

**Insights Generation**:
- ✅ `InsightsRebuild.mq5` script for one-click rebuild
- ✅ Per-slice analytics (strategy|symbol|timeframe)
- ✅ Metrics: win rate, total trades, avg R-multiple, Sharpe ratio
- ✅ Staleness detection
- ✅ JSON output format

### Remaining TODOs

**CI Integration**:
- [ ] Add `kb_check.bat` for headless validation
- [ ] Wire `ValidateInsights.mq5` into CI pipeline
- [ ] Fail CI on stale insights or missing required coverage

**Headless Operations**:
- [ ] PowerShell wrapper for non-interactive `InsightsRebuild`
- [ ] Scheduled task integration

**Schema Management**:
- [ ] Version `insights.json` format
- [ ] Add compatibility checks in `StrategySelector`
- [ ] Document schema in `KB-Schemas.md`

**Validator Enhancements**:
- [ ] Expand `ValidateInsights` to check required metrics
- [ ] Configurable thresholds per slice
- [ ] Concise validation report output

---

## Phase 2: ML/LSTM Pipeline ✅

**Goal**: Train ML models and export trading policies.

### Implemented Features

**Training Pipeline (`ML/train.py`)**:
- ✅ TensorFlow/Keras classifier + LSTM
- ✅ TimeSeriesSplit validation (5 splits)
- ✅ Yahoo Finance enrichment for market context
- ✅ 50+ technical indicators and features
- ✅ ROC-AUC, Brier score, Expected-R metrics

**Policy Export (`ML/policy_export.py`)**:
- ✅ Converts trained models to `policy.json`
- ✅ Per-slice probability estimates
- ✅ SL/TP/lot/trail scaling multipliers
- ✅ Provenance metadata (model hash, train window, metrics)

**Feature Engineering (`ML/features.py`)**:
- ✅ Automatic scaling and normalization
- ✅ Label generation from R-multiples
- ✅ Market regime features

**Model Artifacts**:
- ✅ Saved models (.keras format)
- ✅ Feature scalers (.pkl)
- ✅ Feature metadata (.json)
- ✅ Automatic rotation and compression

### Remaining TODOs

**CI Trainer Job**:
- [ ] Scheduled training on data updates
- [ ] Publish `policy.json` to Common Files
- [ ] Touch `policy.reload` trigger file

**Provenance & Signing**:
- [ ] Model hash validation
- [ ] Digital signing for integrity
- [ ] Last-known-good policy backup

**Shadow Evaluation & A/B**:
- [ ] Dual policy support in PaperEA
- [ ] A/B testing framework
- [ ] Shadow mode before LiveEA promotion

**Calibration**:
- [ ] Reliability diagrams
- [ ] Per-slice confidence calibration
- [ ] Acceptance bands documentation

**Monitoring**:
- [ ] SHAP/feature importance tracking
- [ ] Drift detection and alerts
- [ ] Auto-rollback on plausibility failure

---

## Phase 2a: PaperEA Execution & Telemetry ✅

**Goal**: Production-ready paper trading with comprehensive telemetry.

### Implemented Features

**Core Trading Engine**:
- ✅ `CPaperPosition` class for paper trading
- ✅ Real-time PnL calculation
- ✅ SL/TP hit detection
- ✅ Position lifecycle tracking

**Strategy System**:
- ✅ 21 strategies with `IStrategy` interface
- ✅ `AssetRegistry` for symbol classification
- ✅ `StrategySelector` with performance-based scoring

**Gating System**:
- ✅ 8-stage gate processing
- ✅ `ConfigManager` for centralized configuration
- ✅ `EventBus` for cross-component communication
- ✅ `SystemMonitor` for health tracking
- ✅ Learning-based threshold adjustment

**Advanced Optimization**:
- ✅ `AdaptiveSignalOptimizer` (ML-enabled)
- ✅ `PolicyUpdater` (auto-generates policy every 60 min)
- ✅ `PositionReviewer` (reviews positions every 5 min)
- ✅ `GateLearningSystem` (hybrid learning 5% rate)

**Data Export**:
- ✅ `UnifiedTradeLogger` with daily JSON logs
- ✅ Features export with 100MB rotation
- ✅ Knowledge Base with file locking
- ✅ Telemetry with standardized format

**Controls**:
- ✅ `NoConstraintsMode` for unrestricted data collection
- ✅ Exploration mode with daily/weekly caps
- ✅ Policy hot-reload (timer-based, every 60 min)
- ✅ Policy fallback modes (no_policy, slice_miss)

### Remaining TODOs

**CI Wiring**:
- [ ] Integrate `ValidateInsights` into CI
- [ ] Headless rebuild/validation scripts

**Ops Documentation**:
- [ ] Operator runbook for rebuild/validate flows
- [ ] Artifact location reference

**Telemetry Polish**:
- [ ] Concise summaries for rebuild/validation outcomes
- [ ] Standardize event keys across PaperEA/LiveEA

---

## Phase 3: LiveEA & Feedback Loop ✅

**Goal**: Real trading with stricter gating and risk management.

### Implemented Features (95%)

**Core LiveEA**:
- ✅ Insights gating with stricter thresholds
- ✅ Policy gating with ML confidence
- ✅ Risk gating (spread, session, daily loss, drawdown, margin)
- ✅ News blackout filtering
- ✅ Exploration mode (limited caps)

**Position Manager Integration**:
- ✅ Correlation-adjusted sizing
- ✅ Adaptive sizing based on performance
- ✅ Dynamic risk caps
- ✅ Volatility-based exits

**Risk Controls**:
- ✅ Circuit breakers (daily loss, drawdown, consecutive losses)
- ✅ Margin level monitoring
- ✅ Spread spike rejection
- ✅ Session-based trade limits

**Policy System**:
- ✅ Policy loading from `policy.json`
- ✅ SL/TP/lot/trail scaling
- ✅ Fallback modes with demo-only restriction
- ✅ Timer-based hot-reload

### Remaining TODOs (5%)

**Shadow Mode**:
- [ ] Log decisions without executing
- [ ] Execute only top ML-ranked signals

**One-Execution-Per-Minute De-dup** (Phase 6):
- [ ] Per-slice-per-minute tracking
- [ ] Deterministic tie-breakers

**Policy Guardrails**:
- [ ] Rollback to last-known-good on parse failure
- [ ] Plausibility checks (multipliers in sane ranges)

**Full Timer Parity** (Phase 6):
- [ ] Centralized `ScanStrategies()` function
- [ ] Consistent OnTick/Timer paths

---

## Phase 4: Risk & Safety Systems ✅

**Goal**: Comprehensive risk management and safety controls.

### Implemented Features (100%)

**Circuit Breakers**:
- ✅ Daily loss percentage cap
- ✅ Drawdown from peak cap
- ✅ Consecutive loss counter
- ✅ Cooldown periods after breaker trips

**News Filtering**:
- ✅ CSV-based news calendar
- ✅ Buffer windows (before/after)
- ✅ Impact level filtering (low/med/high)
- ✅ Auto-detect symbol currency

**Regime Detection**:
- ✅ ATR percentile classification
- ✅ ADX trend strength
- ✅ RSI momentum
- ✅ Configurable min/max thresholds

**Session Management**:
- ✅ Trading hours enforcement
- ✅ Max trades per session
- ✅ Daily counter reset

**Correlation Management**:
- ✅ Pearson correlation calculation
- ✅ Portfolio correlation tracking
- ✅ Max correlation gating

**Spread & Margin**:
- ✅ Real-time spread monitoring
- ✅ Spread spike detection
- ✅ Margin level checks
- ✅ Auto-stop on margin call

### Telemetry

All risk gates emit `risk4_*` events:
- `risk4_spread`, `risk4_margin`, `risk4_drawdown`
- `risk4_daily_loss`, `risk4_consecutive`, `risk4_session`

---

## Phase 5: Dynamic Strategy Selection 🔄

**Goal**: Intelligent strategy selection based on performance.

### Implemented Features (70%)

**StrategySelector (PaperEA & LiveEA)**:
- ✅ Performance-based scoring
- ✅ Recency weighting
- ✅ Insights integration
- ✅ Top-N selection

**Auto-Tuning (LiveEA)**:
- ✅ Cooldown + auto re-enable
- ✅ Dynamic threshold adjustment
- ✅ Telemetry (`p5_auto_tune`, `p5_auto_reenabled`)

**Telemetry**:
- ✅ `p5_refresh`, `p5_rescore`, `p5_selector_cfg`

### Remaining TODOs (30%)

**Correlation-Aware Pruning**:
- [ ] Retain diversified subset per symbol/TF
- [ ] Emit `p5_corr` telemetry
- [ ] Cap per symbol/TF

**Multi-Timeframe Confirmations**:
- [ ] Input parameters: `EnableMTFConfirmations`, `MTFConfirmTF`, `MTFConfirmMinScore`
- [ ] Gate logic for MTF validation
- [ ] Telemetry: `p5_mtf`

**Parameter Stability Tracking**:
- [ ] Compute stability score (std of params over time)
- [ ] Gate via `P5_StabilityGateEnable`, `P5_StabilityMaxStdR`
- [ ] Telemetry: `p5_stability`

**Policy Integration**:
- [ ] ML-driven strategy subset selection
- [ ] Weighting from policy (beyond neutral scaling)

**Test Plan**:
- [ ] Walk-forward backtests
- [ ] Forward/demo validation
- [ ] Monitoring dashboards

---

## Phase 6: Low-Latency Minutely Scanner 🔄

**Goal**: Guarantee trade opportunity checking every minute, independent of ticks.

### Current Status (30%)

**Implemented**:
- ✅ OnTimer heartbeat (60s default)
- ✅ Policy/insights reload on timer
- ✅ Telemetry flush on timer

**Planned**:
- [ ] Centralized `ScanStrategies()` function
- [ ] Per-minute de-duplication (`LastScanMinute` map)
- [ ] Consistent OnTick/Timer paths
- [ ] Input: `TimerScanEnabled`, `TimerScanSeconds`

### Implementation Plan

**Inputs**:
```cpp
input bool     TimerScanEnabled = true;      // Enable timer-based scanning
input int      TimerScanSeconds = 60;        // Scan interval (seconds)
```

**OnInit**:
```cpp
if(TimerScanEnabled) {
    EventSetTimer(TimerScanSeconds);
}
```

**OnTimer**:
```cpp
void OnTimer() {
    // Existing: policy/insights reload, telemetry flush
    CheckPolicyReload();
    Telemetry.Flush();
    
    // New: centralized scanning
    if(TimerScanEnabled) {
        ScanStrategies();  // Same logic as OnTick
    }
}
```

**De-duplication**:
```cpp
// Per-slice-per-minute tracking
map<string, datetime> lastScanMinute;

bool ShouldScan(string sliceKey) {
    datetime now = TimeCurrent();
    datetime nowMinute = now - (now % 60);  // Round to minute
    
    if(lastScanMinute.Contains(sliceKey)) {
        if(lastScanMinute[sliceKey] == nowMinute) {
            return false;  // Already scanned this minute
        }
    }
    
    lastScanMinute[sliceKey] = nowMinute;
    return true;
}
```

### Performance Optimizations

**Pre-create Indicator Handles**:
- Allocate all handles in `OnInit()`
- Reuse across scans
- Refresh on symbol/period change

**Cache Policy/Insights**:
- In-memory cache
- Throttle file I/O to timer ticks only

**Optional Sub-Second Scanning** (LiveEA only):
```cpp
input bool     UseMillisecondTimer = false;  // Ultra-low latency
input int      MillisecondTimerMs = 250;     // 250ms-1000ms

if(UseMillisecondTimer) {
    EventSetMillisecondTimer(MillisecondTimerMs);
}
```

**Latency Targets**:
- Scan → gate → exec: <250ms (where broker allows)
- Record latency metrics in telemetry

---

## Phase 7: Monitoring & Telemetry 🔄

**Goal**: Comprehensive observability and performance tracking.

### Implemented Features (80%)

**Telemetry System**:
- ✅ `TelemetryStandard` wrapper
- ✅ CSV export to Common Files
- ✅ JSON
