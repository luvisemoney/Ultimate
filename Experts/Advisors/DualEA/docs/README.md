# DualEA (Paper + Live) — Modular Multi‑Strategy EA with Knowledge Base and Roadmap

## Overview
DualEA is a modular Expert Advisor system for MetaTrader 5 designed to:
- Run a Paper EA to test strategies and indicators, logging all activity to a shared Knowledge Base.
- Evolve into a Live EA that reads insights and ML policy from the Knowledge Base to gate and size real trades.
- Support advanced trade management (pending orders, SL/TP, trailing) and per‑strategy modularity.

This repo currently focuses on the Paper EA with a production‑ready architecture for logging and advanced trade management. A multi‑phase roadmap below describes the path to Live EA, ML/LSTM policy learning, and institutional safety.

### Architecture (Mermaid)

**Legend:**
- <span style="color:#4CAF50;font-weight:bold">Green</span>: Implemented & Working
- <span style="color:#FFC107;font-weight:bold">Yellow</span>: Implemented but Needs Integration/Testing
- <span style="color:#F44336;font-weight:bold">Red</span>: Planned/Not Implemented

```mermaid
flowchart TD
  %% Color classes
  classDef implemented fill:#4CAF50,color:#fff,stroke:#333,stroke-width:2px
  classDef inprogress fill:#FFC107,color:#222,stroke:#333,stroke-width:2px
  classDef planned fill:#F44336,color:#fff,stroke:#333,stroke-width:2px

  %% Paper EA System (v2 - Enhanced)
  subgraph Paper[PaperEA v2 System]
    PEA[PaperEA_v2.mq5]:::implemented
    GM[GateManager - 8 Gates]:::implemented
    LB[LearningBridge]:::implemented
    TM[TradeManager]:::implemented
    TEL[Telemetry]:::implemented
  end

  %% Strategy System
  subgraph Strategies[Strategy System]
    REG[Strategy Registry]:::implemented
    STR[23 Strategy Files]:::implemented
    SEL[StrategySelector]:::implemented
  end

  %% Knowledge Base & Data Files
  subgraph KB[Knowledge Base - Common Files]
    FEAT[features.csv]:::implemented
    TRD[knowledge_base.csv]:::implemented
    INS[insights.json]:::implemented
    POL[policy.json]:::implemented
    IRL[insights.reload]:::planned
    PRL[policy.reload]:::planned
  end

  %% ML Training System
  subgraph ML[ML Training System]
    TRN[train.py]:::implemented
    PEXP[policy_export.py]:::implemented
    DSET[dataset.py]:::implemented
    FEAT_PY[features.py]:::implemented
    MODEL[model.py]:::implemented
    ARTIFACTS[artifacts/]:::implemented
  end

  %% Live EA System
  subgraph Live[LiveEA System]
    LEA[LiveEA.mq5]:::inprogress
    PM[PositionManager]:::inprogress
    SM[SessionManager]:::inprogress
    CM[CorrelationManager]:::inprogress
    VS[VolatilitySizer]:::inprogress
    IL[InsightsLoader]:::implemented
  end

  %% Scripts & Tools
  subgraph Scripts[Scripts & Tools]
    IBD[InsightsRebuild.mq5]:::implemented
    POL_DUMP[PolicyDump.mq5]:::implemented
    BUILD[Build Scripts]:::implemented
  end

  %% Data Flow - Paper EA
  PEA --> GM
  PEA --> LB
  PEA --> TM
  PEA --> TEL
  GM --> LB
  
  %% Strategy Integration
  PEA --> SEL
  SEL --> STR
  STR --> REG

  %% Data Export from Paper EA
  PEA -->|trade data| TRD
  STR -->|features| FEAT
  TEL -->|telemetry| FEAT

  %% ML Training Pipeline
  FEAT --> TRN
  TRD --> TRN
  TRN --> ARTIFACTS
  TRN --> PEXP
  PEXP --> POL

  %% Insights Generation
  FEAT --> IBD
  TRD --> IBD
  IBD --> INS

  %% Live EA Consumption
  INS --> LEA
  POL --> LEA
  LEA --> PM
  LEA --> SM
  LEA --> CM
  LEA --> VS
  IL --> LEA

  %% Live EA Data Export (when active)
  LEA -.->|trade data| TRD
  LEA -.->|features| FEAT
```

**Key Implementation Notes:**
- **PaperEA v2**: Fully implemented with 8-stage gate system, learning bridge, and telemetry
- **LiveEA**: Core structure implemented but needs integration testing and policy consumption
- **ML Pipeline**: Complete training and policy export system with TensorFlow/Keras models
- **Knowledge Base**: File-based system using Common Files for cross-EA data sharing
- **Strategies**: 23 implemented strategies with registry system

## Project Structure
```
MQL5/
├── Experts/
│   └── Advisors/
│       └── DualEA/
│           ├── PaperEA/                # Paper Trading System
│           │   ├── PaperEA_v2.mq5     # Enhanced Paper EA with 8-stage gates
│           │   └── PaperEA_backtest.ini
│           ├── LiveEA/                 # Live Trading System  
│           │   ├── LiveEA.mq5         # Live EA with advanced gating
│           │   ├── LiveEA_StrategyBridge.mqh
│           │   ├── Telemetry.mqh
│           │   └── build_liveea.bat
│           ├── Include/                # Core System Components
│           │   ├── IStrategy.mqh           # Strategy interface
│           │   ├── StrategySelector.mqh    # Strategy selection & scoring
│           │   ├── TradeManager.mqh        # Trade execution management
│           │   ├── PositionManager.mqh     # Position management
│           │   ├── KnowledgeBase.mqh       # Data persistence layer
│           │   ├── GateManager.mqh         # 8-stage gate system
│           │   ├── LearningBridge.mqh      # Learning data bridge
│           │   ├── Telemetry.mqh           # Telemetry system
│           │   ├── TelemetryStandard.mqh   # Standard telemetry
│           │   ├── InsightsLoader.mqh      # Insights JSON loader
│           │   ├── SessionManager.mqh      # Session management
│           │   ├── CorrelationManager.mqh  # Correlation analysis
│           │   ├── VolatilitySizer.mqh     # Volatility-based sizing
│           │   ├── Strategies/             # Strategy Implementations
│           │   │   ├── Registry.mqh        # Strategy registry
│           │   │   ├── ADXStrategy.mqh
│           │   │   ├── BollAveragesStrategy.mqh
│           │   │   ├── MeanReversionBBStrategy.mqh
│           │   │   ├── SuperTrendADXKamaStrategy.mqh
│           │   │   ├── RSI2BBReversionStrategy.mqh
│           │   │   ├── DonchianATRBreakoutStrategy.mqh
│           │   │   └── ... (17 more strategies)
│           │   └── Indicators/             # Technical Indicators
│           │       ├── ATR.mqh
│           │       ├── Donchian.mqh
│           │       ├── KAMA.mqh
│           │       └── ... (7 more indicators)
│           ├── ML/                      # Machine Learning Pipeline
│           │   ├── train.py            # Model training script
│           │   ├── policy_export.py    # Policy generation
│           │   ├── dataset.py          # Data loading utilities
│           │   ├── features.py         # Feature engineering
│           │   ├── model.py            # Model definitions
│           │   ├── policy.py           # Policy utilities
│           │   ├── artifacts/          # Model artifacts
│           │   │   ├── tf_model.keras  # Trained model
│           │   │   ├── scaler.pkl      # Feature scaler
│           │   │   └── features.json   # Feature definitions
│           │   └── requirements.txt    # Python dependencies
│           ├── Scripts/                # Utility Scripts
│           │   ├── InsightsRebuild.mq5 # Rebuild insights from data
│           │   └── PolicyDump.mq5      # Policy debugging
│           ├── docs/                   # Documentation
│           │   ├── README.md           # This file
│           │   ├── CORE_IMPLEMENTATION_PLAN.md
│           │   ├── DualEA_Handbook.md
│           │   └── ... (11 more docs)
│           ├── config/                 # Configuration
│           │   └── learning_config.json
│           ├── logs/                   # Log files
│           ├── results/                # Test results
│           └── build_*.bat             # Build scripts
```

### Common Files Structure (Shared Data)
```
Terminal/Common/Files/DualEA/
├── features.csv           # Feature data from strategies (with rotation)
├── knowledge_base.csv     # Trade execution records
├── insights.json          # Performance analytics per strategy/symbol/timeframe
├── policy.json           # ML-generated trading policy with confidence thresholds
├── insights.reload       # Trigger file for insights rebuild (planned)
└── policy.reload         # Trigger file for policy reload (planned)
```

## Current Implementation Status

### ✅ Fully Implemented & Working
- **PaperEA v2**: Complete paper trading system with 8-stage gate processing
- **GateManager**: 8 gates (Signal Rinse, Market Soap, Strategy Scrub, Risk Wash, Performance Wax, ML Polish, Live Clean, Final Verify)
- **Strategy System**: 23 trading strategies with modular architecture
- **Knowledge Base**: File-based persistence with CSV rotation and robust I/O
- **ML Training Pipeline**: Complete TensorFlow/Keras training with feature engineering
- **Policy Export**: ML model to policy.json conversion with scaling parameters
- **Insights System**: Performance analytics generation from trade data
- **Build System**: Automated compilation and deployment scripts

### 🔄 Implemented but Needs Integration/Testing  
- **LiveEA Core**: Main structure with advanced gating system implemented
- **Position Management**: Core functionality implemented, needs LiveEA integration
- **Session Management**: Trading session controls implemented
- **Correlation Management**: Portfolio correlation analysis implemented
- **Volatility Sizing**: ATR-based position sizing implemented
- **Telemetry System**: Data collection framework, needs standardization

### 🔴 Planned/Not Implemented
- **Live Policy Consumption**: LiveEA reading and applying ML policies
- **Real-time Insights Reload**: Automatic insights refresh triggers
- **Policy Reload Triggers**: Dynamic policy updates without EA restart
- **Advanced Risk Management**: Drawdown controls and circuit breakers
- **Multi-timeframe Coordination**: Cross-timeframe strategy coordination

## Key Features

### 8-Stage Gate System (PaperEA v2)
1. **Signal Rinse**: Basic signal validation and confidence filtering
2. **Market Soap**: Market context analysis (volatility, correlation, regime)
3. **Strategy Scrub**: Strategy-specific validation and parameter adjustment
4. **Risk Wash**: Risk-based position sizing and validation
5. **Performance Wax**: Backtest-based performance validation
6. **ML Polish**: Machine learning confidence scoring
7. **Live Clean**: Live market condition validation
8. **Final Verify**: Final trade validation before execution

### Machine Learning Pipeline
- **Feature Engineering**: 50+ technical indicators and market features
- **Model Training**: TensorFlow/Keras with LSTM and Dense model support
- **Policy Generation**: Automated policy.json creation with confidence thresholds
- **Yahoo Finance Integration**: Market data enrichment for training
- **Time Series Validation**: Proper temporal splits for backtesting

### Strategy Library (23 Strategies)
- **Trend Following**: ADX, SuperTrend, Donchian Breakout
- **Mean Reversion**: Bollinger Bands, RSI2, VWAP Reversion  
- **Momentum**: Awesome Oscillator, Bears/Bulls Power
- **Multi-Asset**: Forex, Gold, Indices specialized strategies
- **Advanced**: Multi-indicator fusion, Opening Range Breakout

### Data Management
- **Knowledge Base**: Centralized trade logging with CSV rotation
- **Features Export**: Long-format feature data for ML training
- **Insights Generation**: Performance analytics per strategy/symbol/timeframe
- **Common Files**: Cross-EA data sharing via MT5 Common Files directory

## Insights Handshake and Live Auto-Reload

To avoid frequent rebuilds while still giving LiveEA immediate access to fresh insights:

- PaperEA writes `DualEA/insights.ready` after a successful rebuild of `insights.json`.
- LiveEA can request a rebuild by creating `DualEA/insights.reload` and watches for `insights.ready` via `OnTimer`.
- LiveEA inputs:
  - `InsightsAutoReload` (bool): enable the watcher/requester.
  - `InsightsLiveFreshMinutes` (int): freshness threshold for `insights.json` before requesting a rebuild.
  - `InsightsReadyPollSec` (int): timer poll frequency.
- PaperEA staleness policy inputs:
  - `InsightsStaleHours = 48` (auto rebuild if aged beyond this; 0=disable age check)
  - `InsightsMinSourceAdvanceHours = 48` (require sources to be ≥ this much newer than `insights.json`)
  - `InsightsMinIntervalHours = 24` (minimum interval between rebuilds per symbol|timeframe slice, tracked in-memory)
  - `InsightsRebuildTimeoutMs = 1800000` (30 minutes, cooperative timeout)
- Builder logging is behind a verbosity flag and uses a very large chunk size to reduce progress spam; final success/failure logs are always emitted.

## Gating Pipeline (Early + Risk4) and Telemetry

Both EAs expose the same gate helpers and inputs for parity:

- News gate: `UseNewsFilter`, `NewsBufferBeforeMin`, `NewsBufferAfterMin`, `NewsImpactMin`, `NewsUseFile`, `NewsFileRelPath`.
- Promotion window: `UsePromotionGate`, `PromoLiveOnly`, `PromoStartHour`, `PromoEndHour`.
- Regime gate (ATR%): `UseRegimeGate`, `RegimeATRPeriod`, `RegimeMinATRPct`, `RegimeMaxATRPct`.
- Circuit cooldown: `CircuitCooldownSec`.

Pipeline phases and call sites:

1) Early phase (pre-selector/insights)
   - LiveEA function: `EvaluateAndMaybeExecute_PreSelector()`
   - PaperEA call: `EarlyGatesAllow()` early in `OnTick()` before any selection/execution
   - Behavior: block immediately unless `NoConstraintsMode` is enabled (LiveEA uses `NoConstraintsMode`; PaperEA typically runs with it true for data collection)

2) Risk4 phase (pre-execution)
   - LiveEA function: `EvaluateAndMaybeExecute_PreExecute()`
   - PaperEA call: `Risk4GatesAllow()` immediately before any execution-like action (simulate parity; PaperEA primarily logs/tracks)

Telemetry and logs:

- Each gate emits a `[TAG] allow|block latency_ms=N` line and a telemetry event with `phase` and `p6_latency_ms`.
- Tags: `[NEWS]`, `[PROMO]`, `[REGIME]`, `[CIRCUIT]`.

Parity note:

- LiveEA and PaperEA share identical inputs and helper implementations for these gates for consistent behavior and observability. LiveEA wires them via `EvaluateAndMaybeExecute_*` functions; PaperEA uses `EarlyGatesAllow()` in `OnTick()` and exposes `Risk4GatesAllow()` for placement near any execution-equivalent points.

## Current Capabilities (PaperEA)
- Modular strategies via `IStrategy` base class stored in `CArrayObj`.
- Trade execution via `CTradeManager`:
  - Market and pending orders
  - SL/TP management
  - Trailing stop manager with fixed‑points policy (activation, distance, step)
- Knowledge Base logging via `CKnowledgeBase`:
  - Trade execution events → `knowledge_base_events.csv`
  - Full trade records → `knowledge_base.csv`
  - Both files stored under MT5 Common Files: `Common\Files\DualEA\...`
- Features export for ML via `ExportFeatures()` → `features.csv` (schema in `docs/KB-Schemas.md`)
- Inputs (PaperEA):
  - Position and risk: `LotSize`, `MagicNumber`, `StopLossPips`, `TakeProfitPips`, `MaxOpenPositions` (0=unlimited)
  - Trailing defaults (used if a strategy doesn’t set them): `TrailEnabled`, `TrailType=0(fixed)`, `TrailActivationPoints`, `TrailDistancePoints`, `TrailStepPoints`
  - Mode toggles: `NoConstraintsMode` (bool, default true) — disables all gating and caps for maximum data collection (trading hours, selector gating, insights gating, exploration caps, and open-position limit)
  - Logging: `KBDebugInit` (writes INIT line), `DebugTrailing` (reserved)
  
- Modules available (planned integration):
  - `PositionManager` (see `Include/PositionManager.mqh`) — implemented module providing scaling/exits/brackets; integration into PaperEA/LiveEA is planned behind a `UsePositionManager` feature flag (off by default).

### Exploration Mode & Insights Gating
- Purpose: allow limited trades to bootstrap insights for unseen slices (strategy|symbol|timeframe).
- No‑slice‑only bypass: exploration bypass is permitted only when there is truly no existing slice. If a slice exists but fails thresholds, it is blocked (no bypass).
- Caps and persistence:
  - Per‑day cap: `ExploreMaxPerSlicePerDay` (default 2; 0=unlimited)
  - Per‑week cap: `ExploreMaxPerSlice` (default 3; 0=unlimited), week bucket = Monday yyyymmdd
  - Counters persist in Common Files:
    - `DualEA/explore_counts_day.csv` (key,day_yyyymmdd,count)
    - `DualEA/explore_counts.csv` (key,week_monday_yyyymmdd,count)
- Interaction with `NoConstraintsMode`:
  - When enabled, insights gating and exploration caps are bypassed entirely for unrestricted trading.
- Logs (Journal):
  - Allow: `GATE: explore allow <strat> on <symbol>/<tf> ... (day=d/D, week=w/W)`
  - Block (cap): `GATE: blocked ... reason=explore_cap_day|explore_cap_week (day=d/D, week=w/W)`
- Resetting caps: delete the above CSV files from `Common\Files\DualEA` to reset counts.

### Default Policy Fallback & Policy Gating
- Inputs (PaperEA):
  - `UsePolicyGating` (bool)
  - `DefaultPolicyFallback` (bool, default true)
  - `FallbackDemoOnly` (bool, default true)
  - `FallbackWhenNoPolicy` (bool, default true)
- Policy loaded detection:
  - Policy is considered "loaded" when `policy.json` provides one or more slices (i.e., `slices > 0`).
  - `min_confidence` from `policy.json` is used as a gating threshold, not to determine loaded state.
- Fallback paths (neutral, safe for data collection):
  - `fallback_no_policy`: triggers when `UsePolicyGating=true` and no policy is loaded (slices=0) and `FallbackWhenNoPolicy=true`.
    - Allowed by default only on demo accounts (`FallbackDemoOnly=true`).
    - Bypasses insights thresholds and exploration caps.
    - Uses neutral scaling (no SL/TP/trailing multipliers).
    - Log example: `FALLBACK: no policy loaded -> neutral scaling used for <strat> on <symbol>/<tf> demo=<true|false>`.
  - `fallback_policy_miss`: triggers when `UsePolicyGating=true`, policy is loaded but the exact strategy/symbol/timeframe slice is missing.
    - Same allow conditions and behavior as above (demo-only by default, neutral scaling, bypass caps).
    - Log example: `FALLBACK: policy slice missing -> neutral scaling used for <strat> on <symbol>/<tf> demo=<true|false>`.
- Policy scaling application:
  - `ApplyPolicyScaling()` runs only when policy is loaded and an exact/aggregate slice exists (ppol>=0.0).
  - On fallback, scaling is neutral (no adjustments applied).
- Exploration counters:
  - Fallback trades do not consume exploration quotas and do not increment exploration counters.

## Where Files Are Written
We target the MT5 Common Files area so Strategy Tester, Demo/Paper, and Live share the same outputs.
- Typical path: `C:\Users\<you>\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DualEA\`
- Alternative (some installs): `C:\ProgramData\MetaQuotes\Terminal\Common\Files\DualEA\`

Files produced:
- `knowledge_base.csv` (header created at init)
- `knowledge_base_events.csv`
 - `features.csv` (per-trade feature rows for ML)
 - `explore_counts.csv` (weekly exploration usage)
 - `explore_counts_day.csv` (daily exploration usage)
 - `insights.json` (aggregated performance by strategy/symbol/timeframe)
 - `policy.json` (exported by trainer) and `policy.reload` (touch file to trigger hot-reload)

## Documentation
- [Phase 3 Plan](docs/Phase3.md)
- [Policy JSON Schema](docs/PolicySchema.md)
- [Knowledge Base CSV Schemas](docs/KB-Schemas.md)
- [Operations Guide](docs/Operations.md)

## Knowledge Base Schemas
- `knowledge_base.csv`
  - Columns: `timestamp,symbol,type,entry_price,stop_loss,take_profit,close_price,profit,strategy_id`
- `knowledge_base_events.csv`
  - Columns: `timestamp,strategy,retcode,deal,order`

## How To Build
- Use the provided batch scripts:
  - PaperEA: open a terminal in `MQL5/Experts/Advisors/DualEA/PaperEA/` and run `build_paperea.bat`
  - LiveEA: open a terminal in `MQL5/Experts/Advisors/DualEA/LiveEA/` and run `build_liveea.bat`
- Or compile from MetaEditor (`PaperEA.mq5` / `LiveEA.mq5`).

## How To Run (Strategy Tester)
1. Open Strategy Tester and select `PaperEA`.
2. On the Inputs tab, click Reset to load the latest defaults.
3. Adjust `LotSize`, `SL/TP`, and trailing inputs as needed.
4. Run a backtest; outputs will be in `Common\Files\DualEA\` and visible in the Journal.

## Trainer Workflow (Windows)
 - Requirements: Python 3, internet access (for pip + Yahoo enrichment).
 - Steps:
   1) Open a terminal in `MQL5/Experts/DualEA/ML/`.
   2) Run: `run_train_and_export.bat`
 - What it does:
   - Creates `.venv/`, installs `ML/requirements.txt`.
   - Runs `train.py` to produce `ML/artifacts/tf_model.keras`, `scaler.pkl`, `features.json`.
   - Runs `policy_export.py --min_conf 0.45` to write `Common\Files\DualEA\policy.json` with per-slice `p_win` and scaling fields: `sl_scale`, `tp_scale`, `trail_atr_mult`.
   - Touches `Common\Files\DualEA\policy.reload`.
- EA behavior:
  - `PaperEA` calls `CheckPolicyReload()` in both `OnTimer()` and `OnTick()`; when `policy.reload` exists, it reloads `policy.json` and logs `Policy gating: min_conf=..., slices=N`.
  - On trade execution, if policy is loaded, the EA applies per-slice scaling before sending the order.

### Rebuilding Insights (without rerunning trades)
- Use the provided script to recompute `insights.json` from the current `features.csv`:
  1) In MT5 Navigator → Scripts → run `InsightsRebuild`.
  2) Check `Common\Files\DualEA\insights.json` and Journal for status.

## Troubleshooting
- “No CSVs in MQL5/Files”: Expected. Tester and Live now write to `Common\Files\DualEA` using `FILE_COMMON`.
- “Error 5004 opening file”: First‑run read attempts can fail if the file doesn’t exist; the constructor now creates the file and header without logging an error.
 - “Inputs not showing in Tester”: Click Inputs → Reset; MT5 caches previous inputs.

---

## PaperEA

- Purpose: primary data-collection EA for backtests and demo/paper runs. Logs features, events, and trades to the shared Knowledge Base for ML and insights.
- Execution model:
  - OnInit/OnTick drive the scan→gate→execute path; logs to KB on every decision and execution.
  - Policy reload via `DualEA/policy.reload` checked in `CheckPolicyReload()`; telemetry flush after scans.
  - Timer-based scanning per Phase 6 design may be enabled as parity with LiveEA (see Phase 6) where implemented.
- Gating and exploration caps:
  - `NoConstraintsMode` (default true) can bypass all gates/caps for unrestricted exploration (for ML bootstrapping).
  - Exploration caps persist in Common Files: `DualEA/explore_counts_day.csv`, `DualEA/explore_counts.csv`.
  - No‑slice‑only bypass: exploration only bypasses when a slice truly doesn’t exist; existing under‑threshold slices remain gated.
  - Reset by deleting the above CSVs in `Common\Files\DualEA`.
- Policy integration and fallback:
  - Inputs: `UsePolicyGating`, `DefaultPolicyFallback`, `FallbackWhenNoPolicy`, `FallbackDemoOnly`.
  - When policy is loaded and slice exists, `ApplyPolicyScaling()` adjusts SL/TP/trailing.
  - On fallback (no policy or slice missing), trades use neutral scaling, do not consume exploration quotas, and bypass caps (demo‑only by default).
- Persistence paths (MT5 Common Files):
  - `knowledge_base.csv`, `knowledge_base_events.csv`, `features.csv`, `insights.json`, exploration CSVs under `Common\Files\DualEA`.
- CI hooks (insights freshness + coverage):
  - Use `kb_check.bat` to rebuild and validate `insights.json` headlessly; fails on stale/empty slices and on missing required coverage.
  - Example:
    ```powershell
    kb_check.bat --build-insights --attempt-run-script --run-validate --fail-on-stale --fail-on-empty-slices --require-symbols=USDCNH --require-timeframes=60 --require-strategies=BollAverages,DonchianATRBreakout,RSI2BBReversion --fail-on-missing-required --show-report
    ```
## Roadmap (Phased)
This roadmap aligns with the implementation plan.

 For detailed Phase 3 guidance (docs, hygiene, scoring, roadmap), see:
 - `docs/Phase3.md`

### Action Framework — 3 Phases × 3 Cycles (Merged)
 - Source: `docs/DualEA_Action_Framework.md` (full details and templates)
 
 - Phase 1 — Codebase & Requirements Deep Dive
   - Cycle 1: Structural Audit (jailbreak permitted)
     - Inventory gating paths (strategy → policy → insights → execution)
     - Trace file I/O and timers: `CheckPolicyReload()`, `CheckInsightsReload()`, staleness checks
     - Identify insertion points: circuit breakers, session/news filters, PositionManager, correlation, vol sizing, regime
     - Deliverables: audit map + risk log
   - Cycle 2: Requirements Mapping
     - Spec one‑pagers per feature with inputs, data flow, telemetry, failure/rollback
   - Cycle 3: Risk & Gaps Closure
     - Threat model: file races, stale artifacts, partial reloads; decide LiveEA fail‑safe defaults
     - Deliverables: mitigations + rollback levers; updated lifecycle gates
 
 - Phase 2 — Design, Build, Validate
   - Cycle 1: Task Decomposition
     - Backlog with effort/risk/owner/sequence for FR‑01..FR‑10
   - Cycle 2: Code + Peer Review
     - Definition of Ready: inputs defined, telemetry standardized, rollback behavior set
     - Guidelines: feature flags (`Use*`), shared includes under `Include/`
   - Cycle 3: QA + Fuzzing
     - Unit‑like stubs, deterministic sims, log assertions; fuzz missing files/reload storms/high‑tick
 
 - Phase 3 — Polish, Lockdown, Final Scoring
   - Cycle 1: Docs & architecture alignment (README + lifecycle + operator runbooks)
   - Cycle 2: Code hygiene & consistency (inputs/enums/log tags; dead‑code purge)
   - Cycle 3: Final scoring (correctness/safety/observability/perf) + next roadmap
 
 #### Action Backlog (Pre‑Implementation Specs)
 - FR‑01 Circuit Breakers — Inputs: `UseCircuitBreakers`, `DailyLossLimit`, `DailyDrawdownLimit`, `CooldownMinutes`; block entries, allow exits; telemetry `cb:*`; DoD: day rollover sims
 - FR‑02 Session/Window Filter — Inputs: `UseSessionFilter`, `SessionTZ`, `SessionWindows`; pre‑gate block; DoD: DST/tz edges
 - FR‑03 News Filter — Inputs: `UseNewsFilter`, `ImpactLevelMin`, `PreLockoutMin`, `PostLockoutMin`; offline‑safe fallback; DoD: replay test
 - FR‑04 Position Manager (v1) — Inputs: `UsePositionManager`, `ExitProfile`, `ClusterMinPts`, `PerSymbolMax`; centralized exits/scaling hooks; DoD: backtest diffs. (Core module implemented in `Include/PositionManager.mqh`; integration behind flag pending.)
 - FR‑05 Correlation Exposure Caps — Inputs: `UseCorrelationCaps`, `CorrLookbackDays`, `MaxGroupExposure`; cap grouped exposure; DoD: deterministic calc
 - FR‑06 Volatility Position Sizing — Inputs: `UseVolSizing`, `ATRPeriod`, `RiskPerTrade`; ATR‑adaptive lots; DoD: regime consistency, caps respected
 - FR‑07 Regime Detector Stub — Inputs: `UseRegime`, `RegimeMethod`; tag regime; optional gating modifier; DoD: stable tags
 - FR‑08 Promotion Gate & Evaluator — Inputs: min trades/hit‑rate/expectancy/DD/Sharpe; artifact: `Scripts/DualEA/AssessPromotion.mq5`; DoD: reproducible
 - FR‑09 Telemetry Standardization & Ops Views — Event schema/fields/severity; rotate/size bounds; optional ops notebooks
 - FR‑10 Performance — Event batching, log throttling, timer cadence review; DoD: CPU/mem profile under stress
 
 #### Control Gates (Before Coding)
 - Gate A: Specs complete (inputs, flow, telemetry, rollback) for FR‑01..FR‑10
 - Gate B: Test plans defined; simulators/log assertions ready
 - Gate C: Security + fail‑safe review; LiveEA defaults conservative
 
 #### Ownership & Sequencing (Draft)
 - Wave 1 (risk first): FR‑01, FR‑02, FR‑08
 - Wave 2 (exposure/positioning): FR‑04, FR‑05, FR‑06
 - Wave 3 (context/perf): FR‑03, FR‑07, FR‑09, FR‑10
 - Note: Features default‑off in LiveEA until validated in PaperEA
 
  ### Status Dashboard
  - Completed:
    - Phase 1: Data & Insights Foundation (insights builder, headless rebuild, validator, CI flags, Common Files outputs)
    - Phase 2: ML/LSTM Pipeline (trainer + policy export + batch runner; PaperEA policy hot‑reload integrated)
  - Phase 2a: PaperEA Execution & Telemetry (baseline complete; timer-scan parity tracked under Phase 6)
  - Phase 3 (core): LiveEA core loop with policy gating/fallbacks and scaling
    - `LiveEA/LiveEA.mq5`: policy hot‑reload (tick+timer), `ApplyPolicyScaling()` incl. trailing scaling via `trail_atr_mult` (applies to ATR and fixed trailing), fallback gating (`fallback_no_policy`, `fallback_policy_miss`, demo‑only by default), heartbeat with fallback flags
- In Progress:
  - Phase 3: LiveEA hardening (risk gates, stricter caps, optional shadow‑mode, per‑minute de‑dup)
  - Phase 6: Low‑Latency Minutely Scanner & ML‑Enriched Orchestration
  - Phase 6: Low‑Latency Minutely Scanner & Orchestration (central `ScanStrategies`, minute de‑dup, parity with OnTick)
  - Phase 2a → P1C1 (ACTIVE): Structural Audit for PaperEA (gating/caps persistence, telemetry, KB writes, insights staleness, CI validators)
  - Phase 4/7/8: Risk/Telemetry/Adversarial hardening — partial primitives present
  - Ops/CI TODOs (remaining):
    - Add `kb_check.bat` for headless insights rebuild+validate and wire into CI (fail on stale/coverage).
    - Add `scripts/RunInsightsValidation.ps1` and `ScheduleInsightsValidation.ps1` for scheduled validation.
    - Optional CI trainer job: run `ML/run_train_and_export.bat` on schedule/data‑change; publish `policy.json` and touch `policy.reload`.
    - Operator runbook: KB rebuild/validate flows and artifact paths under `Common\\Files\\DualEA`.
    - Telemetry: concise summaries for insights rebuild/validation outcomes.
 - Not Implemented:
   - Phase 5, 9, 10, 11

### Phase 1: Data & Insights Foundation
- TODOs (hardening and ops):
  - CI integration: add `kb_check.bat` and wire `Scripts/ValidateInsights.mq5` to CI to fail on stale `insights.json`, empty/missing slices, and unmet required coverage (symbols/TFs/strategies).
  - Headless rebuild wrapper: provide a batch/PowerShell entry point to run `Scripts/InsightsRebuild.mq5` non‑interactively (for CI/scheduled tasks).
  - Schema versioning: version `insights.json` and add compatibility checks in `Include/StrategySelector.mqh`; document version in `docs/KB-Schemas.md`.
  - I/O hardening: ensure `FolderCreate("DualEA", FILE_COMMON)` is called by all writers; prefer robust readers (`FILE_TXT|FILE_ANSI`), skip malformed rows, and log/continue.
  - Validator enhancements: expand `ValidateInsights` to assert non‑empty required metrics per slice and configurable thresholds; surface a concise report.
  - Ops scheduling: optionally add `scripts/RunInsightsValidation.ps1` and `ScheduleInsightsValidation.ps1` to run validation on a cadence.

### Phase 2: ML/LSTM Pipeline
- TODOs (ops/hardening):
  - CI trainer job: run `ML/run_train_and_export.bat` on schedule or data‑change; publish `policy.json` to Common Files and touch `policy.reload`.
  - Provenance & signing: include model hash, train window, metrics in `policy.json`; sign/hash for integrity; keep last‑known‑good for rollback.
  - Shadow eval & A/B: support dual policies in PaperEA (shadow mode) prior to promotion to LiveEA.
  - Calibration & thresholds: reliability diagrams, Brier, per‑slice min_conf calibration; document acceptance bands.
  - Monitoring: log SHAP/feature importance drift signals; alert on material drift.
  - Rollback guardrails: auto‑rollback to last‑known‑good on parse/plausibility failure during hot‑reload.

 Note (sequencing): core ML training/export and PaperEA policy load are implemented. The structured 3×3 audit for Phase 2 will begin after Phase 3 — Cycle 3.

- Suggestions:
  - Use walk‑forward splits; track ROC‑AUC, Brier, Expected‑R; calibrate probabilities and thresholds per slice.
  - Export `policy.json` with provenance (model hash, train window, metrics); sign/hash for integrity.
  - Run A/B policies and shadow evaluation in PaperEA before promotion to LiveEA.
  - Log SHAP/feature importance to monitor drift and potential leakage.

### Phase 2a: PaperEA Execution & Telemetry
- TODOs (remaining):
  - CI wiring: integrate `Scripts/ValidateInsights.mq5` into CI and add `kb_check.bat` to fail on stale `insights.json`, empty/missing slices, and missing required coverage.
  - Headless operations: add `scripts/RunInsightsValidation.ps1` and `ScheduleInsightsValidation.ps1` for scheduled rebuild/validation.
  - Ops docs: add a short operator runbook covering rebuild/validate flows and artifact locations in `Common\\Files\\DualEA`.
  - Explore caps ops: provide a lightweight reset helper and a smoke test that verifies daily/weekly counters persist and increment as expected.
  - Telemetry polish: emit concise summaries for insights rebuild/validation outcomes.
- Status:
  - Baseline implemented (modular strategies, exploration caps/gating, `NoConstraintsMode`, policy hot‑reload/fallbacks, Common Files persistence).
  - Timer‑based scanning parity with LiveEA is tracked under Phase 6.

 ### Phase 3: LiveEA & Feedback Loop
- Implement `LiveEA.mq5` with the same strategies but stricter gating (policy + risk limits).
- LiveEA logs to the same KB; trainer merges Paper+Live data.
- Feedback loop: Paper adapts based on Live outcomes via retrained policy.
- TODOs (remaining):
    - LiveEA shadow‑mode: log candidate decisions; execute only top ML‑ranked passing min_conf and risk budget.
    - Tighter gates vs PaperEA: stricter min_conf, spread/news/session caps, lower exploration caps.
    - Enforce risk/circuit‑breakers: max daily loss, session drawdown, stricter spread/news/session caps.
    - One‑execution‑per‑slice‑per‑minute de‑dup; deterministic tie‑breakers.
    - Full timer‑scan parity (Phase 6): centralize ScanStrategies; consistent OnTick/Timer paths.
    - Policy hot‑reload guardrails with rollback to last‑known‑good on parse/plausibility failure.
    - Integrate `Include/PositionManager.mqh` behind `UsePositionManager`; route sizing/exits through it.
    - Prep hooks for Phase 6 parity: shared scanner entrypoints and per‑minute dedup state.
  #### Red‑Team Execution Plan (3×3) — Current focus
- Phase 1: Codebase & Requirements Deep Dive
  - Cycle 1  Structural Audit for LiveEA 
  - Cycle 2: Requirements Mapping to concrete code paths and artifacts; close gaps
  - Cycle 3: Risk & Gaps Closure; redesign fragile modules as needed
- Phase 2: Design, Build, Validate
  - Cycle 1: Task decomposition for LiveEA hardening; define acceptance criteria
  - Cycle 2: Implement fixes; peer review and adversarial edge‑case tests
  - Cycle 3: QA + fuzzing of IO/races; enforce CI gates
- Phase 3: Polish, Lockdown, Final Scoring
  - Cycle 1: Docs & architecture alignment (README + docs/Phase3.md)
  - Cycle 2: Code hygiene & consistency; refactors; dead‑code purge
  - Cycle 3: Final scoring + roadmap

Next: Upon completing Phase 3 — Cycle 3 above, begin Phase 2 — Cycle 1 (ML/LSTM Pipeline) as the next 3×3 plan.

### Phase 4: Risk & Safety Systems
 ##### Phase 4 TODO checklist
 - [ ] Run Strategy Tester to trigger each Phase 4 gate and confirm risk4_* telemetry + margin_level reason

 #### Phase 4 Telemetry: risk4_* events and reason strings

- `risk4_spread`: spread cap gating.
  - Shadow (NoConstraintsMode=true): `LogGatingShadow(strategy, symbol, tf, "risk4_spread", ok, reason, true)`
  - Enforced: `[RISK4] blocked <strategy> on <symbol>/<tf> reason=<spread_reason>` and `LogGating(symbol, tf, strategy, "risk4_spread", allow, reason)`
### Phase 5: Dynamic Strategy/Indicator Selection
  - Status: In progress — merged into LiveEA: cooldown + auto re-enable + dynamic auto‑tuning with telemetry (`underperf_auto_disabled`, `p5_cooldown`, `p5_auto_reenabled`, `p5_auto_tune`).
    - New (LiveEA): Phase 5 telemetry completed for `p5_refresh`, `p5_rescore`, and `p5_selector_cfg`.
  - TODO (prioritized)
    1. Selector wiring parity in both EAs (OnInit): thresholds, recency overlay, strict thresholds, and per‑symbol/timeframe strategy registration.
       - Acceptance: strategies register per symbol/TF; logs/telemetry confirm thresholds/recency overlays applied.
    2. Correlation‑aware pruning within selector/gating to retain a diversified subset per symbol/timeframe.
       - Emit `p5_corr` telemetry; cap per symbol/TF.
    3. Multi‑timeframe confirmations in selector/gating with inputs (e.g., `EnableMTFConfirmations`, `MTFConfirmTF`, `MTFConfirmMinScore`) and telemetry (`p5_mtf`).
    4. Parameter stability tracking in selector; compute stability score and gate via (`P5_StabilityGateEnable`, `P5_StabilityWindowDays`, `P5_StabilityMaxStdR`) with telemetry (`p5_stability`).
    5. Policy integration for subset selection/weighting from ML policy (beyond neutral scaling); document and gate safely.
    6. Feature/telemetry export parity after exec in both EAs (ATR, spread, TF, trailing params, strategy features).
    7. Telemetry consistency across both EAs: standardize remaining `p5_*` event keys and shadow logging under `NoConstraintsMode` (PaperEA parity).
    8. Test plan: backtests (walk‑forward), forward/demo runs, and monitoring to validate selector and gating behavior.
### Phase 6: Low‑Latency Minutely Scanner & ML‑Enriched Orchestration
- Status: Partial — OnTimer heartbeat/reload present; centralized `ScanStrategies` with minute de‑dup not yet implemented.
- Guarantee both EAs "look" for trades at least every minute, independent of tick arrival.
  - Add inputs: `TimerScanEnabled` (bool, default `true`), `TimerScanSeconds` (int, default `60`).
  - `OnInit()`: configure `EventSetTimer(TimerScanSeconds)` when `TimerScanEnabled`.
  - `OnTimer()`: run a `ScanStrategies()` routine that performs the same Refresh → CheckSignal → gating (selector + insights + policy + caps) path as `OnTick()`.
  - Deduplicate within a minute per `symbol|timeframe|strategy` using a rolling `LastScanMinute` map to avoid duplicate triggers if ticks also arrive.
  - Preserve existing behavior: always `CheckPolicyReload()` and `Telemetry.Flush()` on timer.
- Performance & reliability hardening
  - Pre‑create and reuse indicator handles for all registered strategies/timeframes to avoid reallocation overhead per scan.
  - Cache policy and insights in memory; throttle file I/O to timer ticks; batch telemetry writes.
  - Optional: `EventSetMillisecondTimer(250–1000ms)` for ultra‑low‑latency scanning in LiveEA; gate by CPU budget.
- LiveEA enrichment path
  - Consume trained ML outputs for per‑slice `min_conf`, expected‑R, and dynamic sizing; apply via `ApplyPolicyScaling()`.
  - Maintain exploration caps and detailed `LogGating`/`LogGatingShadow` for full auditability.
- Test & validation plan
  - Backtests: walk‑forward with OOS across 3–5y per symbol/TF, including realistic spread/slippage/commission; parameter stability and FDR controls.
  - Forward tests: parallel demo/real, M1 granularity logs, latency SLO (<250ms scan→gate→exec where broker allows), missed‑opportunity audits.
  - Monitoring: 60s heartbeat, exploration cap summaries, and per‑slice gating counters.

 - Suggestions:
   - Guard `OnTimer()` with a re‑entrancy flag to prevent overlapping scans; prefer non‑blocking work.
   - Expose `TimerScanSeconds` overrides (e.g., 30s) and optional `EventSetMillisecondTimer` for LiveEA with CPU budget guard.
   - Record scan→gate latency metrics; emit to telemetry for SLO tracking.
   - Pre‑warm indicator handles in `OnInit()`; refresh/rebuild on symbol/period change; cache policy/insights in memory.
   - Centralize gating in a reusable `EvaluateAndMaybeExecute()` path used by both `OnTick()` and timer scans.

### Phase 7: Monitoring & Telemetry
- Emit telemetry CSV/JSON (tick latency, SL moves, trades/sec, error rates).
- Optional lightweight dashboard (HTML/JS) or notebook to visualize metrics.

 
- Suggestions:
  - Define SLOs: scan→gate latency, missed‑opportunity rate, per‑reason gating counts.
  - Alerts for policy/insights read failures and staleness; log rotation and retention policy.
  - Optional dashboard/notebook; per‑slice counters and trend lines for drift/anomaly detection.

### Phase 8: Adversarial/Jailbreak Hardening
- Fuzz file I/O (empty/corrupt/locked `policy.json`/`insights.json`/CSV) and assert safe fallbacks, halts, or rollbacks.
- Timing/race tests: low-tick periods, bar-boundary races, clock skew; verify de-dup and single-exec semantics.
- Resource pressure: very large CSVs, slow disk; ensure `OnTick()` remains non-blocking, heavy I/O on timer.
- Produce Q&A logs, expert rebuttals, and jailbreak traces mapped to files/modules per @/greep.

 - Suggestions:
   - Add `SafeMode` input to force conservative gating on anomalies; persist last‑known‑good `policy.json`/`insights.json` caches.
   - Create a fuzz harness (script/test) that mutates JSON/CSV and asserts expected EA behavior and logs.
   - Store jailbreak trace logs in `Common\Files\DualEA\jailbreak\` with timestamps and module references.
   - Automate adversarial tests in CI; fail the pipeline on missing fallbacks or unsafe behavior.

### Phase 9: MLOps & Continuous Training
- Data/versioning (DVC/Git LFS), model registry, and feature/label drift detection with alerts.
- Scheduled retraining and policy export with provenance (model hash, data window, metrics).
- Canary deployment of `policy.json` and automatic rollback on degradation or plausibility failures.

 - Suggestions:
   - Define acceptance criteria (min ROC‑AUC/Brier, uplift vs baseline) before policy promotion to LiveEA.
   - Build reproducible training pipelines (seeded, environment‑pinned) and artifact signing.
   - Add drift detectors on features/labels; trigger retrain or quarantine when thresholds are exceeded.
   - Maintain a data catalog of `features.csv` schema versions and TTL/retention policies.

### Phase 10: Multi‑Symbol/TF Orchestration (Optional)
- Option A: one EA per symbol/TF (simple, robust). Option B: single orchestrator scanning a configured portfolio.
- Central registry of symbols/TFs; per-slice de‑dup and CPU budget/load shedding to maintain latency SLOs.
- Consistent telemetry across all slices; portfolio‑level risk budget enforcement.

 - Suggestions:
   - For orchestrator mode: implement per‑slice schedule, backpressure, and fairness to avoid starving symbols.
   - Throttle scanning and degrade gracefully under CPU load; prioritize LiveEA executions.
   - Guard broker API calls; exponential backoff on transient errors; per‑symbol error budgets.
   - Keep robust chart‑per‑slice mode as default until orchestrator proves reliability.

### Phase 11: Performance & Resilience
- Avoid heavy file I/O in `OnTick()`; defer to timer/batched writes; use `FILE_SHARE_*` and rotate logs.
- Pre‑allocate buffers, reuse indicator handles; cap log verbosity on hot paths.
- Watchdog for timer and safe‑mode fallbacks on parse errors (use last‑known‑good caches).

 - Suggestions:
   - Implement log rotation (daily/size‑based) and retention; compress archives.
   - Add a timer watchdog that re‑initializes the timer if missed deadlines are detected.
   - Use re‑entrancy guards around critical sections (order placement, persistence writes).
   - Ensure `OnDeinit()` flushes telemetry and persists counters atomically.

---

## Next Milestones
  - Add features.csv export and insights.json aggregation.
  - Provide Python ML trainer and batch launcher (writes policy.json).
  - Add `policy.json` loader in PaperEA and gating/scaling application.
  - Skeleton `LiveEA.mq5` with circuit breaker checks.

## LiveEA: PositionManager — Correlation Sizing + Dynamic Risk Caps

This section documents the LiveEA wiring of `Include/PositionManager.mqh` for correlation‑aware sizing and dynamic risk caps. All features are behind `UsePositionManager` and new PM inputs.

### Inputs (LiveEA)
- PositionManager switches
  - `UsePositionManager` (bool)
  - `PM_EnableCorrelationSizing` (bool, default true)
  - `PM_EnableAdaptiveSizing` (bool), `PM_MinSizeMult` (double), `PM_MaxSizeMult` (double)
  - `PM_ScalingProfile` (int: 0=Aggressive, 1=Moderate, 2=Conservative)
  - `PM_EnableVolatilityExit` (bool), `PM_VolatilityExitATRMult` (double)
- Dynamic risk caps (optional)
  - `PM_EnableDynamicRiskCaps` (bool)
  - `PM_MaxDailyDDPct` (double), `PM_MaxPosRiskPct` (double), `PM_MaxPortfolioRiskPct` (double), `PM_RiskDecay` (double 0..1)
- Correlation sizing floors
  - `PM_CorrMinMult` (double) — minimum fraction of base lots allowed after correlation dampening
  - `PM_CorrMinLots` (double) — absolute minimum lots floor after dampening

### Behavior
- New entries: after policy scaling (`ApplyPolicyScaling`), LiveEA applies correlation‑adjusted sizing via `CPositionManager.CalculateCorrelationAdjustedVolume(symbol, base_lots)`.
  - Floors: `PM_CorrMinMult * base_lots` and `PM_CorrMinLots` are enforced to avoid over‑dampening.
- Scale‑ins: when PositionManager proposes `vol_scaled`, LiveEA applies the same correlation dampening and floors before overriding `order.lots`.
- Dynamic risk caps: configured in `OnInit()` via `CPositionManager.SetDynamicRisk(...)`. Internally caps additional size growth (implementation advisory, subject to future expansion).

### Telemetry & Logs
- Events: `pm_corr_sizing`, `pm_corr_floor`, `pm_corr_scale_in`, `pm_corr_floor_scale_in` with correlation value and before/after lots.
- Init log: `[PM] Initialized (...)` includes adaptive, profile, volatility exit, and dynamic risk params.

### Validation
1) Enable `UsePositionManager=true`, `PM_EnableCorrelationSizing=true`.
2) Open a correlated position (e.g., EURUSD) and then trade a related pair (e.g., GBPUSD). Expect reduced lots and `pm_corr_sizing` event.
3) Trigger a scale‑in via PositionManager; expect `pm_corr_scale_in` and floor events if dampening is severe.
4) Toggle `PM_CorrMinMult` / `PM_CorrMinLots` to observe floors applying (logs show before/after + floor values).

## License
Copyright 2025, Windsurf Engineering.

If you truly need low-latency sync later, consider:
- Named pipes or local TCP with a lightweight Python service
- A minimal REST loopback server

Note: These add failure modes and deployment friction; file-based I/O is simpler and reliable for MT5. Prefer file-based until a concrete latency SLO requires otherwise.

## Appendix A: Red‑Team Artifacts (Q&A, Rebuttals, Jailbreak Traces)

To operationalize the 3×3 red‑team process, store artifacts in MT5 Common Files for both Tester and Live to access.

- Base path: `Common\\Files\\DualEA\\jailbreak\\`
- Run layout:
  - `jailbreak\\runs\\YYYYMMDD_HHMMSS/`
    - `qna.md` — Q&A log for the session
    - `rebuttals.jsonl` — Expert rebuttals (JSONL)
    - `traces.jsonl` — Jailbreak traces (JSONL)
    - `summary.md` — Short session summary with outcomes and follow‑ups
  - `jailbreak\\latest/` — optional symlink/copy of most recent run for dashboards

### A.1 Q&A Log (Markdown)

Minimal, structured template capturing prompts, answers, and references to code.

```markdown
# Red‑Team Q&A — <YYYY‑MM‑DD HH:MM:SS>

## Q1: <question>
- Context: <module(s) e.g., `Experts/Advisors/DualEA/PaperEA/PaperEA.mq5`>
- Hypothesis: <expected behavior>
- Answer: <observed behavior/decision>
- Evidence: <file refs, line ranges, logs>
- Outcome: pass | fail | needs‑followup

## Q2: ...
```

### A.2 Expert Rebuttals (JSONL)

One JSON per line with explicit links to files/modules and decisions.

```json
{"id":"rb_0001","claim":"Exploration bypass triggers with existing slice","rebuttal":"Bypass is no‑slice‑only; existing under‑threshold slices are gated","evidence_files":["Experts/Advisors/DualEA/PaperEA/PaperEA.mq5"],"decision_paths":["Gate->Insights->ExploreCaps"],"status":"resolved","timestamp":"2025-08-17T00:00:00Z"}
```

Fields:
- `id`: stable id
- `claim`: red‑team claim
- `rebuttal`: concise counterargument
- `evidence_files`: array of repository paths
- `decision_paths`: e.g., `Scan->Selector->Gate->Execute`
- `status`: open | resolved | needs‑work
- `timestamp`: ISO8601

### A.3 Jailbreak Traces (JSONL)

Record adversarial tests, input mutations, expected vs observed behavior, and severity.

```json
{"ts":"2025-08-17T00:00:00Z","module":"PolicyLoader","file":"Experts/Advisors/DualEA/Include/StrategySelector.mqh","symbol":"EURUSD","timeframe":60,"case":"corrupt_policy_json","mutation":"truncated file","expected":"fallback to last‑known‑good policy with log and no crash","observed":"fallback engaged; neutral scaling applied","outcome":"safe","severity":"low","artifacts":["Common/Files/DualEA/policy.json","Common/Files/DualEA/policy.backup.json"],"notes":"Validated timer reload path and guardrails"}
```

Fields:
- `ts`: timestamp
- `module`, `file`: component and path under repo
- `symbol`, `timeframe`: slice context when applicable
- `case`, `mutation`: short names for cataloging
- `expected`, `observed`: behaviors
- `outcome`: safe | unsafe | inconclusive
- `severity`: low | medium | high
- `artifacts`: related files (Common Files paths allowed)
- `notes`: free‑form

### A.4 Traceability Rules

- Always reference concrete files/paths (e.g., `Experts/Advisors/DualEA/LiveEA/LiveEA.mq5`).
- Map each finding to a decision path: `OnTick()->ScanStrategies()->Gating()->TradeManager.Execute()`.
- Prefer JSONL for machine‑readable aggregation; keep Markdown summaries for humans.
- Attach log snippets (Journal) and KB rows when relevant.

### A.5 CI Hooks

- Copy the latest run into `jailbreak\\latest/` after each session.
- Optional validator can assert that for each `case` seen in traces there is at least one `outcome=safe` or an open issue.
- Include red‑team artifacts in reports alongside insights validation.

### A.6 Operational Notes

- PaperEA and LiveEA do not read from `jailbreak/`; it is a write‑only audit area.
- Keep PII/broker identifiers out of logs; sanitize before sharing.
- Large artifacts (CSV/JSON) should be rotated/compressed if size grows beyond operational limits.

