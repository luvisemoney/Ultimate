# Phase 3: LiveEA Core Loop & Documentation Lockdown

## Overview

Phase 3 focuses on completing the LiveEA core trading loop with policy gating, insights integration, risk management, and comprehensive documentation alignment. This phase bridges the gap between PaperEA (data collection) and LiveEA (production trading).

## Current Status

### ✅ Completed
- **LiveEA.mq5** (1832+ lines): Core trading loop with policy loading and gating
- **LiveEA_StrategyBridge.mqh**: Strategy bridge for 21+ IStrategy implementations
- **InsightsLoader.mqh**: DRY insights parsing from `insights.json`
- **PolicyEngine.mqh**: ML policy loading with confidence thresholds
- **Telemetry.mqh**: Real-time telemetry with standardized event schema
- **PositionManager.mqh**: Correlation-aware sizing and dynamic risk caps
- **IncrementalInsightEngine.mqh**: Real-time O(1) statistics engine

### 🔄 In Progress
- LiveEA hardening with stricter risk gates
- Timer-scan parity with PaperEA (Phase 6 alignment)
- Shadow mode for candidate decision logging

## Architecture

### LiveEA Execution Pipeline

```
OnTick() / OnTimer()
    ↓
ScanStrategies() → Per-strategy signal generation
    ↓
InsightGating() → Check performance metrics per slice
    ↓
PolicyGating() → ML confidence scoring with scaling
    ↓
RiskGating() → Spread, session, drawdown checks
    ↓
CorrelationCheck() → Portfolio exposure validation
    ↓
ExecuteOrder() → Trade placement with audit trail
    ↓
LogToKnowledgeBase() → Record for feedback loop
```

### Key Components

#### 1. Policy Integration (`PolicyEngine.mqh`)
- Loads `policy.json` from Common Files on init
- `ApplyPolicyScaling()`: SL/TP/trailing scaling per slice
- Fallback modes: `fallback_no_policy`, `fallback_policy_miss`
- Demo-only restriction configurable via `FallbackDemoOnly`

#### 2. Insights Gating (`InsightsLoader.mqh`)
- Real-time loading of `insights.json` performance metrics
- Per-slice validation: win rate, expectancy, drawdown
- Auto-reload with `InsightsAutoReload` polling mechanism
- Freshness tracking via file modification time

#### 3. Risk Management (`CPositionManager.mqh`)
- Correlation-aware position sizing
- Dynamic risk caps with daily drawdown limits
- Kelly Criterion position sizing (simplified)
- Volatility-based exit triggers

#### 4. Telemetry (`Telemetry.mqh` / `TelemetryStandard.mqh`)
- Event-driven logging with severity levels
- Per-slice gating counters and latency metrics
- Cross-EA compatibility with PaperEA
- Shadow logging under `NoConstraintsMode`

## Input Parameters

### Core Settings
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `MagicNumber` | long | 123456 | Trade identification |
| `NoConstraintsMode` | bool | false | Shadow-gate only, don't block |
| `Verbosity` | int | 1 | 0=errors, 1=warn, 2=info, 3=debug |

### Risk Management
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `SpreadMaxPoints` | double | 0.0 | 0=disabled |
| `MaxDailyLossPct` | double | 0.0 | Daily loss limit |
| `MaxDrawdownPct` | double | 0.0 | Max drawdown % |
| `ConsecutiveLossLimit` | int | 0 | Max consecutive losses |

### Insights Gating
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `UseInsightsGating` | bool | true | Enable insights validation |
| `GateMinTrades` | int | 0 | Min trades for slice validity |
| `GateMinWinRate` | double | 0.00 | Min win rate threshold |
| `GateMinExpectancyR` | double | -10.0 | Min expectancy in R |

### Policy Gating
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `UsePolicyGating` | bool | true | Enable ML policy gating |
| `DefaultPolicyFallback` | bool | true | Allow neutral trading on missing slice |
| `FallbackDemoOnly` | bool | true | Restrict fallback to demo accounts |
| `FallbackWhenNoPolicy` | bool | true | Allow fallback when no policy file |

### Exploration Mode
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ExploreOnNoSlice` | bool | true | Allow limited trades for new slices |
| `ExploreMaxPerSlice` | int | 100 | Max exploration trades per slice |
| `ExploreMaxPerSlicePerDay` | int | 100 | Daily exploration cap |

### PositionManager Integration
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `UsePositionManager` | bool | false | Enable PositionManager integration |
| `PM_EnableCorrelationSizing` | bool | true | Apply correlation dampening |
| `PM_CorrMinMult` | double | 0.5 | Min multiplier after dampening |
| `PM_CorrMinLots` | double | 0.01 | Absolute minimum lots floor |

## Feedback Loop

The LiveEA → PaperEA feedback loop enables continuous improvement:

1. **LiveEA** executes trades and logs to `knowledge_base.csv`
2. **ML Pipeline** merges PaperEA + LiveEA data for training
3. **Trainer** generates updated `policy.json` with new patterns
4. **PaperEA** validates policy changes in simulation
5. **Promotion Gate** advances validated strategies to LiveEA

```mermaid
LiveEA ──trades──→ knowledge_base.csv
                          ↓
PaperEA ──features──┴──→ ML Pipeline
                          ↓
                   policy.json (retrained)
                          ↓
         ┌────────────────┴────────────────┐
         ↓                                 ↓
    LiveEA (hot-reload)              PaperEA (validation)
```

## 3×3 Red-Team Execution Plan

### Phase 1: Codebase & Requirements Deep Dive
- **Cycle 1**: Structural Audit for LiveEA
  - Inventory gating paths: strategy → selector → insights → policy → execution
  - Trace file I/O: `CheckPolicyReload()`, `CheckInsightsReload()`, staleness checks
  - Identify insertion points: circuit breakers, session filters, PositionManager
  
- **Cycle 2**: Requirements Mapping
  - Spec one-pagers per feature with inputs, data flow, telemetry, failure/rollback
  
- **Cycle 3**: Risk & Gaps Closure
  - Threat model: file races, stale artifacts, partial reloads
  - Define LiveEA fail-safe defaults

### Phase 2: Design, Build, Validate
- **Cycle 1**: Task decomposition for LiveEA hardening
- **Cycle 2**: Implement fixes; peer review and adversarial edge-case tests
- **Cycle 3**: QA + fuzzing of IO/races; enforce CI gates

### Phase 3: Polish, Lockdown, Final Scoring
- **Cycle 1**: Docs & architecture alignment (README + this file)
- **Cycle 2**: Code hygiene & consistency; refactors; dead-code purge
- **Cycle 3**: Final scoring + roadmap to Phase 4 (Risk & Safety Systems)

## Telemetry Events

### Key Event Types
- `live_init`: EA initialization with policy/insights status
- `policy_loaded`: Policy file successfully loaded
- `policy_fallback_*`: Fallback mode activation
- `insight_gating`: Per-slice insights validation result
- `risk4_*`: Risk gate triggers (spread, session, drawdown)
- `p5_*`: Phase 5 selector events (cooldown, auto-disable, re-enable)
- `pm_corr_sizing`: PositionManager correlation sizing adjustment
- `order_executed`: Trade execution with full context
- `order_blocked`: Trade blocked with gating reason

### Event Schema
```json
{
  "timestamp": "2026-01-15T14:30:00Z",
  "event": "insight_gating",
  "symbol": "EURUSD",
  "timeframe": 60,
  "strategy": "ADXStrategy",
  "allowed": true,
  "metrics": {
    "trades": 150,
    "win_rate": 0.58,
    "expectancy_r": 0.35,
    "max_drawdown_r": 2.1
  }
}
```

## Next Steps

1. **Complete Phase 3 Cycle 3**: Final scoring and documentation alignment
2. **Begin Phase 4**: Risk & Safety Systems hardening
3. **Phase 6 Alignment**: Timer-scan parity with PaperEA
4. **CI Integration**: Wire `ValidateInsights.mq5` into automated testing

## Related Documentation
- [README.md](README.md) - Main system documentation
- [PolicySchema.md](PolicySchema.md) - Policy JSON format
- [KB-Schemas.md](KB-Schemas.md) - Knowledge Base CSV formats
- [Operations.md](Operations.md) - Operational runbook
- [MQL5_Migration_Notes.md](MQL5_Migration_Notes.md) - Migration guidance
