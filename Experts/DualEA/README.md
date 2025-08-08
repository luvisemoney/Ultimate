# DualEA (Paper + Live) — Modular Multi‑Strategy EA with Knowledge Base and Roadmap

## Overview
DualEA is a modular Expert Advisor system for MetaTrader 5 designed to:
- Run a Paper EA to test strategies and indicators, logging all activity to a shared Knowledge Base.
- Evolve into a Live EA that reads insights and ML policy from the Knowledge Base to gate and size real trades.
- Support advanced trade management (pending orders, SL/TP, trailing) and per‑strategy modularity.

This repo currently focuses on the Paper EA with a production‑ready architecture for logging and advanced trade management. A multi‑phase roadmap below describes the path to Live EA, ML/LSTM policy learning, and institutional safety.

### Architecture (Mermaid)

```mermaid
flowchart LR
  subgraph Paper
    PEA[PaperEA]
    STR[Strategies (IStrategy)]
    TM[TradeManager (SL/TP/Trailing)]
  end

  subgraph KB[Knowledge Base (Common\Files\DualEA)]
    FEAT[features.csv]
    TRD[knowledge_base.csv]
    EVT[knowledge_base_events.csv]
    INS[insights.json]
    POL[policy.json]
  end

  subgraph ML[Trainer (Python LSTM/GRU)]
    TRN[train.py]
  end

  PEA --> TM
  PEA -->|logs| TRD
  PEA -->|events| EVT
  PEA -->|features| FEAT
  FEAT --> TRN
  TRN -->|writes| POL
  POL --> PEA

  subgraph Live
    LEA[LiveEA]
  end

  POL --> LEA
  LEA -->|results| TRD
  LEA -->|events| EVT
```

## Project Structure
```
MQL5/
├── Experts/
│   └── DualEA/
│       ├── PaperEA/                # Orchestrator EA (PaperEA.mq5)
│       └── Include/
│           ├── IStrategy.mqh       # Base class and TradeOrder struct
│           ├── TradeManager.mqh    # Order execution, SL/TP, trailing
│           ├── KnowledgeBase.mqh   # CSV logging (Common Files)
│           └── Strategies/
│               ├── BollAveragesStrategy.mqh
│               └── MeanReversionBBStrategy.mqh
└── Files/ (unused now; we write to Common\Files)
```

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
- Inputs (PaperEA):
  - Position and risk: `LotSize`, `MagicNumber`, `StopLossPips`, `TakeProfitPips`
  - Trailing defaults (used if a strategy doesn’t set them): `TrailEnabled`, `TrailType=0(fixed)`, `TrailActivationPoints`, `TrailDistancePoints`, `TrailStepPoints`
  - Logging: `KBDebugInit` (writes INIT line), `DebugTrailing` (reserved)

## Where Files Are Written
We target the MT5 Common Files area so Strategy Tester, Demo/Paper, and Live share the same outputs.
- Typical path: `C:\Users\<you>\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DualEA\`
- Alternative (some installs): `C:\ProgramData\MetaQuotes\Terminal\Common\Files\DualEA\`

Files produced:
- `knowledge_base.csv` (header created at init)
- `knowledge_base_events.csv`

## Knowledge Base Schemas
- `knowledge_base.csv`
  - Columns: `timestamp,symbol,type,entry_price,stop_loss,take_profit,close_price,profit,strategy_id`
- `knowledge_base_events.csv`
  - Columns: `timestamp,strategy,retcode,deal,order`

## How To Build
- Use the provided batch script:
  - Open a terminal in `MQL5/Experts/DualEA/`
  - Run: `compile.bat`
- Or compile `PaperEA.mq5` from MetaEditor.

## How To Run (Strategy Tester)
1. Open Strategy Tester and select `PaperEA`.
2. On the Inputs tab, click Reset to load the latest defaults.
3. Adjust `LotSize`, `SL/TP`, and trailing inputs as needed.
4. Run a backtest; outputs will be in `Common\Files\DualEA\` and visible in the Journal.

## Troubleshooting
- “No CSVs in MQL5/Files”: Expected. Tester and Live now write to `Common\Files\DualEA` using `FILE_COMMON`.
- “Error 5004 opening file”: First‑run read attempts can fail if the file doesn’t exist; the constructor now creates the file and header without logging an error.
- “Inputs not showing in Tester”: Click Inputs → Reset; MT5 caches previous inputs.

---

## Roadmap (Phased)
This roadmap aligns with the implementation plan.

### Phase 1: Data & Insights Foundation
- Extend KB: record per‑trade features (indicator values, ATR, spread, session, regime, signal strength) and labels (R multiple, MFE/MAE, duration).
- Add `InsightsBuilder` to compute win‑rate, average R, PF, “top signals”, write `insights.json` to `Common\Files\DualEA`.
- Export `features.csv` for ML training.

### Phase 2: ML/LSTM Pipeline
- Build Python trainer (PyTorch/TensorFlow) that reads `features.csv`, trains an LSTM/GRU to predict Prob(win) or Expected R.
- Export `policy.json` with per‑symbol/timeframe thresholds, strategy weights, and SL/TP/trailing scaling.
- PaperEA: load `policy.json` on a timer; gate trades by min‑confidence and adapt order parameters.

### Phase 3: LiveEA & Feedback Loop
- Implement `LiveEA.mq5` with the same strategies but stricter gating (policy + risk limits).
- LiveEA logs to the same KB; trainer merges Paper+Live data.
- Feedback loop: Paper adapts based on Live outcomes via retrained policy.

### Phase 4: Risk & Safety Systems
- Circuit breaker: `MaxDailyLossPct`, `MaxDrawdownPct`, `MinMarginLevel`, `MaxOpenPositions`, `ConsecutiveLossLimit`.
- Optional VaR: estimate risk from recent PnL distribution; block trading if risk exceeds limits.
- Audit logging and hard enforcement in OnTick before execution.

### Phase 5: Dynamic Strategy/Indicator Selection
- Discover strategies/indicators dynamically, score by stability, PF, correlation, and regime fitness.
- Policy selects and weights a subset per symbol/timeframe.

### Phase 6: Monitoring & Telemetry
- Emit telemetry CSV/JSON (tick latency, SL moves, trades/sec, error rates).
- Optional lightweight dashboard (HTML/JS) or notebook to visualize metrics.

---

## Next Milestones
- Add features.csv export and insights.json aggregation.
- Provide Python ML trainer and batch launcher (writes policy.json).
- Add `policy.json` loader in PaperEA and gating/scaling application.
- Skeleton `LiveEA.mq5` with circuit breaker checks.

## License
Copyright 2025, Windsurf Engineering.