# Configuration Reference — DualEA System

**Actual input parameters from PaperEA_v2.mq5 and LiveEA.mq5**

> **IMPORTANT:** Previous versions of this document listed aspirational/planned inputs that do not exist in the code. This version documents only the actual `input` declarations found in the source files.

---

## Quick Reference: Key Differences Between EAs

| Feature | PaperEA_v2 | LiveEA |
|---------|-----------|--------|
| **NoConstraintsMode** | default `true` | default `false` |
| **Policy Reload** | Hot-reload via `policy.reload` + HTTP polling | Load on init only (restart required) |
| **Insights Rebuild** | Input exists but not implemented | Requests rebuild via `insights.reload` |
| **Signal Generation** | 23 indicator signal generators | Strategy bridge (not called from OnTick) |
| **Telemetry** | `TelemetryEnabled = true` | `TelemetryEnabled = false` |
| **Exploration Caps** | 100/100 (daily/weekly) | 100/100 (daily/weekly) |

---

## PaperEA_v2 Input Parameters

Located in: `PaperEA/PaperEA_v2.mq5`

### Basic Trading Parameters

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `LotSize` | double | 0.0 | Position size in lots (0 = use VolatilitySizer) |
| `MagicNumber` | int | 12345 | EA identification number |
| `StopLossPips_Input` | double | 150.0 | Initial SL in pips (adaptive) |
| `TakeProfitPips_Input` | double | 300.0 | Initial TP in pips (adaptive) |
| `MaxOpenPositions` | int | 0 | Max concurrent positions (0 = unlimited) |

**Trailing Stop Configuration**
```cpp
input bool     TrailEnabled = true;              // Enable trailing stops
input int      TrailType = 2;                    // 0=fixed points, 2=ATR-based
input int      TrailActivationPoints = 30;       // Profit points before trail activates
input int      TrailDistancePoints = 20;         // Distance from current price
input int      TrailStepPoints = 5;              // Minimum step for SL adjustment
input int      TrailATRPeriod = 14;              // ATR period for dynamic trailing
input double   TrailATRMultiplier = 2.0;         // ATR multiplier for trail distance
```

### Gating System Configuration

**Master Switches**
```cpp
input bool     NoConstraintsMode = true;         // Bypass many gates (circuit/memory/news still enforced)
input bool     UseInsightsGating = true;         // Enable insights-based gating
input int      GateMinTrades = 0;                // Minimum trades required in slice
input double   GateMinWinRate = 0.00;            // Minimum win rate (0 = no minimum)
input double   GateMinExpectancyR = -10.0;       // Minimum expectancy R
input double   GateMaxDrawdownR = 1000000.0;     // Maximum drawdown R
input double   GateMinProfitFactor = 0.00;       // Minimum profit factor
```

**Note:** The 8-stage gate system (`G1_SignalRinse` through `G8_FinalVerify`) described in earlier documentation was aspirational. The actual implementation uses:
- `NoConstraintsMode` to bypass non-critical gates
- `UseInsightsGating` with threshold inputs above
- `UsePolicyGating` for ML policy filtering
- Risk gates (circuit breakers, news filter, regime detection) always enforced

### Insights Gating Configuration

**Thresholds**
```cpp
input double   InsightsMinWinRate = 0.50;        // Minimum win rate to pass insights gate
input int      InsightsMinTotalTrades = 10;      // Minimum trades required in insights
input double   InsightsMinAvgR = 0.3;            // Minimum average R-multiple
input double   InsightsMinSharpe = 0.0;          // Minimum Sharpe ratio (0=disabled)
```

**Freshness & Auto-Reload**
```cpp
input bool     InsightsAutoReload = true;        // Input exists but auto-rebuild NOT IMPLEMENTED
input int      InsightsStaleHours = 48;          // Consider stale after this many hours
input int      InsightsMinSourceAdvanceHours = 48; // Min hours source files must be ahead
input int      InsightsMinIntervalHours = 24;    // Minimum interval between rebuilds
input bool     InsightsCheckOnTimer = true;      // Enable timer-based staleness checks
input int      InsightsRebuildTimeoutMs = 1800000; // Timeout for rebuild (30 min)
```

> **Note:** `InsightsAutoReload` input exists but the actual auto-rebuild logic is commented out in `CheckInsightsReload()`. Use `Scripts/InsightsRebuild.mq5` to manually rebuild insights.

### Exploration Mode Configuration

**Caps & Limits**
```cpp
input int      ExploreMaxPerSlicePerDay = 100;   // Daily exploration cap per slice (default 100)
input int      ExploreMaxPerSlice = 100;         // Weekly exploration cap per slice (default 100)
input bool     ExploreOnNoSlice = true;          // Allow exploration when no slice exists
```

> **Note:** Previous documentation listed defaults of 2/3. Actual code defaults are 100/100 for both daily and weekly caps, effectively unlimited for most practical purposes.

### Policy Gating Configuration

**Fallback Behavior**
```cpp
input bool     DefaultPolicyFallback = true;     // Enable fallback when policy missing
input bool     FallbackDemoOnly = true;          // Restrict fallback to demo accounts only
input bool     FallbackWhenNoPolicy = true;      // Fallback when policy.json not loaded
input bool     FallbackWhenSliceMissing = true;  // Fallback when specific slice missing
```

**Policy Scaling & Hot-Reload**
```cpp
input bool     UsePolicyGating = true;           // Enable policy gating (minimal: checks min_confidence only)
input string   PolicyServerUrl = "";             // HTTP endpoint for policy polling
input int      PolicyHttpPollPercent = 20;       // % chance to poll HTTP vs file
input int      HotReloadIntervalSec = 10;        // Timer interval for reload checks
```

> **Note:** PaperEA_v2 supports policy hot-reload via `policy.reload` file and HTTP polling. LiveEA loads policy on init only (restart required for updates).

### Risk Management Configuration

**Circuit Breakers**
```cpp
input bool     UseCircuitBreakers = true;        // Enable circuit breaker system
input double   CBDailyLossLimitPct_Input = 5.0;  // Max daily loss (% of starting balance)
input double   CBDrawdownLimitPct = 10.0;        // Max drawdown from peak (%)
input int      CBCooldownMinutes = 60;           // Cooldown period after breaker trips
input bool     GuardsEnabled = true;             // Enable trade guards
input double   GuardMaxSpreadPoints = 0.0;       // Max spread in points (0=disabled)
```

**News Filtering**
```cpp
input bool     UseNewsFilter = true;             // Enable news blackout filtering
input int      NewsBufferBeforeMin = 30;         // Minutes before news to stop trading
input int      NewsBufferAfterMin = 30;          // Minutes after news to resume
input int      NewsImpactMin = 2;                // Minimum impact level (1=Low, 2=Med, 3=High)
input bool     NewsUseFile = true;               // Read news from CSV file
input string   NewsFileRelPath = "DualEA\\news_blackouts.csv"; // News events CSV path
```

**Regime Detection**
```cpp
input bool     UseRegimeGate = true;             // Enable market regime detection
input string   RegimeMethod = "combined";        // ATR + ADX method
input int      RegimeATRPeriod = 14;             // ATR period for regime classification
input double   RegimeMinATRPct = 0.5;            // Low volatility threshold
input double   RegimeMaxATRPct = 2.5;            // High volatility threshold
input int      RegimeADXPeriod = 14;             // ADX period for trend strength
input double   RegimeADXTrendThreshold = 25.0;   // ADX trend threshold
input bool     ATRRegimeEnable = false;          // ATR regime filtering
input int      ATRRegimePeriod = 14;             // ATR period
input int      ATRRegimeLookback = 100;          // Lookback for percentile calc
input double   ATRMinPercentile = 0.3;           // Minimum ATR percentile
input double   ATRMaxPercentile = 0.8;           // Maximum ATR percentile
input double   ATRRegimeMinATRPct = 0.5;         // Low volatility threshold
input double   ATRRegimeMaxATRPct = 2.5;         // High volatility threshold
```

**Session Management**
```cpp
input bool     UseSessionManager = true;         // Enable session management
input int      SessionEndHour = 20;              // Session end hour
input bool     UsePromotionGate = false;         // Enable promotion window
input bool     PromoLiveOnly = false;            // Apply only on live accounts
input int      PromoStartHour = 0;               // Promotion window start
input int      PromoEndHour = 24;                // Promotion window end
```

**Correlation Management**
```cpp
input bool     UseCorrelationManager = true;     // Enable correlation-based gating
input double   MaxCorrelationLimit = 0.7;        // Max avg correlation in portfolio
input int      CorrLookbackDays = 30;            // Days for correlation calculation
```

### Strategy Selector Configuration

**Scoring & Selection**
```cpp
input bool     UseStrategySelector = true;       // Enable strategy selector
input double   SelW_PF = 1.0;                    // Weight: profit factor
input double   SelW_Exp = 1.0;                   // Weight: expectancy
input double   SelW_WR = 0.5;                    // Weight: win rate
input double   SelW_DD = 0.3;                    // Weight: drawdown
input bool     SelStrictThresholds = false;      // Use strict vs probabilistic thresholds
input bool     SelUseRecency = true;             // Weight recent performance
input int      SelRecentDays = 14;               // Recent performance lookback
input double   SelRecAlpha = 0.5;                // Recency decay factor
```

> **Note:** Previous documentation listed inputs like `SelectorEnable`, `SelectorMinScore`, `SelectorTopN` which do not exist in the code.

### Knowledge Base Configuration

**File Management**
```cpp
input string   KBBasePath = "DualEA/";           // Base path in Common Files
input bool     KBRotateFiles = true;             // Enable file rotation
input int      KBRotateSizeMB = 100;             // Rotate after N MB
input bool     KBCompressRotated = true;         // Compress rotated files
```

**Logging Options**
```cpp
input bool     KBDebugInit = false;              // Write INIT line to KB on startup
input int      KBInitIntervalSec = 60;           // Interval for INIT writes
```

> **Note:** Knowledge Base is always enabled. Previous inputs like `KBEnable`, `KBLogEvents`, `KBLogFeatures` do not exist as configurable inputs.

### Telemetry & Monitoring Configuration

**Telemetry System**
```cpp
input bool     TelemetryEnabled = true;          // Enable telemetry emission
input bool     TelemetryVerbose = false;         // Verbose telemetry logging
input int      TelemetryFlushInterval = 300;     // Flush interval in seconds
input bool     TelemetryUseCSV = false;          // Use CSV format (vs JSONL)
```

> **Note:** System Monitor and Event Bus are initialized via `ConfigManager` without individual input toggles. Previous inputs like `MonitorEnable`, `EventBusEnable` do not exist.

### Phase 5 Advanced Features

**Auto-Disable / Auto-Reenable**
```cpp
input bool     P5_AutoDisableEnable = true;      // Auto-disable underperforming strategies
input double   P5_MinPF_Input = 1.20;            // Minimum profit factor threshold
input double   P5_MinWR_Input = 0.45;            // Minimum win rate threshold
input double   P5_MinExpR = -0.05;               // Minimum expectancy R
input int      P5_AutoDisableCooldownM = 1440;   // Cooldown minutes before re-enable
input bool     P5_AutoReenable = true;           // Auto-reenable after cooldown
```

**Auto-Tune**
```cpp
input bool     P5_AutoTuneEnable = true;         // Auto-tune strategy parameters
input int      P5_AutoTuneEveryMin = 60;         // Auto-tune interval
```

**Timer Rescore**
```cpp
input bool     P5_TimerRescoreEnable = true;     // Enable periodic rescoring
input int      P5_TimerRescoreEveryMin = 60;     // Rescoring interval
```

**Correlation Pruning**
```cpp
input bool     P5_CorrPruneEnable = true;        // Enable correlation pruning
input double   P5_CorrMax = 0.80;                // Max correlation threshold
input int      P5_CorrLookbackDays = 30;         // Correlation lookback
```

**MTF Confirmation**
```cpp
input bool     P5_MTFConfirmEnable = true;       // Enable MTF confirmation
input string   P5_MTFHigherTFs = "H1,H4";        // Higher timeframe pairs
input int      P5_MTFMinAgree = 1;               // Minimum MTF confirmations
```

**Stability Gate**
```cpp
input bool     P5_StabilityGateEnable = false;   // Enable stability filtering
input int      P5_StabilityWindowDays = 14;      // Stability window
input double   P5_StabilityMaxStdR = 1.00;       // Max std dev R for stability
```

**Other**
```cpp
input bool     P5_PersistLossCounters = false;   // Persist loss counters
input bool     P5_PickBestEnable = false;        // Enable best strategy selection
input int      GateAuditMinSignals = 100;        // Min signals before audit alert
input int      GateAuditMinUptimeMin = 60;       // Min uptime before audit alert
input int      GateAuditAlertCooldownMin = 5;    // Audit alert cooldown
```

> **Note:** Previous inputs for `AdaptiveOptimizerEnable`, `PolicyUpdaterEnable`, `PositionReviewerEnable`, and `GateLearningEnable` were aspirational and do not exist in the code.

### Logging & Debug Configuration

**Debug Flags**
```cpp
input bool     DebugTrailing = false;            // Debug trailing stop operations
input bool     DebugGates = false;               // Debug gate decisions
input bool     DebugStrategies = false;          // Debug strategy signals
input bool     DebugPolicy = false;              // Debug policy loading/application
input bool     DebugInsights = false;            // Debug insights loading
input bool     DebugKB = false;                  // Debug KB writes
```

**Log Levels**
```cpp
input int      LogLevel = 2;                     // 0=None, 1=Error, 2=Warning, 3=Info, 4=Debug
input bool     LogToFile = true;                 // Enable file logging
input bool     LogToJournal = true;              // Enable MT5 Journal logging
```

---

## LiveEA Parameters

Located in: `LiveEA/LiveEA.mq5`

> **IMPORTANT:** LiveEA does NOT inherit PaperEA parameters. It has its own independent input set shown below.

### Core Settings

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `MagicNumber` | long | 123456 | EA identification number |
| `Verbosity` | int | 1 | 0=errors, 1=warn, 2=info, 3=debug |
| `TelemetryEnabled` | bool | **false** | Enable telemetry emission |
| `NoConstraintsMode` | bool | **false** | Shadow-gate only, do not block |

### Telemetry

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `TelemetryExperiment` | string | "live" | Experiment name for telemetry |
| `TelemetryBufferMax` | int | 1000 | Max events before flush |

### Risk Management

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `SpreadMaxPoints` | double | 0.0 | Max spread (0=disabled) |
| `SessionStartHour` | int | 0 | Trading session start |
| `SessionMaxTrades` | int | 0 | Max trades per session |
| `MaxDailyLossPct` | double | 0.0 | Max daily loss % (0=disabled) |
| `MaxDrawdownPct` | double | 0.0 | Max drawdown % (0=disabled) |
| `MinMarginLevel` | double | 0.0 | Min margin % (0=disabled) |
| `ConsecutiveLossLimit` | int | 0 | Max consecutive losses |

### Insights Gating (same threshold names as PaperEA)

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `UseInsightsGating` | bool | true | Enable insights gating |
| `GateMinTrades` | int | 0 | Min trades in slice |
| `GateMinWinRate` | double | 0.00 | Min win rate |
| `GateMinExpectancyR` | double | -10.0 | Min expectancy R |
| `GateMaxDrawdownR` | double | 1000000.0 | Max drawdown R |
| `GateMinProfitFactor` | double | 0.00 | Min profit factor |

### Exploration

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `ExploreOnNoSlice` | bool | true | Allow exploration when no slice |
| `ExploreMaxPerSlice` | int | **100** | Weekly cap |
| `ExploreMaxPerSlicePerDay` | int | **100** | Daily cap |

### Policy Gating

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `UsePolicyGating` | bool | true | Enable policy gating |
| `DefaultPolicyFallback` | bool | true | Allow neutral when slice missing |
| `FallbackDemoOnly` | bool | true | Restrict fallback to demo |
| `FallbackWhenNoPolicy` | bool | true | Allow when policy absent |

> **Note:** LiveEA loads policy on `OnInit()` only. Restart required for policy updates (no hot-reload).

### Auto-Reload Controls

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `InsightsAutoReload` | bool | true | Request rebuild when stale |
| `InsightsLiveFreshMinutes` | int | 10 | Consider fresh if < N min old |
| `InsightsReadyPollSec` | int | 5 | Poll frequency for ready signal |

### News / Promotion / Regime

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `UseNewsFilter` | bool | false | Block around news windows |
| `NewsBufferBeforeMin` | int | 30 | Minutes before event |
| `NewsBufferAfterMin` | int | 30 | Minutes after event |
| `NewsImpactMin` | int | 2 | Min impact level |
| `NewsUseFile` | bool | true | Read from CSV |
| `NewsFileRelPath` | string | "DualEA\\news_blackouts.csv" | CSV path |
| `UsePromotionGate` | bool | false | Allow only in windows |
| `PromoLiveOnly` | bool | false | Apply only on live |
| `PromoStartHour` | int | 0 | Window start |
| `PromoEndHour` | int | 24 | Window end |
| `UseRegimeGate` | bool | false | Filter by volatility |
| `RegimeATRPeriod` | int | 14 | ATR period |
| `RegimeMinATRPct` | double | 0.0 | 0=disabled |
| `RegimeMaxATRPct` | double | 1000.0 | 1000=disabled |
| `CircuitCooldownSec` | int | 0 | Cooldown (0=disabled) |

### Session & Correlation

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `UseSessionManager` | bool | true | Enable session controls |
| `SessionEndHour` | int | 20 | Session end hour |
| `MaxTradesPerSession` | int | 10 | Max trades |
| `UseCorrelationManager` | bool | true | Enable correlation checks |
| `MaxCorrelationLimit` | double | 0.7 | Max correlation |
| `CorrLookbackDays` | int | 30 | Lookback period |
| `P5_CorrMax` | double | 1.0 | 1.0=no pruning |
| `P5_CorrLookbackDays` | int | 5 | Lookback if PM unavailable |

### Position & Volatility

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `PMMaxOpenPositions` | int | 10 | Max open positions |
| `UsePositionManager` | bool | false | Enable PositionManager |
| `UseVolatilitySizer` | bool | false | ATR-based sizing |
| `VolSizerATRPeriod` | int | 14 | ATR period |
| `VolSizerBaseATRPct` | double | 1.0 | Base ATR % |
| `VolSizerMinMult` | double | 0.1 | Min lot multiplier |

---

## Configuration Patterns

### Pattern 1: Maximum Data Collection (PaperEA)

For initial data gathering phase:

```cpp
input bool     NoConstraintsMode = true;         // Bypass non-critical gates
input int      MaxOpenPositions = 0;             // Unlimited positions
input bool     UseInsightsGating = false;        // Disable insights gating
input int      ExploreMaxPerSlicePerDay = 100;   // High exploration cap
input int      ExploreMaxPerSlice = 100;         // High weekly cap

// Still collect data
input bool     TelemetryEnabled = true;
input bool     TelemetryVerbose = true;
```

### Pattern 2: Cautious Demo Trading

For demo trading with realistic constraints:

```cpp
input bool     NoConstraintsMode = false;        // Enable gates
input int      MaxOpenPositions = 5;             // Reasonable limit
input bool     UseInsightsGating = true;
input double   GateMinWinRate = 0.50;
input int      GateMinTrades = 10;
input int      ExploreMaxPerSlicePerDay = 10;
input int      ExploreMaxPerSlice = 20;

// Conservative risk
input double   CBDailyLossLimitPct_Input = 3.0;
```

### Pattern 3: Live Trading (Conservative)

For initial live deployment (using LiveEA):

```cpp
// LiveEA inputs
input bool     NoConstraintsMode = false;        // All gates active
input int      PMMaxOpenPositions = 3;           // Very limited
input bool     UseInsightsGating = true;
input double   GateMinWinRate = 0.55;            // Stricter than paper
input int      GateMinTrades = 30;               // More data required
input bool     UsePolicyGating = true;

// Strict risk controls
input double   MaxDailyLossPct = 2.0;
input double   MaxDrawdownPct = 10.0;
input double   MinMarginLevel = 200.0;
```

### Pattern 4: ML Training Focus

Optimize for ML training data quality:

```cpp
input bool     NoConstraintsMode = true;         // Max coverage
input bool     TelemetryEnabled = true;
input bool     TelemetryVerbose = true;          // Capture all details

// Diverse strategy exposure
input bool     UseStrategySelector = true;

// Policy fallback for coverage
input bool     UsePolicyGating = true;
input bool     DefaultPolicyFallback = true;
input bool     FallbackDemoOnly = false;         // Allow everywhere for data
```

---

## Gate Configuration

### Actual Gate Implementation

The DualEA system uses a simplified gate architecture compared to the aspirational 8-stage pipeline documented earlier:

**Always-Enforced Gates (not bypassed by NoConstraintsMode):**
- Circuit breaker checks (`UseCircuitBreakers`)
- Memory limit validation
- News filter (`UseNewsFilter`)

**Optional Gates (bypassed when `NoConstraintsMode=true`):**
- Insights gating (`UseInsightsGating` with threshold inputs)
- Policy gating (`UsePolicyGating`)
- Session management (`UseSessionManager`)
- Correlation management (`UseCorrelationManager`)
- Regime detection (`UseRegimeGate`)

### Shadow Mode for Testing

Test gate decisions without blocking trades:

```cpp
input bool     NoConstraintsMode = true;         // Enable shadow mode
input bool     TelemetryVerbose = true;          // Capture shadow decisions

// Gates still evaluate but don't block
// Check telemetry for shadow gating events
```

---

## Best Practices

### 1. Start with NoConstraintsMode

Begin with unrestricted data collection:
- Set `NoConstraintsMode=true`
- Run for 2-4 weeks across multiple symbols/timeframes
- Generate comprehensive insights.json

### 2. Gradually Enable Gates

After data collection:
- Set `NoConstraintsMode=false`
- Enable gates one by one
- Monitor impact on trade count and quality

### 3. Use Exploration Wisely

Balance exploration vs exploitation:
- Start with higher caps (5/10) in paper
- Reduce caps as insights mature
- In live, use minimal caps (1/2)

### 4. Test in Strategy Tester First

Before live deployment:
- Run backtests with realistic spread/slippage
- Validate gate behavior with actual constraints
- Check exploration counter persistence

### 5. Monitor Health Scores

Track SystemMonitor health:
- Aim for >80 health score
- Investigate if dropping below 70
- Check gate success rates individually

### 6. Policy Fallback Strategy

For production live trading:
- Set `FallbackDemoOnly=true` initially
- Only disable after validating policy coverage
- Keep `DefaultPolicyFallback=true` as safety net

### 7. Risk Ladder Approach

Gradually increase risk exposure:
1. Start: 0.5% risk per trade, 2% daily loss cap
2. After 50 trades: 1.0% risk, 3% daily cap
3. After 200 trades: 1.5% risk, 5% daily cap
4. Review and adjust based on performance

---

## Configuration Checklist

### Before Going Live

- [ ] `NoConstraintsMode=false` (gates active)
- [ ] Insights gating thresholds validated
- [ ] Policy loaded and coverage checked
- [ ] Exploration caps set conservatively (1-2)
- [ ] Risk limits appropriate for account size
- [ ] Circuit breakers configured
- [ ] News calendar updated
- [ ] Position Manager tested
- [ ] Telemetry and logging working
- [ ] Strategy Tester validation completed
- [ ] Demo account forward test successful (minimum 2 weeks)

---

## P0-P5 Advanced Hardening Inputs

**Location**: `Include/PaperEA_v2_P0P5_Integration.mqh`

All P0-P5 features can be enabled/disabled via input parameters for gradual rollout.

### P0 - Production Risk Controls
```cpp
input bool     InpEnableNuclearRiskEngine = true;         // Enable VaR/Kelly/CVaR risk engine
input bool     InpEnableSQLiteKB = true;                  // Enable SQLite parallel KB
input int      InpSQLiteMigrationDays = 30;               // CSV migration period
input bool     InpEnableShadowLogging = true;             // Atomic CSV writes with checksums
input double   InpMaxPortfolioRiskPct = 15.0;             // Max portfolio risk %
input double   InpMaxCorrelationForPruning = 0.70;        // Correlation threshold for strategy pruning
```

### P1 - Architectural Hardening
```cpp
input bool     InpEnableFeatureCache = true;                // Pre-warmed indicator handles
input bool     InpEnableSystemMonitor = true;               // CPU/memory monitoring
input bool     InpEnableVolatilityExits = true;               // Trailing volatility exits
input int      InpFeatureCacheSize = 100;                 // Cache size per indicator
```

### P2 - Intelligence Enhancements
```cpp
input bool     InpEnableConceptDriftDetection = true;      // Auto-adjust gate thresholds
input bool     InpEnableAutoDriftAdjustment = true;         // Welford's algorithm adjustment
input double   InpDriftZScoreThreshold = 2.5;              // Drift detection threshold
input bool     InpEnableAutoPromotionSystem = true;        // Paper to Live promotion
input bool     InpEnableShadowTradingBridge = true;         // Parallel demo execution
input bool     InpEnableMTFConfirmationGate = true;          // Multi-timeframe confirmation
input bool     InpEnableCorrelationPruner = true;            // Correlation-aware pruning
input int      InpMTFConfirmationTimeframes = 2;             // Number of TF confirmations required
```

### P3 - Performance Optimizations
```cpp
input bool     InpEnableCPUBudgeting = true;                // CPU fail-fast processing
input int      InpCPUBudgetMsPerTick = 10;                  // Max CPU ms per tick
input bool     InpEnableIndicatorCache = true;              // Pre-warm indicator handles
input bool     InpEnableRingBuffers = true;                 // Lock-free logging
input bool     InpEnableBatchTelemetry = true;              // Batched I/O writes
input int      InpRingBufferSize = 8192;                    // Ring buffer capacity
input int      InpTelemetryBatchSize = 100;                   // Batch write size
input bool     InpEnableTimerStrategyScanner = true;           // Timer-based scanning
input int      InpStrategyScanIntervalSec = 60;              // Scan interval
```

### P4 - Strategic Evolution
```cpp
input bool     InpEnableGrpcMLBridge = false;               // gRPC ML inference (disabled by default)
input string   InpGrpcServerAddress = "localhost:50051";   // gRPC server
input bool     InpEnableAdversarialFuzzer = false;          // Jailbreak testing (debug only)
input bool     InpEnableFeatureDriftDetector = true;        // Distribution shift detection
```

### Cross-Chart Coordination
```cpp
input bool     InpEnableSymbolCoordinator = false;          // Redis coordination (disabled by default)
input string   InpRedisServerAddress = "localhost:6379";   // Redis server
input int      InpMaxPositionsPerSymbol = 5;                // Per-symbol position cap
```

**Key Design Decisions**:
- Risk gates (G1, G4, G7, G8) are never skipped under CPU pressure
- Multi-symbol management remains chart-per-symbol with Redis coordination
- SQLite runs parallel to CSV for 30-day migration period
- gRPC ML Bridge disabled by default (local ONNX preferred)
- Redis coordination disabled by default (single-chart mode)

---

**See Also:**
- [Execution-Pipeline.md](Execution-Pipeline.md) - Detailed execution flow
- [Observability-Guide.md](Observability-Guide.md) - Monitoring and telemetry
- [Policy-Exploration-Guide.md](Policy-Exploration-Guide.md) - Policy and exploration details
