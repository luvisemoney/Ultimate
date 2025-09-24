# Strategy Unlock Implementation Plan (FX Majors/Minors, Indices, Metals, Energies)

## 1. Strategy Enablement Core Team

### 1.1 Architecture & Foundations (mirror of CORE plan, scope-limited to strategy unlock)
- [ ] Modularize strategy enablement into Include/ with clear boundaries:
  - `Strategies/` families (Breakout, Trend, Mean-Reversion, Volatility)
  - `StrategyRegistry.mqh` (per-symbol/timeframe enablement & metadata)
  - `SymbolRegistry.mqh` (contract metadata, sessions, tick/lot specs, mapping to broker symbols)
  - `StrategyProfiles.mqh` (default params per asset class and timeframe)
  - `GatingProfiles.mqh` (class-specific insights/policy thresholds and exploration caps)
- [ ] Unify feature keys in `KnowledgeBase/` for multi-asset:
  - Mandatory tags: `asset_class`, `symbol`, `timeframe`, `strategy`, `session`, `regime`

### 1.2 Strategy Families & Hypotheses Catalog
- [ ] Breakout/Momentum
  - Donchian ATR Breakout
  - Opening Range Breakout (ORB)
  - Keltner Momentum
- [ ] Trend Following
  - SuperTrend + ADX + KAMA slope
  - MA Crossover variants (fast/slow EMA/SMMA)
- [ ] Mean Reversion
  - RSI(2) + Bollinger Bands
  - VWAP Reversion
- [ ] Volatility Structures
  - Expansion/Contraction filters (ATR percentile bands)
  - Range-state filters (True Range clustering)
- [ ] FX-specific overlays
  - Carry/roll considerations (info-only for now), session bias (London/NY opens)

## 2. Asset-Class Universe & Symbol Onboarding Team

### 2.1 Universe Definition
- [ ] FX Majors: `EURUSD, GBPUSD, USDJPY, USDCHF, USDCAD, AUDUSD, NZDUSD`
- [ ] FX Minors (examples): `EURGBP, EURJPY, GBPJPY, AUDNZD, AUDJPY, CADJPY, CHFJPY`
- [ ] Indices (CFDs): `US500(S&P 500), US30(Dow), NAS100(Nasdaq), GER40(DAX), UK100(FTSE)`
- [ ] Metals: `XAUUSD, XAGUSD`
- [ ] Energies: `WTICOUSD(USOil/WTI), UKOILCOUSD(Brent), NGAS` (exact broker symbols via registry)

### 2.2 Symbol Registry & Contract Specs
- [ ] Create/extend `SymbolRegistry.mqh` to store and serve:
  - Tick size/value, digits, contract size, min/max lot, lot step
  - Stop level & freeze distances, margin mode, currency
  - Market hours (session templates), holidays
- [ ] Add runtime asserts + logs for mismatches vs broker metadata

### 2.3 Session Templates
- [ ] FX 24×5 template with Friday close & Sunday open handling
- [ ] Indices/Energies exchange windows (RTH/ETH) with DST-aware timezones
- [ ] Metals liquidity troughs (Asia overnight) tagging for risk/gating purposes

## 3. Data & Feature Engineering Team

### 3.1 Features (per asset class)
- [ ] Core price/volatility: ATR, KAMA slope, ADX, SuperTrend bands, Donchian, BB, VWAP distance
- [ ] Regime & seasonality: ATR percentile, session of day, day-of-week, month-of-year
- [ ] Cross-asset & correlation: rolling pairwise corr within a class basket (e.g., majors), market beta proxies (indices)
- [ ] Execution context: spread points, tick-to-tick volatility, slippage proxy (tester)

### 3.2 Quality & Coverage
- [ ] Per-slice coverage metric (trades per week/month by `strategy|symbol|tf`)
- [ ] Feature lag/NaN guards per indicator
- [ ] Ensure multi-TF reads have enough bars before signal evaluation

### 3.3 KnowledgeBase Extensions
- [ ] Add columns/tags: `asset_class`, `session_label`, `atr_pctile_bin`, `corr_bucket`
- [ ] Indexing for fast slice scans by asset class and timeframe

## 4. Gating, Selector, and Policy Team

### 4.1 Exploration & Selector Profiles
- [ ] Exploration quotas per class (generous initially in PaperEA):
  - FX Majors: higher quotas (deep liquidity)
  - Minors: moderate quotas
  - Indices/Metals/Energies: conservative quotas to start
- [ ] Strategy selector weights by class:
  - PF-heavy for indices/energies (gap/spike risk)
  - Expectancy + WR balance for FX

### 4.2 Insights & Policy Gating Thresholds
- [ ] Insights minimums (bootstrap low, ramp later): `min_trades, min_wr, min_expR`
- [ ] Policy `min_conf` per class + scaling hints (SL/TP/trail multipliers)
- [ ] Shadow gating in PaperEA when `NoConstraintsMode=true` for telemetry without blockage

### 4.3 Correlation & Position Manager Profiles
- [ ] Per-class correlation prune limits (tighter for indices baskets)
- [ ] PositionManager caps per class (max open per class, per strategy)

## 5. Execution & Risk Team

### 5.1 Execution Profiles
- [ ] Spread/Slippage model per class (tester options):
  - Wider baseline for indices/energies; intraday widening around opens and events
- [ ] Pending order rules validation across classes (min distance vs quote, freeze levels)
- [ ] Weekend gap safety (skip new entries near shutdown, break-even logic disabled before close)

### 5.2 Position Sizing (Volatility & Risk Targets)
- [ ] Calibrate `CVolatilitySizer` per class: ATR period, base ATR %, multiplier bounds
- [ ] Risk targets per class/timeframe (e.g., 0.25–0.5% for indices intraday)
- [ ] Minimum stop distances and guardrails per class

### 5.3 Portfolio Controls
- [ ] Per-class gross/net exposure caps
- [ ] Cross-class correlation surge kill-switch
- [ ] Daily loss and trade count caps per class (SessionManager)

## 6. Backtesting, Validation, and QA Team

### 6.1 Test Matrix
- [ ] Grid of timeframes: `M5, M15, M30, H1, H4, D1` (per family where sensible)
- [ ] Coverage across 3–5 years, include crisis regimes (COVID, inflation spikes), commodity super-cycles
- [ ] Walk-forward evaluation and A/B gating comparisons

### 6.2 Acceptance Criteria (per slice)
- [ ] Stable PF/WR/ExpR across folds and adjacent windows
- [ ] Tail risk audit: max adverse excursion, gap sensitivity, spread shock sensitivity
- [ ] Operational viability: order validity (no zero-lot), SL/TP admissibility, symbol readiness

### 6.3 Fuzzing & Fault Injection
- [ ] Gate toggles fuzzing (session, spread caps, insights, policy)
- [ ] Randomized slippage/spread anomalies
- [ ] Missing policy slices → fallback behavior validation

## 7. Telemetry & Observability Team

### 7.1 Logging & Metrics
- [ ] Mandatory logs: `[SIGNAL]`, `[EXEC]`, `[EXEC_FAIL]`, `[GATE]`, `[RISK4]`
- [ ] Per-class dashboards: attempt rate, success rate, gate reason distribution, spread/ATR context
- [ ] Slice coverage boards: `strategy|symbol|tf` heatmap with explore caps usage

### 7.2 Alerting
- [ ] No-trade slices over N sessions
- [ ] Retcode spikes (e.g., freeze-level or distance violations) per class
- [ ] Equity drawdown and correlation surge alerts

## 8. Rollout & Change Management Team

### 8.1 Phased Unlock (Paper → Live)
- [ ] Wave 1 (Weeks 1–2): FX Majors (M5–H1), low sizing caps, high exploration
- [ ] Wave 2 (Weeks 3–4): FX Minors + Metals (M15–H1), moderate caps
- [ ] Wave 3 (Weeks 5–6): Indices (M5–M30) + Energies (M15–H1), conservative caps
- [ ] Wave 4+: Higher TFs (H4–D1) across classes once policy stable

### 8.2 Safety & Feature Flags
- [ ] Per-class enable flags in inputs; canary on PaperEA only
- [ ] Gradual increase of `ExploreMaxPerSlice`/`PerDay` and position caps
- [ ] Immediate rollback switch and telemetry bookmarks

## Dependencies

1. **KnowledgeBase & ML Artifacts**
   - Feature schema updates (`asset_class`, regime labels)
   - Model retraining with multi-asset data; `policy.json` per slice
2. **Session Calendars & Symbol Registry**
   - Exchange windows and DST rules for indices/energies
   - Broker symbol mapping and contract specs
3. **Execution Modules**
   - `PositionManager.mqh`, `TradeManager.mqh`, `SessionManager.mqh` class-specific profiles

## Risk Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Symbol metadata mismatch | High | Runtime asserts vs broker specs; registry audits |
| Session misalignment/DST | High | TZ-aware calendars; unit tests for windows |
| Spread/slippage underestimation | Medium | Conservative tester presets; sensitivity analysis |
| Correlation spikes | High | Dynamic prune + exposure caps; surge kill-switch |
| Overfit to a class | High | Walk-forward, cross-regime validation, paired baselines |

## Acceptance Criteria (Program-level)
- [ ] ≥70% of targeted slices reach minimum explore coverage in PaperEA within 4 weeks
- [ ] Policy confidence available for ≥60% of active slices; fallback behavior documented for the rest
- [ ] LiveEA rollout shows stable PF/WR/ExpR deltas within tolerance vs PaperEA policy-gated subset
- [ ] No critical execution errors (zero lot, SL/TP invalid, freeze violations) in acceptance runs

## Implementation Epics (Traceable Work Items)

- __EP-01: Symbol Registry & Calendars__
  - [ ] Create `SymbolRegistry.mqh`; populate majors/minors/indices/metals/energies
  - [ ] Add DST-aware session templates and holiday support
- __EP-02: Strategy Profiles__
  - [ ] `StrategyProfiles.mqh` per class: default params, TF scopes, stop/trail presets
- __EP-03: Gating Profiles__
  - [ ] `GatingProfiles.mqh`: insights thresholds, explore caps, selector weights per class
- __EP-04: Selector & Policy__
  - [ ] Per-class selector weighting; policy min_conf matrix and scaling hints
- __EP-05: Telemetry__
  - [ ] Standardize logs/tags; per-class dashboards & alerts
- __EP-06: QA & Bench__
  - [ ] Test matrix automation; acceptance checks; fuzzing suite

## Appendix A: Timeframe Matrix (suggested)

| Asset Class | TFs |
|-------------|-----|
| FX Majors | M5, M15, M30, H1, H4 |
| FX Minors | M15, M30, H1, H4 |
| Indices | M5, M15, M30, H1 |
| Metals | M15, H1, H4 |
| Energies | M15, H1, H4 |

## Appendix B: Example Symbol Map (broker dependent)

- FX Majors: `EURUSD, GBPUSD, USDJPY, USDCHF, USDCAD, AUDUSD, NZDUSD`
- FX Minors: `EURGBP, EURJPY, GBPJPY, AUDNZD, AUDJPY, CADJPY, CHFJPY`
- Indices: `US500, US30, NAS100, GER40, UK100` (broker-specific suffixes possible)
- Metals: `XAUUSD, XAGUSD`
- Energies: `WTICOUSD (USOil/WTI), UKOILCOUSD (Brent), NGAS`
