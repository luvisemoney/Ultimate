# PaperEA_v2 - DualEA Demo Execution Expert Advisor

## Overview
PaperEA_v2 executes real MT5 orders on demo accounts to validate strategies, ML policy gating, and position/risk logic before promoting changes to LiveEA. It mirrors the execution flow of `../LiveEA/LiveEA.mq5` as closely as possible.

Key traits:
- Real MT5 order execution on demo accounts via `CTradeManager::ExecuteOrder()` (not simulation)
- Policy reload via `DualEA\policy.reload` with HTTP/file polling support
- Telemetry to `Common\Files\DualEA\telemetry\paper_*.jsonl`
- Knowledge base and feature logging to `Common\Files\DualEA\knowledge_base.csv` and `features.csv`
- Policy reload via `DualEA\policy.reload` (LiveEA requires restart for policy changes)

## Architecture
```mermaid
graph TD
    A[Market Data] --> B[Strategy Signals]
    B --> C[ML Policy Gating]
    D -->|ExecuteOrder()| E[Real MT5 Orders (Demo)]

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
- `../PaperEA/PaperEA_v2.mq5` — main EA
- `../LiveEA/LiveEA.mq5` — live EA (parity target)
- `../Include/` — shared utilities (e.g., insights builder, telemetry, KB)
- `../ML/` — Python ML scaffolding (README, `train.py`, `policy_export.py`)

## Configuration Highlights
These inputs exist in `PaperEA_v2.mq5` and govern ML gating and insights behaviour:
- `UsePolicyGating` — enable policy gating (minimal implementation: checks `min_confidence` only)
- `DefaultPolicyFallback` — allow neutral trading when a policy slice is missing
- `FallbackDemoOnly` — restrict fallback behaviour to demo accounts
- `FallbackWhenNoPolicy` — allow trading when `policy.json` is absent
- `PolicyServerUrl` — HTTP endpoint for policy polling (e.g., `http://127.0.0.1:5005`)
- `PolicyHttpPollPercent` — percentage chance to poll HTTP vs file
- `HotReloadIntervalSec` — timer interval for policy reload checks (default 10s)

Note: `InsightsAutoBuild` input exists but auto-rebuild is not currently implemented in `CheckInsightsReload()`; use `Scripts/InsightsRebuild.mq5` to rebuild insights manually.

Signals and timers:
- `OnTick()` drives scan→gate→execute with 23 signal generators
- `OnTimer()` checks `CheckPolicyReload()` and performs HTTP/file polling
- Manual trigger by creating `Common\Files\DualEA\policy.reload`

## Quick Start
1. Attach `PaperEA_v2` to a chart.
2. Ensure file operations are allowed in MT5 (Common tab).
3. Optionally run `Scripts/InsightsRebuild.mq5` to generate `insights.json` from existing data.
4. Drop `DualEA/policy.json` built by `../ML/policy_export.py` into Common Files.
5. Observe telemetry and gating logs in Experts tab and `telemetry/*.jsonl`.

## ML Integration
- Trainer: `../ML/train.py` and `../ML/policy_export.py`
- Reads: `DualEA/features.csv`, `DualEA/knowledge_base.csv`
- Writes: `DualEA/policy.json` with fields: `min_confidence`, slices with `strategy`, `symbol`, `timeframe`, `p_win`, optional `sl_scale`, `tp_scale`, `trail_atr_mult`.

Note: PaperEA_v2's policy parsing is minimal (detects `min_confidence` string); per-slice probability and scaling parsing is not fully implemented. Use LiveEA for full per-slice policy gating.

## Insights Workflow
- Builder lives in `Include/KnowledgeBase.mqh` (`CInsightsBuilder` class)
- Run `Scripts/InsightsRebuild.mq5` manually to rebuild `insights.json` from `features.csv` and `knowledge_base.csv`
- PaperEA_v2's `CheckInsightsReload()` detects `insights.reload` but only deletes it (rebuild logic is commented out)

## Telemetry
- Buffered JSONL written to `Common\Files\DualEA\telemetry` with EA lifecycle, gating decisions, and trade events

## Safety and Parity Notes
- Fallbacks ensure safe demo operation when policy is missing or slices are absent
- Real MT5 order execution (not simulation) via `CTradeManager`
- Timer wiring for policy reload; insights rebuild requires external script

## See Also
- `../LiveEA/LiveEA.mq5`
- `../docs/CORE_IMPLEMENTATION_PLAN.md`
- `../ML/README.md`
