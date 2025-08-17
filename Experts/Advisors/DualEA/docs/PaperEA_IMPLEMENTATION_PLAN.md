# PaperEA Implementation Plan

## 1. Objectives
- Validate strategies and ML gating safely before promotion to LiveEA
- Maintain feature parity with `../LiveEA/LiveEA.mq5` for behavior comparability
- Produce datasets for ML (`DualEA/features.csv`, `DualEA/knowledge_base.csv`) and telemetry for analysis

## 2. Architecture (Parity-First)
- [ ] Event wiring: `OnInit`, `OnTick`, `OnTimer`, `OnDeinit`
- [ ] Policy gating: `UsePolicyGating`, `DefaultPolicyFallback`, `FallbackDemoOnly`, `FallbackWhenNoPolicy`
- [ ] Insights lifecycle: `Insights_IsStale()`, `Insights_RebuildAndReload()`, `CheckInsightsReload()`
- [ ] Policy hot-reload: `CheckPolicyReload()` from `DualEA/policy.reload`
- [ ] ML scaling helpers: `GetPolicyScaleSL/TP/Trail()` and `ApplyPolicyScaling()`
- [ ] Telemetry JSONL: buffered writer under `DualEA/telemetry/`

Mermaid (see `./PaperEA_README.md`)

## 3. ML Filter Integration
- [ ] Consume `DualEA/policy.json` via `Policy_Load()`
- [ ] Apply gating by `GetPolicyProb()` with `g_policy_min_conf`
- [ ] Enable safe fallbacks if policy missing or slice miss
- [ ] Manual reload by `DualEA/policy.reload`

Related files:
- `../PaperEA/PaperEA.mq5`
- `../ML/README.md`, `../ML/policy_builder.py`

## 4. Data and Insights
- [ ] Write `DualEA/features.csv` and `DualEA/knowledge_base.csv`
- [ ] Trigger `Insights_RebuildAndReload()` on timer when stale
- [ ] Manual rebuild via `DualEA/insights.reload` handled by `CheckInsightsReload()`
- [ ] Validate via `Scripts/DualEA/ValidateInsights.mq5`

## 5. Simulation Realism
- [ ] Spread/spike awareness (read spread and reject too-wide)
- [ ] Partial fills/slippage (optional)
- [ ] Session/time filters
- [ ] News filter (optional)

## 6. Dependencies
1. Shared Includes
   - `../Include/` utilities: telemetry, insights builder, KB writer
   - PositionManager (optional future): `../Include/PositionManager.mqh`
2. External
   - Market feed via MT5
   - Python trainer writing `DualEA/policy.json`

## 7. Risk Mitigation
| Risk | Impact | Mitigation |
|------|--------|------------|
| Policy missing/stale | Medium | Fallback knobs, staleness checks, manual reloads |
| Divergence from LiveEA | High | Parity-first changes; mirror `OnTimer()` flow |
| Data inconsistency | Medium | `ValidateInsights.mq5`, logs with sizes/mtimes |
| Performance overhead | Medium | Buffered telemetry, adjustable log levels |

## 8. Tasks & Next Steps
- [ ] Confirm `CheckInsightsReload()` parity (done)
- [ ] Smoke test policy/insights reload flags
- [ ] Run backtests ML ON vs OFF; compare telemetry
- [ ] Review slices coverage in `insights.json` and `policy.json`
- [ ] Document results in `./PaperEA_README.md` and commit presets
