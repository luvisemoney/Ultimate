# Execution Pipeline — DualEA System

**Complete trade execution flow from signal to position**

---

## Pipeline Overview

```
OnTick/OnTimer
    ↓
[1. Early Safety & Filters] ← circuit breaker, memory guard, news filter (PaperEA); risk/spread/session/news/etc (LiveEA)
    ↓ PASS
[2. Strategy Selection] ← selector scoring (PaperEA) or external orchestration (LiveEA)
    ↓ SELECTED
[3. Signal Generation] ← PaperEA: indicator signal generator registry; LiveEA: strategy bridge is available but not called from OnTick
    ↓ SIGNAL
[4. 8-Stage Gates] ← GateManager (PaperEA) / LiveEA early + risk4 gates
    ↓ PASS
[5. Policy & Insights Gating] ← LiveEA: per-slice policy + insights gating + exploration; PaperEA: minimal policy load + min_conf gate
    ↓ PASS
[6. Trade Execution] ← TradeManager.ExecuteOrder() (both EAs)
    ↓ SUCCESS
[7. Post-Execution] ← KB logging, features export, telemetry, learning
```

---

## Stage 1: Signal Generation

**Entry Points:**
- `OnTick()`: Real-time tick processing
- `OnTimer()`: Used today for maintenance and reload polling (PaperEA); LiveEA uses a timer for insights auto-reload polling

**PaperEA_v2 Signal Generation (actual):**
- Strategy selection chooses from a **23-strategy list** (e.g., `ADXStrategy`, `RSIStrategy`, `MACDStrategy`, `IchimokuStrategy`, etc.).
- Signal generation is executed through `Include/StrategySignalGenerators.mqh` via `GenerateSignalFromStrategy()`.
- Output is a `TradingSignal` (from `Include/GateManager.mqh`) with `price`, `sl`, `tp`, `volume`, and `confidence` seeded.

**LiveEA Signal Generation (actual):**
- `LiveEA.mq5` provides the gating and execution pipeline but **does not call the strategy bridge from `OnTick()`**.
- Strategy generation exists as `LiveEA_StrategyBridge.mqh` (21 default `IStrategy` implementations) and can be used by an external orchestrator or future wiring.

**Signal Structure:**
- `strategy_name`, `direction` (1=Buy, -1=Sell)
- `confidence` (0.0-1.0), `entry_price`, `stop_loss`, `take_profit`, `lot_size`
- `reason` (human-readable), `timestamp`
- Strategy-specific indicator values

---

## Stage 2: Early Phase Validation

Quick rejection before expensive gate processing.

**Checks:**
1. **Circuit breakers / risk limits**
2. **News blackout** (Common Files CSV `DualEA\news_blackouts.csv`)
3. **Session/trading hours caps** (where enabled)
4. **Spread and margin checks** (LiveEA)

**NoConstraintsMode**:
- PaperEA default is `true` and bypasses many constraints, but **circuit breaker + memory guard remain enforced**.
- LiveEA default is `false`; when `true`, many gates become **shadow/diagnostic only** (it logs but does not block on early gates).

---

## Stage 3: 8-Stage Gate Processing

Progressive filtering through configurable gates.

**Important reality check:** In `Include/GateManager.mqh`, several gates are currently implemented as simplified/deterministic checks (for repeatable Strategy Tester runs), not a full production-grade market simulation.

### Gate 1: Signal Rinse
- **Purpose**: Basic validation
- **Checks**: `confidence ≥ G1_MinConfidence`, `strength ≥ G1_MinStrength`

### Gate 2: Market Soap
- **Purpose**: Market context
- **Checks**: ATR within `[G2_MinVolatility, G2_MaxVolatility]`, portfolio correlation ≤ `G2_MaxCorrelation`, regime tradeable

### Gate 3: Strategy Scrub
- **Purpose**: Strategy-specific validation
- **Checks**: History bars ≥ `G3_MinHistoryBars`, strategy.ValidateSignal()

### Gate 4: Risk Wash
- **Purpose**: Risk validation
- **Checks**: Risk/trade ≤ `G4_MaxRiskPct`, portfolio risk ≤ `G4_MaxPortfolioRisk`, RR ≥ `G4_MinRiskReward`

### Gate 5: Performance Wax
- **Purpose**: Backtest performance
- **Checks**: Backtest WR ≥ `G5_MinBacktestWinRate`, trades ≥ `G5_MinBacktestTrades`, R ≥ `G5_MinBacktestRMultiple`

### Gate 6: ML Polish
- **Purpose**: ML confidence
- **Checks**: ML confidence ≥ `G6_MinMLConfidence`, ML available if `G6_RequireMLAvailable`

### Gate 7: Live Clean
- **Purpose**: Live market conditions
- **Checks**: Spread, market open, liquidity

### Gate 8: Final Verify
- **Purpose**: Pre-execution validation
- **Checks**: Broker constraints (min/max lots), duplicate signals

**Learning Integration**: Each gate decision recorded via `LearningBridge` for threshold optimization.

---

## Stage 4: Strategy Selection

### StrategySelector Scoring (PaperEA)

```cpp
score = (winRate × W1) + (normRMultiple × W2) + (normSharpe × W3) + (normTrades × W4)
if(SelectorUseRecency) score ×= recencyDecay^daysSinceLastTrade
```

**Weights (actual PaperEA inputs):** `SelW_PF`, `SelW_Exp`, `SelW_WR`, `SelW_DD` with optional recency overlay.

### Insights Gating

Load insights.json slice for `strategy|symbol|timeframe`:

- **No slice found**: Enter exploration mode if enabled
- **Slice exists**: Check `winRate ≥ InsightsMinWinRate`, `totalTrades ≥ InsightsMinTotalTrades`, `avgR ≥ InsightsMinAvgR`

### Exploration Mode

**Triggered when**: No insights slice exists

**Caps (current defaults in code):**
- Daily: `ExploreMaxPerSlicePerDay` (default 100)
- Weekly: `ExploreMaxPerSlice` (default 100)

**Counters**: Persist in `explore_counts.csv` and `explore_counts_day.csv`

**NoConstraintsMode**: Bypasses insights gating and exploration caps entirely.

---

## Stage 5: Policy Application

### Policy Loading

**LiveEA (actual):**
- Loads `DualEA\policy.json` from **Common Files**.
- Parses per-slice fields including `p_win`, and optional scaling keys `sl_scale`, `tp_scale`, `trail_scale`.
- Applies a slice lookup order:
  - Exact `strategy+symbol+timeframe`
  - Aggregate `strategy+symbol` with `timeframe=-1`
  - Aggregate `strategy` with `symbol="*"` and `timeframe=-1`

**PaperEA_v2 (actual):**
- Loads `DualEA\policy.json` from Common Files and treats the policy as “loaded” if it can find the string `min_confidence`.
- `g_policy_min_conf` defaults to `0.5`.
- Per-slice parsing/scaling is **not currently wired** in PaperEA’s `Policy_Load()`.
- HTTP polling exists (see `PolicyServerUrl`, `PolicyHttpPollPercent`) but still only checks for `min_confidence`.

### Policy Gating Logic

```
if policy.slices == 0:
    if FallbackWhenNoPolicy && (FallbackDemoOnly→demo OR !FallbackDemoOnly):
        → FALLBACK: neutral scaling, bypass insights/exploration
    else:
        → BLOCK
        
if slice missing:
    if FallbackWhenSliceMissing && (demo check as above):
        → FALLBACK: neutral scaling
    else:
        → BLOCK
        
if slice.probability < policy.min_confidence:
    → BLOCK
    
else:
    → PASS: Apply scaling
```

### Policy Scaling

**LiveEA (actual):**
- Adjusts SL/TP distance from entry using `sl_scale` / `tp_scale`.
- Adjusts trailing distance using `trail_scale`.

**PaperEA_v2 (current):**
- Policy gating is applied as a **minimum confidence check** (and the scaling path is currently neutral/placeholder in `ApplyPolicyGating()`).

---

## Stage 6: Risk Management

### Position Sizing

**Base Sizing**:
```
pipRisk = |entry - SL| / Point / 10
riskAmount = Balance × (G4_MaxRiskPct / 100)
lots = riskAmount / (pipRisk × tickValue)
lots = NormalizeLots(lots)  // Broker constraints
```

**Correlation Adjustment** (LiveEA with PositionManager):
```
avgCorr = CorrelationManager.GetAverageCorrelation(symbol)
dampening = 1.0 - (avgCorr × 0.5)
adjustedLots = lots × dampening
adjustedLots = max(adjustedLots, max(lots × PM_CorrMinMult, PM_CorrMinLots))
```

### Circuit Breakers

- **Daily Loss**: Block if daily PnL < `-MaxDailyLossPct`
- **Drawdown**: Block if drawdown from peak > `MaxDrawdownPct`
- **Consecutive Losses**: Block after `MaxConsecutiveLosses` losses
- **Cooldown**: After breaker trips, wait `CircuitCooldownSec` seconds

---

## Stage 7: Trade Execution

### TradeManager.Execute()

**PaperEA_v2 (actual):** Places **real MT5 orders on demo accounts** via `CTradeManager::ExecuteOrder()`.

**LiveEA (actual):** Places **real MT5 orders** via `CTradeManager::ExecuteOrder()`.
- Market orders: Immediate execution
- Pending orders: BuyStop, SellStop, BuyLimit, SellLimit
- SL/TP normalization to broker tick size
- Volume normalization (min/max/step)

**Trailing Stops**: Initialized if `TrailEnabled=true`
- Fixed-points: `TrailActivationPoints`, `TrailDistancePoints`, `TrailStepPoints`
- ATR-based: `TrailATRMultiplier × ATR` for distance

---

## Stage 8: Post-Execution

### Knowledge Base Logging

**knowledge_base.csv**:
```
timestamp,symbol,type,entry_price,stop_loss,take_profit,close_price,profit,strategy_id
```

**knowledge_base_events.csv**:
```
timestamp,strategy,retcode,deal,order
```

### Features Export

**features.csv** (long format):
```
timestamp,symbol,timeframe,strategy,direction,confidence,...,indicator_1,indicator_2,...
```
- 50+ features per trade
- Automatic ~100MB rotation (rename to `*.bak`); no compression is performed in MQL5

### Telemetry & Logging

**Telemetry Events**:
- `gate_decision`: Pass/block with reason, latency
- `trade_execution`: Order placement, retcode
- `policy_load`, `insights_rebuild`, `threshold_adjust`
- `risk4_*`: Risk gate events (spread, margin, drawdown)
- `pm_*`: PositionManager events (correlation sizing, scale-ins)
- `p5_*`: Selector events (refresh, rescore, tune)

**UnifiedTradeLogger**: Daily JSON logs with full lifecycle
```json
{
  "timestamp": "2025-01-15T10:30:00Z",
  "strategy": "ADXStrategy",
  "symbol": "EURUSD",
  "timeframe": 60,
  "direction": 1,
  "entry": 1.0850,
  "sl": 1.0800,
  "tp": 1.0950,
  "lots": 0.10,
  "gates": ["signal_rinse:pass", "market_soap:pass", ...],
  "policy": {"confidence": 0.75, "sl_mult": 1.0, "tp_mult": 1.2},
  "outcome": "closed",
  "profit": 15.50,
  "r_multiple": 1.2
}
```

### Learning System Update

**LearningBridge**: Records `CSignalDecision` with:
- All 8 gate decisions (pass/fail, reason, latency)
- Final outcome (executed, blocked, reason)
- Trade result (if executed): profit, R-multiple, duration

**GateLearningSystem**: Updates gate thresholds
- Hybrid learning: immediate (5% rate) + batch (every 20 trades)
- Target success rate per gate configurable
- Adjusts thresholds to optimize pass rate vs trade quality

---

## Live Trading Flow (LiveEA)

**Differences from PaperEA_v2 (as wired today):**
1. **Insights auto-reload loop**: LiveEA requests rebuild by creating `DualEA\insights.reload` and waits for `DualEA\insights.ready`.
2. **Per-slice policy scaling**: LiveEA parses per-slice policy entries and applies SL/TP/trailing scaling.
3. **Risk gates**: LiveEA includes spread/session/margin/consecutive-loss gating in the EA itself.

**Safety Features**:
- Shadow mode possible (log decisions, don't execute)
- Policy fallback with demo-only restriction
- Multiple circuit breakers
- One-execution-per-slice-per-minute de-dup (Phase 6 - planned)

---

## Error Handling

### Broker Errors

**Retcode Handling**:
- `TRADE_RETCODE_DONE`: Success → proceed to post-execution
- `TRADE_RETCODE_REQUOTE`: Retry with new price (max 3 attempts)
- `TRADE_RETCODE_REJECT`: Log + telemetry, don't retry
- `TRADE_RETCODE_NO_MONEY`: Trip circuit breaker, halt trading
- Other errors: Log, telemetry, optional cooldown

### File I/O Errors

**KB Write Failures**:
- Retry with exponential backoff (3 attempts)
- Create directory if missing
- Log to Journal on persistent failure
- Continue execution (non-fatal)

**Policy/Insights Load Failures**:
- Use last-known-good cached version
- Log warning + telemetry event
- Fallback to neutral scaling if allowed
- Reload attempt on next timer cycle

### Learning System Failures

- Non-fatal: Log errors, continue trading
- Disable learning if consecutive failures > 5
- Telemetry event for monitoring

---

## Performance Characteristics

### Latency Targets

- **Signal → Gate entry**: <5ms
- **8-stage gates**: <50ms total (target <10ms per gate)
- **Policy/insights lookup**: <2ms (in-memory cache)
- **KB write**: <10ms (non-blocking preferred)
- **Telemetry emit**: <1ms
- **Total pipeline**: <100ms (OnTick → OrderSend)

### Memory Footprint

- **Strategies (21)**: ~500KB
- **Gate Manager**: ~100KB
- **Policy cache**: ~50KB
- **Insights cache**: ~200KB
- **Telemetry buffer**: ~500KB
- **Total**: ~1.5MB per EA instance

### File I/O

- **KB writes**: Append-only, buffered every 10 trades
- **Features export**: Buffered every 50 trades
- **Telemetry flush**: Every 5 minutes or 1000 events
- **Policy/insights reload**: On timer (every 60 minutes) or .reload trigger

---

**See Also:**
- [Configuration-Reference.md](Configuration-Reference.md) - All input parameters
- [Observability-Guide.md](Observability-Guide.md) - Telemetry and monitoring
- [Policy-Exploration-Guide.md](Policy-Exploration-Guide.md) - Policy fallback and exploration details
