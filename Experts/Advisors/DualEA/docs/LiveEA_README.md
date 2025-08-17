# LiveEA - DualEA Live Trading Expert Advisor

## Overview
LiveEA is the live-trading counterpart of DualEA, consuming the same strategy signals and ML policy gating used by `../PaperEA/PaperEA.mq5`, with added live-safety guards. It executes real orders when the ML filter and risk checks permit.

Highlights:
- Always-on ML gating via `Common\Files\DualEA\policy.json`
- Insights auto-build on timer and manual reload via `DualEA\insights.reload`
- Policy hot-reload via `DualEA\policy.reload`
- Telemetry stream to `Common\Files\DualEA\telemetry/*.jsonl`
- Optional PositionManager integration behind a flag (future work)

## Architecture
```mermaid
graph TD
    A[Strategy Signals] --> B[ML Policy Gating]
    B -->|allow/scale/block| C[Live Execution Engine]
    C --> D[Broker/MT5 Orders]

    %% Side channels
    C --> E[Telemetry JSONL]
    C --> F[Knowledge Base CSV]
    C --> G[Features CSV]

    %% Offline/External
    G --> H[Python Policy Builder]
    H --> I[policy.json]

    %% Insights
    G --> J[Insights Builder]
    F --> J
    J --> K[insights.json]

    %% Control flags (Common Files)
    L[policy.reload] --> B
    M[insights.reload] --> J
```

## File Map (relative)
- `../LiveEA/LiveEA.mq5` — main EA
- `../PaperEA/PaperEA.mq5` — paper EA (parity reference)
- `../Include/` — shared utilities (InsightsBuilder, Telemetry, KnowledgeBase)
- `../ML/` — Python scaffolding (README, `policy_builder.py`)

## Common Files I/O
- `DualEA/policy.json` — gating probabilities and optional SL/TP/Trail scales
- `DualEA/insights.json` — insights used by heuristics/exploration
- `DualEA/knowledge_base.csv`, `DualEA/features.csv` — analytics/training
- `DualEA/telemetry/*.jsonl` — runtime telemetry
- `DualEA/policy.reload`, `DualEA/insights.reload` — control flags

## Key Behaviors
- `UsePolicyGating` governs gating and scaling; filter is designed to be always-on with safe fallbacks
- `OnTimer()` calls `CheckPolicyReload()` and `CheckInsightsReload()`
- Auto-rebuild of insights when stale via `Insights_IsStale()` + `Insights_RebuildAndReload()`
- Neutral fallback when slices are missing if enabled by inputs

## Quick Start
1. Compile `LiveEA.mq5` in MetaEditor.
2. Attach to a live/demo chart with file operations allowed.
3. Ensure `DualEA/policy.json` exists in Common Files.
4. Monitor the Experts tab and `DualEA/telemetry` for gating/scaling decisions and order flow.

## ML Integration
- Trainer stub at `../ML/policy_builder.py`
- Reads `DualEA/features.csv` and `DualEA/knowledge_base.csv`
- Writes `DualEA/policy.json` with `min_confidence` and slice entries per strategy/symbol/timeframe

## Position Manager (Planned)
- See `../Include/PositionManager.mqh`. Integrate behind a `UsePositionManager` input to control scaling, exits, correlation, and bracket logic.

## Maintenance
- Use `Scripts/DualEA/ValidateInsights.mq5` to verify `insights.json` freshness and coverage
- Drop `DualEA/policy.reload` or `DualEA/insights.reload` to refresh on-demand

## See Also
- `../PaperEA/PaperEA.mq5`
- `./PaperEA_README.md`
- `./CORE_IMPLEMENTATION_PLAN.md`
- `../ML/README.md`
