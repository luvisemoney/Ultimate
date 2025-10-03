# DualEA — Production Multi-Strategy Trading System

**Paper EA + Live EA with ML Policy Engine**

---

## System Overview

**DualEA** is a production-ready Expert Advisor ecosystem for MetaTrader 5:

- **PaperEA_v2** (2793 lines): Paper trading with 8-stage gates, 21 strategies, ML integration
- **LiveEA** (1702 lines): Real trading with insights/policy gating and advanced risk management  
- **ML Pipeline**: TensorFlow/Keras training with policy export
- **Knowledge Base**: Shared CSV/JSON data in Common Files

---

## Quick Start

```bash
# 1. Run PaperEA for data collection
# Load PaperEA/PaperEA_v2.mq5 on charts (EURUSD H1, GBPUSD H1, etc.)
# Set NoConstraintsMode=true for maximum data collection

# 2. Generate insights from collected data
# Run Scripts/InsightsRebuild.mq5 to create insights.json

# 3. Train ML model and export policy
cd ML
run_train_and_export.bat

# 4. Deploy LiveEA with policy
# Load LiveEA/LiveEA.mq5 on charts
# Set UsePolicyGating=true and UseInsightsGating=true
```

---

## Implementation Status

### ✅ Production Ready

**PaperEA_v2**
- 8-stage unified gate system (ConfigManager, EventBus, SystemMonitor)
- 21 strategies with asset-class registry  
- Paper positions with real-time PnL tracking
- Advanced optimizers: AdaptiveSignalOptimizer, PolicyUpdater, PositionReviewer, GateLearningSystem
- Knowledge Base with 100MB rotation, UnifiedTradeLogger with daily JSON logs
- 180+ input parameters for fine-tuning

**LiveEA**
- Insights gating (win rate, trades, R-multiple thresholds)
- ML policy gating (confidence, SL/TP/trail scaling)
- Risk management (spread, session, daily loss, drawdown, margin, consecutive losses)
- News filtering, exploration mode, position/session/correlation/volatility managers

**ML Pipeline**
- TensorFlow/Keras training with TimeSeriesSplit validation
- Policy export with slice-based probabilities
- Yahoo Finance enrichment, 50+ features
- Automatic rotation and compression

**Supporting Systems**
- InsightsRebuild: One-click insights.json generation
- Test suite: 8 integration/unit tests
- Build scripts and CI hooks

### 🔄 Partial / Planned

- Policy hot-reload via .reload triggers
- LSTM sequence validation
- Multi-timeframe confirmation gate (P5_MTFConfirmEnable)
- Timer-based minutely scanning (Phase 6)
- Advanced correlation pruning algorithms

---

## Architecture

### 21 Active Strategies

**Trend (5):** ADX, SuperTrendADXKama, DonchianATRBreakout, ForexTrend, Alligator  
**Mean Reversion (4):** BollAverages, MeanReversionBB, RSI2BBReversion, VWAPReversion  
**Momentum (6):** AwesomeOscillator, AcceleratorOscillator, BearsPower, BullsPower, KeltnerMomentum, Aroon  
**Multi-Asset (3):** GoldVolatility, IndicesEnergies, OpeningRangeBreakout  
**Advanced (3):** MultiIndicator, EMAPullback, Stub  

Strategies auto-selected via asset-class registry (FX Major/Minor, Crypto, Metal, Energy, Index).

### 8-Stage Gate System

1. **Signal Rinse**: Basic validation, confidence filtering
2. **Market Soap**: Volatility, correlation, regime analysis
3. **Strategy Scrub**: Strategy-specific validation
4. **Risk Wash**: Position sizing, risk validation
5. **Performance Wax**: Backtest performance checks
6. **ML Polish**: ML confidence scoring
7. **Live Clean**: Live market conditions
8. **Final Verify**: Pre-execution validation

Each gate: individually configurable, learning-based auto-tuning, shadow logging support.

### Data Flow

```
PaperEA → features.csv, knowledge_base.csv
         ↓
      InsightsRebuild.mq5
         ↓
      insights.json
         
features.csv → ML/train.py → policy.json

policy.json + insights.json → LiveEA → Real Trades → knowledge_base.csv
```

### Common Files Structure

```
Common/Files/DualEA/
├── features.csv               # ML training data (100MB rotation)
├── knowledge_base.csv         # Trade records
├── knowledge_base_events.csv  # Trade events
├── insights.json              # Performance per strategy/symbol/TF
├── policy.json                # ML policy with confidence thresholds
├── policy.backup.json         # Rollback cache
├── explore_counts.csv         # Weekly exploration tracking
├── explore_counts_day.csv     # Daily exploration tracking
└── logs/trades_YYYYMMDD.json  # Daily trade logs
```

---

## Configuration

**📘 For complete parameter reference, see [Configuration-Reference.md](Configuration-Reference.md)**

### Key PaperEA Parameters

**Trading**: `LotSize`, `MagicNumber`, `StopLossPips`, `TakeProfitPips`, `MaxOpenPositions`, `TrailEnabled`  
**Gating**: `UseInsightsGating`, `UseExploration`, `UsePolicyGating`, `NoConstraintsMode`  
**Exploration**: `ExploreMaxPerSlicePerDay` (default 2), `ExploreMaxPerSlice` (default 3)  
**Policy Fallback**: `DefaultPolicyFallback`, `FallbackDemoOnly`, `FallbackWhenNoPolicy`  
**Risk**: Circuit breakers, news filters, regime gates, session limits  

**NoConstraintsMode=true** (default): Bypasses ALL gates for maximum data collection.

### Key LiveEA Parameters

Inherits PaperEA params plus:

**Insights Thresholds**: Min win rate, total trades, avg R-multiple  
**Policy Thresholds**: Min confidence, scaling multipliers  
**Risk Limits**: Max spread, daily loss %, drawdown %, margin level, consecutive losses  
**PositionManager**: `UsePositionManager`, `PM_EnableCorrelationSizing`, `PM_ScalingProfile`

---

## Execution Pipeline

**📘 For detailed pipeline documentation, see [Execution-Pipeline.md](Execution-Pipeline.md)**

1. **Signal Generation** (OnTick/OnTimer) → Strategy.CheckSignal()
2. **Early Validation** → Trading hours, news, spread, margin
3. **8-Stage Gates** → Progressive filtering with learning
4. **Strategy Selection** → Performance scoring, insights gating
5. **Policy Application** → ML confidence, SL/TP scaling, fallbacks
6. **Risk Management** → Position sizing, correlation, circuit breakers
7. **Trade Execution** → TradeManager, SL/TP normalization, trailing
8. **Post-Execution** → KB logging, features export, telemetry, learning updates

---

## Exploration Mode

**📘 For complete policy and exploration guide, see [Policy-Exploration-Guide.md](Policy-Exploration-Guide.md)**

**Purpose**: Bootstrap insights for new strategy/symbol/TF slices.

**Rules**:
- Bypass ONLY when NO slice exists (no-slice-only)
- If slice exists but fails thresholds → BLOCKED
- Daily cap: `ExploreMaxPerSlicePerDay` (default 2)
- Weekly cap: `ExploreMaxPerSlice` (default 3)
- Counters persist in `explore_counts*.csv`

**NoConstraintsMode**: Bypasses insights gating AND exploration caps entirely.

**Logs**:
```
GATE: explore allow ADXStrategy on EURUSD/H1 (day=1/2, week=2/3)
GATE: blocked ADXStrategy reason=explore_cap_day (day=2/2)
```

**Reset**: Delete `explore_counts.csv` and `explore_counts_day.csv`.

---

## Policy Fallback

**When**: `UsePolicyGating=true` but policy missing or incomplete.

**Fallback Modes**:

1. **No Policy** (`fallback_no_policy`): policy.json not loaded (slices=0)
2. **Policy Miss** (`fallback_policy_miss`): policy loaded but slice missing

**Behavior**:
- Demo-only by default (`FallbackDemoOnly=true`)
- Neutral scaling (no SL/TP/trail multipliers)
- Bypasses insights/exploration caps
- Safe for data collection

**Logs**:
```
FALLBACK: no policy loaded -> neutral scaling for ADXStrategy on EURUSD/H1 demo=true
FALLBACK: policy slice missing -> neutral scaling for BollAverages on GBPUSD/H1 demo=true
```

**Production**: Set `FallbackDemoOnly=false` carefully or disable fallbacks entirely.

---

## ML Pipeline

### Training

```bash
cd ML
python train.py --input ../../../Common/Files/DualEA/features.csv --output artifacts/
```

- TimeSeriesSplit validation (5 splits)
- LSTM + Dense classifier
- Yahoo Finance enrichment
- ROC-AUC, Brier, Expected-R metrics

### Policy Export

```bash
python policy_export.py --model artifacts/tf_model.keras --scaler artifacts/scaler.pkl --output policy.json
```

- Per-slice probability estimates
- Confidence thresholds
- SL/TP/trail scaling multipliers
- Provenance metadata (model hash, train window, metrics)

### Deployment

Copy `policy.json` to `Common/Files/DualEA/policy.json` and restart LiveEA (or touch `policy.reload` for hot-reload when implemented).

/block with reason and latency
- `trade_execution`: Trade placements
- `policy_load`: Policy reload events
- `insights_rebuild`: Insights regeneration
- `threshold_adjust`: Learning-based adjustments
- `risk4_*`: Risk gate events (spread, margin, drawdown)
- `pm_*`: PositionManager events (correlation sizing)
- `p5_*`: Selector events (refresh, rescore, tune)

### SystemMonitor

- Gate success rates per stage
- Processing latency (gate, total pipeline)
- System health score (0-100)
- Memory and handle tracking

### Telemetry Export

CSV/JSON format:
```csv
timestamp,event_type,symbol,timeframe,strategy,gate,result,reason,latency_ms,metadata
```

---

## Testing

### Test Suite

Run from `Tests/`:
- `Test_Integration.mq5`: End-to-end pipeline
- `Test_GateManager.mq5`: Gate logic validation
- `Test_UnifiedSystem.mq5`: ConfigManager/EventBus/SystemMonitor
- `Test_PositionManager.mq5`: Position management
- `Test_SessionManager.mq5`: Session controls
- `Test_CorrelationManager.mq5`: Correlation logic
- `Test_VolatilitySizer.mq5`: Volatility sizing
- `Test_SystemHealth.mq5`: Health monitoring

### Validation

```bash
# Validate insights.json
run Scripts/ValidateInsights.mq5

# Rebuild insights
run Scripts/InsightsRebuild.mq5
```

---

## Documentation

- **README.md**: This file
- **UnifiedSystemGuide.md**: ConfigManager/EventBus/SystemMonitor integration
- **KB-Schemas.md**: CSV/JSON schemas
- **PolicySchema.md**: policy.json structure
- **Phase3.md**: LiveEA implementation plan
- **Operations.md**: Ops runbook
- **DualEA_Handbook.md**: Comprehensive guide

---

## Development Roadmap

See detailed phase documentation in original README.md:

- **Phase 1**: Data & Insights Foundation ✅
- **Phase 2**: ML/LSTM Pipeline ✅  
- **Phase 2a**: PaperEA Execution & Telemetry ✅
- **Phase 3**: LiveEA & Feedback Loop ✅ (hardening in progress)
- **Phase 4**: Risk & Safety Systems ✅
- **Phase 5**: Dynamic Strategy Selection 🔄
- **Phase 6**: Low-Latency Scanner 🔄
- **Phase 7**: Monitoring & Telemetry 🔄
- **Phase 8**: Adversarial Hardening 📋
- **Phase 9**: MLOps & Continuous Training 📋
- **Phase 10**: Multi-Symbol Orchestration 📋
- **Phase 11**: Performance & Resilience 📋

---

## License

Copyright 2025, Windsurf Engineering.

---

## Support

For detailed implementation guidance, see the full README.md and documentation in `docs/`.
