# LiveEA Implementation Plan

## 1. Objectives
- Execute live trades safely using DualEA signals + ML gating
- Maintain behavior parity with `../PaperEA/PaperEA_v2.mq5` (where applicable)
- Provide operational controls for policy/insights reload and robust telemetry

## 2. Architecture
- [ ] Event lifecycle: `OnInit`, `OnTick`, `OnTimer`, `OnDeinit`
- [ ] ML policy gating: always-on, safe fallbacks
- [ ] Insights lifecycle: stale detection + auto-rebuild, manual reload flag
- [ ] Policy hot-reload via `DualEA/policy.reload`
- [ ] Telemetry to `DualEA/telemetry/*.jsonl`
- [ ] (Planned) PositionManager integration behind a feature flag

Mermaid (see `./LiveEA_README.md`).

## 3. ML Filter Integration
- [ ] Load `DualEA/policy.json` in `Policy_Load()`
- [ ] Gate/scaling via `GetPolicyProb()` and `GetPolicyScaleSL/TP/Trail()`
- [ ] Honor inputs: `UsePolicyGating`, `DefaultPolicyFallback`, `FallbackWhenNoPolicy`
- [ ] Manual reload via `CheckPolicyReload()` (reads `DualEA/policy.reload`)

Sources:
- `../LiveEA/LiveEA.mq5`
- `../ML/README.md`, `../ML/policy_builder.py`

## 4. Insights + Data
- [ ] Write `DualEA/knowledge_base.csv` and `DualEA/features.csv`
- [ ] `OnTimer()` checks `Insights_IsStale()` and calls `Insights_RebuildAndReload()`
- [ ] Manual reload via `CheckInsightsReload()` from `DualEA/insights.reload`
- [ ] Validate with `Scripts/DualEA/ValidateInsights.mq5`

## 5. Live Safety
- [ ] Spread guardrails and trading window constraints
- [ ] Exposure caps and per-symbol limits
- [ ] Circuit breakers (daily loss, drawdown)
- [ ] (Optional) News filter and session controls

## 6. Dependencies
1. Shared Includes
   - Insights Builder, Telemetry, KB writer under `../Include/`
   - PositionManager (planned): `../Include/PositionManager.mqh`
2. External
   - MT5 market/broker access
   - Python trainer maintaining `DualEA/policy.json`

## 7. Risk Mitigation
| Risk | Impact | Mitigation |
|------|--------|------------|
| Policy missing/stale | High | Fallbacks, `policy.reload`, stale detection |
| Execution errors | High | Retry policies, error logging, circuit breakers |
| Data drift | Medium | Validate insights and policy coverage |
| Performance overhead | Medium | Bounded telemetry buffers, adjustable log levels |

## 8. Tasks & Next Steps
- [ ] Verify `OnTimer()` wiring for policy + insights reload (parity with PaperEA)
- [ ] Smoke test reload flags in Common Files
- [ ] Backtest with ML ON vs OFF, review telemetry for scaling/blocks
- [ ] (Optional) Add `UsePositionManager` and progressive integration
- [ ] Document operational runbook in `./LiveEA_README.md`
