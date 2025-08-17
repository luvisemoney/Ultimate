# PaperEA - DualEA Paper Trading Expert Advisor

## Overview
PaperEA is the paper-trading counterpart of DualEA, used to validate strategies, ML policy gating, and position/risk logic before promoting changes to LiveEA. It runs in demo/simulation contexts while mirroring the execution flow of `../LiveEA/LiveEA.mq5` as closely as possible.

Key traits:
- Always-on ML filter via `Common\Files\DualEA\policy.json` with safe fallbacks
- Insights auto-build and manual reload wiring (`DualEA\insights.reload`)
- Telemetry to `Common\Files\DualEA\telemetry/*.jsonl`
- Knowledge base and feature logging to `Common\Files\DualEA\knowledge_base.csv` and `features.csv`
- Parity with LiveEA timer flow and policy reload (`DualEA\policy.reload`)

## Architecture
```mermaid
graph TD
    A[Market Data] --> B[Strategy Signals]
    B --> C[ML Policy Gating]
    C -->|allow/scale/block| D[Paper Execution Engine]
    D --> E[Positions/Orders (sim)]

    %% Side channels
    E --> F[Telemetry JSONL]
    E --> G[Knowledge Base CSV]
    E --> H[Features CSV]

    %% Offline/External
    H --> I[Python Policy Builder]
    I --> J[policy.json]

    %% Insights
    H --> K[Insights Builder]
    G --> K
    K --> L[insights.json]

    %% Control flags in Common Files
    M[policy.reload] --> C
    N[insights.reload] --> K
```

## File Locations (Common Files)
- `DualEA/policy.json` — ML gating probabilities and optional scales (sl/tp/trail)
- `DualEA/insights.json` — insights slices used by heuristics/exploration
- `DualEA/knowledge_base.csv` — trade/episode log for analytics
- `DualEA/features.csv` — indicator and market features
- `DualEA/telemetry/*.jsonl` — buffered telemetry stream
- `DualEA/policy.reload` — signal to reload policy
- `DualEA/insights.reload` — signal to rebuild/reload insights

## Source Layout (relative)
- `../PaperEA/PaperEA.mq5` — main EA
- `../LiveEA/LiveEA.mq5` — live EA (parity target)
- `../Include/` — shared utilities (e.g., insights builder, telemetry, KB)
- `../ML/` — Python ML scaffolding (README, `policy_builder.py`)

## Configuration Highlights
These inputs exist in `PaperEA.mq5` and govern ML gating and insights behavior:
- `UsePolicyGating` — enable policy gating and scaling
- `DefaultPolicyFallback` — allow neutral trading when a policy slice is missing
- `FallbackDemoOnly` — restrict fallback behavior to demo accounts
- `FallbackWhenNoPolicy` — allow trading when `policy.json` is absent
- `InsightsAutoBuild` — enable periodic insights refresh
- `InsightsCheckOnTimer` — enable timer-based staleness checks
- `InsightsStaleHours` — threshold for auto-rebuild

Signals and timers:
- `OnTimer()` checks `CheckPolicyReload()` and `CheckInsightsReload()`
- Manual trigger by creating `Common\Files\DualEA\policy.reload` or `insights.reload`

## Quick Start
1. Attach `PaperEA` to a chart.
2. Ensure file operations are allowed in MT5 (Common tab).
3. Optionally run `Scripts/DualEA/ValidateInsights.mq5` to verify `insights.json` freshness.
4. Drop `DualEA/policy.json` built by `../ML/policy_builder.py` into Common Files.
5. Observe telemetry and gating logs in Experts tab and `telemetry/*.jsonl`.

## ML Integration
- Trainer stub: `../ML/policy_builder.py`
- Reads: `DualEA/features.csv`, `DualEA/knowledge_base.csv`
- Writes: `DualEA/policy.json` with fields: `min_confidence`, slices with `strategy`, `symbol`, `timeframe`, `p_win`, optional `sl_scale`, `tp_scale`, `trail_atr_mult`.

## Insights Workflow
- Builder lives in `Include` and is invoked by PaperEA via `Insights_RebuildAndReload(reason)`
- Auto-rebuild occurs on staleness; manual via `DualEA/insights.reload`

## Telemetry
- Buffered JSONL written to `Common\Files\DualEA\telemetry` with EA lifecycle, gating decisions, and trade events

## Safety and Parity Notes
- Fallbacks ensure safe demo operation when policy is missing or slices are absent
- Timer wiring matches LiveEA to surface issues before promotion
- Scaling helpers apply only when a matching policy slice exists

## See Also
- `../LiveEA/LiveEA.mq5`
- `../docs/CORE_IMPLEMENTATION_PLAN.md`
- `../ML/README.md`
