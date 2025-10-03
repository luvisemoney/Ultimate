# Configuration Reference — DualEA System

**Complete guide to all 180+ input parameters**

---

## Table of Contents

1. [PaperEA_v2 Parameters](#paperea_v2-parameters)
2. [LiveEA Parameters](#liveea-parameters)
3. [Configuration Patterns](#configuration-patterns)
4. [Gate Configuration](#gate-configuration)
5. [Best Practices](#best-practices)

---

## PaperEA_v2 Parameters

### Basic Trading Parameters

**Position & Risk**
```cpp
input double   LotSize = 0.1;                    // Base position size in lots
input int      MagicNumber = 20250101;           // EA identification number (unique per instance)
input double   StopLossPips = 50.0;              // Default stop loss in pips
input double   TakeProfitPips = 100.0;           // Default take profit in pips
input int      MaxOpenPositions = 0;             // Max concurrent positions (0=unlimited)
```

**Trailing Stop Configuration**
```cpp
input bool     TrailEnabled = true;              // Enable trailing stops
input int      TrailType = 0;                    // 0=Fixed points, 1=ATR-based
input int      TrailActivationPoints = 100;      // Profit points before trail activates
input int      TrailDistancePoints = 50;         // Distance from current price in points
input int      TrailStepPoints = 10;             // Minimum step size for SL adjustment
input double   TrailATRPeriod = 14;              // ATR period for ATR-based trailing (TrailType=1)
input double   TrailATRMultiplier = 2.0;         // ATR multiplier for trail distance
```

### Gating System Configuration

**Master Switches**
```cpp
input bool     NoConstraintsMode = true;         // BYPASS ALL GATES for maximum data collection
input bool     UseInsightsGating = true;         // Enable insights-based gating
input bool     UseExploration = true;            // Enable exploration mode for new slices
input bool     UsePolicyGating = false;          // Enable ML policy gating
input bool     UseUnifiedSystem = true;          // Use ConfigManager/EventBus/SystemMonitor
```

**Gate 1: Signal Rinse**
```cpp
input bool     G1_SignalRinseEnable = true;      // Enable signal rinse gate
input double   G1_MinConfidence = 0.6;           // Minimum signal confidence (0.0-1.0)
input double   G1_MinStrength = 0.5;             // Minimum signal strength
```

**Gate 2: Market Soap**
```cpp
input bool     G2_MarketSoapEnable = true;       // Enable market analysis gate
input double   G2_MinVolatility = 0.0001;        // Minimum ATR in decimal (0=no minimum)
input double   G2_MaxVolatility = 0.01;          // Maximum ATR (0=no maximum)
input double   G2_MaxCorrelation = 0.8;          // Maximum portfolio correlation (-1 to 1)
```

**Gate 3: Strategy Scrub**
```cpp
input bool     G3_StrategyScrubEnable = true;    // Enable strategy validation gate
input double   G3_MinScore = 0.5;                // Minimum strategy score from selector
input int      G3_MinHistoryBars = 100;          // Minimum bars required for strategy
```

**Gate 4: Risk Wash**
```cpp
input bool     G4_RiskWashEnable = true;         // Enable risk validation gate
input double   G4_MaxRiskPct = 2.0;              // Maximum risk per trade (% of balance)
input double   G4_MaxPortfolioRisk = 10.0;       // Maximum total portfolio risk (%)
input double   G4_MinRiskReward = 1.5;           // Minimum risk:reward ratio
```

**Gate 5: Performance Wax**
```cpp
input bool     G5_PerformanceWaxEnable = true;   // Enable performance validation gate
input double   G5_MinBacktestWinRate = 0.45;     // Minimum backtest win rate
input double   G5_MinBacktestRMultiple = 0.5;    // Minimum avg R-multiple from backtest
input int      G5_MinBacktestTrades = 30;        // Minimum backtest sample size
```

**Gate 6: ML Polish**
```cpp
input bool     G6_MLPolishEnable = true;         // Enable ML confidence gate
input double   G6_MinMLConfidence = 0.55;        // Minimum ML model confidence
input bool     G6_RequireMLAvailable = false;    // Block if ML model unavailable
```

**Gate 7: Live Clean**
```cpp
input bool     G7_LiveCleanEnable = true;        // Enable live market validation gate
input double   G7_MaxSpreadPips = 3.0;           // Maximum spread in pips
input bool     G7_CheckMarketHours = true;       // Validate trading hours
input bool     G7_CheckLiquidity = true;         // Check market liquidity
```

**Gate 8: Final Verify**
```cpp
input bool     G8_FinalVerifyEnable = true;      // Enable final verification gate
input bool     G8_VerifyBrokerConstraints = true;// Check broker lot/margin limits
input bool     G8_VerifyDuplicates = true;       // Check for duplicate signals
input int      G8_DuplicateWindowSeconds = 60;   // Deduplication window in seconds
```

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
input bool     InsightsAutoReload = true;        // Auto-reload insights.json periodically
input int      InsightsReloadMinutes = 60;       // Reload interval in minutes
input int      InsightsLiveFreshMinutes = 30;    // Freshness for live trading (warn if older)
input int      InsightsStaleHours = 24;          // Consider stale after this many hours
```

### Exploration Mode Configuration

**Caps & Limits**
```cpp
input int      ExploreMaxPerSlicePerDay = 2;     // Daily exploration cap per slice (0=unlimited)
input int      ExploreMaxPerSlice = 3;           // Weekly exploration cap per slice (0=unlimited)
input bool     ExploreResetOnMonday = true;      // Reset weekly counter on Monday
```

**Behavior**
```cpp
input bool     ExploreBypassInsights = true;     // Bypass insights thresholds in explore mode
input bool     ExploreLogVerbose = true;         // Verbose logging for exploration events
```

### Policy Gating Configuration

**Fallback Behavior**
```cpp
input bool     DefaultPolicyFallback = true;     // Enable fallback when policy missing
input bool     FallbackDemoOnly = true;          // Restrict fallback to demo accounts only
input bool     FallbackWhenNoPolicy = true;      // Fallback when policy.json not loaded
input bool     FallbackWhenSliceMissing = true;  // Fallback when specific slice missing
```

**Policy Scaling**
```cpp
input double   PolicySLMultiplier = 1.0;         // SL scaling multiplier (from policy)
input double   PolicyTPMultiplier = 1.0;         // TP scaling multiplier (from policy)
input double   PolicyTrailMultiplier = 1.0;      // Trailing stop scaling multiplier
input double   PolicyLotMultiplier = 1.0;        // Lot size scaling multiplier
```

**Hot-Reload (Planned)**
```cpp
input bool     PolicyHotReload = false;          // Enable policy hot-reload (planned)
input int      PolicyReloadCheckSeconds = 60;    // Check for .reload file every N seconds
```

### Risk Management Configuration

**Circuit Breakers**
```cpp
input bool     CircuitBreakerEnable = true;      // Enable circuit breaker system
input double   MaxDailyLossPct = 5.0;            // Max daily loss (% of starting balance)
input double   MaxDrawdownPct = 15.0;            // Max drawdown from peak (%)
input int      CircuitCooldownSec = 3600;        // Cooldown period after breaker trips (seconds)
input int      MaxConsecutiveLosses = 5;         // Max consecutive losing trades
```

**News Filtering**
```cpp
input bool     UseNewsFilter = true;             // Enable news blackout filtering
input string   NewsCSVPath = "DualEA/news_calendar.csv"; // News events CSV path
input int      NewsBufferBeforeMin = 30;         // Minutes before news to stop trading
input int      NewsBufferAfterMin = 15;          // Minutes after news to resume
input int      NewsImpactMin = 2;                // Minimum impact level (1=Low, 2=Med, 3=High)
input bool     NewsDetectCurrency = true;        // Auto-detect symbol currency for news
```

**Regime Detection**
```cpp
input bool     UseRegimeGate = true;             // Enable market regime detection
input int      RegimeATRPeriod = 20;             // ATR period for regime classification
input double   RegimeMinATRPct = 0.5;            // Minimum ATR percentile (0-1)
input double   RegimeMaxATRPct = 0.95;           // Maximum ATR percentile
input int      RegimeADXPeriod = 14;             // ADX period for trend strength
input double   RegimeMinADX = 20.0;              // Minimum ADX for trending regime
input int      RegimeRSIPeriod = 14;             // RSI period for momentum
```

**Session Management**
```cpp
input bool     UseSessionGate = true;            // Enable session-based gating
input string   SessionStartTime = "09:00";       // Trading session start (HH:MM)
input string   SessionEndTime = "17:00";         // Trading session end (HH:MM)
input int      SessionMaxTrades = 10;            // Max trades per session (0=unlimited)
input bool     SessionResetDaily = true;         // Reset session counters daily
```

**Correlation Management**
```cpp
input bool     UseCorrelationGate = true;        // Enable correlation-based gating
input double   MaxPortfolioCorrelation = 0.75;   // Max avg correlation in portfolio
input int      CorrelationLookback = 100;        // Bars for correlation calculation
input bool     CorrelationUsePearson = true;     // Use Pearson correlation (vs simple)
```

### Strategy Selector Configuration

**Scoring & Selection**
```cpp
input bool     SelectorEnable = true;            // Enable strategy selector
input double   SelectorMinScore = 0.5;           // Minimum score to consider strategy
input int      SelectorTopN = 5;                 // Select top N strategies per signal
input bool     SelectorUseRecency = true;        // Apply recency weighting to scores
input double   SelectorRecencyDecay = 0.95;      // Recency decay factor (0-1)
input int      SelectorRecencyDays = 30;         // Days to consider for recency
```

**Performance Weighting**
```cpp
input double   SelectorWinRateWeight = 0.3;      // Weight for win rate in scoring
input double   SelectorRMultipleWeight = 0.4;    // Weight for R-multiple in scoring
input double   SelectorSharpeWeight = 0.2;       // Weight for Sharpe ratio in scoring
input double   SelectorTradeCountWeight = 0.1;   // Weight for sample size in scoring
```

### Knowledge Base Configuration

**File Management**
```cpp
input bool     KBEnable = true;                  // Enable Knowledge Base logging
input string   KBBasePath = "DualEA/";           // Base path in Common Files
input bool     KBRotateFiles = true;             // Enable file rotation
input int      KBRotateSizeMB = 100;             // Rotate after N MB (features.csv)
input bool     KBCompressRotated = true;         // Compress rotated files
```

**Logging Options**
```cpp
input bool     KBDebugInit = false;              // Write INIT line to KB on startup
input bool     KBLogEvents = true;               // Log trade events to KB
input bool     KBLogFeatures = true;             // Export features for ML training
input bool     KBLogTelemetry = true;            // Export telemetry data
```

### Telemetry & Monitoring Configuration

**Telemetry System**
```cpp
input bool     TelemetryEnable = true;           // Enable telemetry system
input bool     TelemetryVerbose = false;         // Verbose telemetry logging
input bool     TelemetryStandard = true;         // Use TelemetryStandard wrapper
input int      TelemetryFlushSeconds = 300;      // Flush telemetry every N seconds
```

**System Monitor**
```cpp
input bool     MonitorEnable = true;             // Enable SystemMonitor
input int      MonitorUpdateSeconds = 60;        // Update health score every N seconds
input double   MonitorHealthThreshold = 70.0;    // Minimum health score (0-100)
input bool     MonitorAlertOnDegradation = true; // Alert when health degrades
```

**Event Bus**
```cpp
input bool     EventBusEnable = true;            // Enable EventBus
input int      EventBusPriority = 2;             // Min priority to log (0=all, 1=low, 2=med, 3=high, 4=critical)
input int      EventBusMaxQueueSize = 1000;      // Max events in queue
```

### Advanced Optimization Configuration

**AdaptiveSignalOptimizer**
```cpp
input bool     AdaptiveOptimizerEnable = true;   // Enable adaptive signal optimization
input double   AdaptiveMinImprovement = 0.05;    // Minimum improvement to adjust (5%)
input int      AdaptiveWindowTrades = 50;        // Rolling window size for optimization
```

**PolicyUpdater**
```cpp
input bool     PolicyUpdaterEnable = true;       // Enable automatic policy updates
input int      PolicyUpdateMinutes = 60;         // Update policy every N minutes
input int      PolicyUpdateMinTrades = 100;      // Minimum trades required for update
```

**PositionReviewer**
```cpp
input bool     PositionReviewerEnable = true;    // Enable position review system
input int      PositionReviewMinutes = 5;        // Review positions every N minutes
input bool     PositionReviewAdjustSL = true;    // Allow SL adjustments
input bool     PositionReviewAdjustTP = false;   // Allow TP adjustments
```

**GateLearningSystem**
```cpp
input bool     GateLearningEnable = true;        // Enable gate learning system
input double   GateLearningRate = 0.05;          // Learning rate (0-1)
input int      GateLearningBatchSize = 20;       // Batch size for updates
input bool     GateLearningImmediate = true;     // Enable immediate learning updates
```

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

LiveEA inherits all PaperEA parameters plus the following:

### Live-Specific Risk Controls

**Stricter Gating**
```cpp
input double   LiveInsightsMinWinRate = 0.55;    // Higher win rate requirement (vs 0.50 in Paper)
input int      LiveInsightsMinTotalTrades = 30;  // More trades required (vs 10 in Paper)
input double   LiveInsightsMinAvgR = 0.5;        // Higher R-multiple (vs 0.3 in Paper)
```

**Spread Controls**
```cpp
input double   LiveMaxSpreadPips = 2.0;          // Stricter spread limit (vs 3.0 in Paper)
input bool     LiveRejectOnSpreadSpike = true;   // Reject if spread suddenly widens
input double   LiveSpreadSpikeMultiplier = 2.0;  // Spike = N × normal spread
```

**Daily Limits**
```cpp
input double   LiveMaxDailyLossPct = 3.0;        // Stricter daily loss limit (vs 5.0 in Paper)
input int      LiveMaxDailyTrades = 20;          // Max trades per day
input double   LiveMaxDailyVolume = 5.0;         // Max total volume per day (lots)
```

**Margin & Drawdown**
```cpp
input double   LiveMinMarginLevel = 200.0;       // Minimum margin level (%)
input double   LiveMaxDrawdownPct = 10.0;        // Stricter drawdown limit (vs 15.0 in Paper)
input bool     LiveStopOnMarginCall = true;      // Stop trading if margin < threshold
```

**Consecutive Loss Protection**
```cpp
input int      LiveMaxConsecutiveLosses = 3;     // Stricter consecutive loss limit (vs 5 in Paper)
input int      LiveConsecutiveLossCooldown = 7200; // Longer cooldown (2 hours vs 1 hour)
```

### Position Manager Integration

**Core Settings**
```cpp
input bool     UsePositionManager = true;        // Enable PositionManager
input int      PM_ScalingProfile = 1;            // 0=Aggressive, 1=Moderate, 2=Conservative
```

**Correlation Sizing**
```cpp
input bool     PM_EnableCorrelationSizing = true;    // Enable correlation-adjusted sizing
input double   PM_CorrMinMult = 0.25;                // Min multiplier after correlation dampening
input double   PM_CorrMinLots = 0.01;                // Absolute minimum lots floor
input double   PM_CorrMaxPortfolio = 0.75;           // Max portfolio correlation
```

**Adaptive Sizing**
```cpp
input bool     PM_EnableAdaptiveSizing = true;   // Enable performance-based sizing
input double   PM_MinSizeMult = 0.5;             // Minimum size multiplier
input double   PM_MaxSizeMult = 2.0;             // Maximum size multiplier
input int      PM_AdaptiveWindowTrades = 20;     // Rolling window for adaptive calc
```

**Dynamic Risk Caps**
```cpp
input bool     PM_EnableDynamicRiskCaps = true;  // Enable dynamic risk management
input double   PM_MaxDailyDDPct = 2.0;           // Max daily drawdown (%)
input double   PM_MaxPosRiskPct = 1.5;           // Max risk per position (%)
input double   PM_MaxPortfolioRiskPct = 8.0;     // Max total portfolio risk (%)
input double   PM_RiskDecay = 0.9;               // Risk cap decay factor after loss
```

**Volatility Exit**
```cpp
input bool     PM_EnableVolatilityExit = true;   // Enable volatility-based exits
input double   PM_VolatilityExitATRMult = 3.0;   // Exit if ATR > N × normal
input int      PM_VolatilityExitPeriod = 20;     // ATR period for volatility exit
```

### Exploration Mode (LiveEA)

**Stricter Caps**
```cpp
input int      LiveExploreMaxPerSlicePerDay = 1; // More conservative (vs 2 in Paper)
input int      LiveExploreMaxPerSlice = 2;       // More conservative (vs 3 in Paper)
```

---

## Configuration Patterns

### Pattern 1: Maximum Data Collection (PaperEA)

For initial data gathering phase:

```cpp
input bool     NoConstraintsMode = true;         // BYPASS ALL GATES
input int      MaxOpenPositions = 0;             // Unlimited positions
input bool     UseInsightsGating = false;        // Disable insights gating
input bool     UseExploration = false;           // Not needed with NoConstraints
input int      ExploreMaxPerSlicePerDay = 0;     // Unlimited if exploration enabled
input int      ExploreMaxPerSlice = 0;           // Unlimited

// Still collect data
input bool     KBEnable = true;
input bool     KBLogFeatures = true;
input bool     TelemetryEnable = true;
```

### Pattern 2: Cautious Paper Trading

For paper trading with realistic constraints:

```cpp
input bool     NoConstraintsMode = false;        // Enable all gates
input int      MaxOpenPositions = 5;             // Reasonable limit
input bool     UseInsightsGating = true;
input double   InsightsMinWinRate = 0.50;
input int      InsightsMinTotalTrades = 10;
input bool     UseExploration = true;
input int      ExploreMaxPerSlicePerDay = 2;
input int      ExploreMaxPerSlice = 3;

// Conservative risk
input double   MaxDailyLossPct = 3.0;
input int      MaxConsecutiveLosses = 3;
```

### Pattern 3: Live Trading (Conservative)

For initial live deployment:

```cpp
input bool     NoConstraintsMode = false;        // All gates active
input int      MaxOpenPositions = 3;             // Very limited
input bool     UseInsightsGating = true;
input double   LiveInsightsMinWinRate = 0.60;    // Stricter than paper
input int      LiveInsightsMinTotalTrades = 50;  // More data required
input bool     UsePolicyGating = true;
input double   G6_MinMLConfidence = 0.65;        // High ML confidence required

// Strict risk controls
input double   LiveMaxDailyLossPct = 2.0;
input int      LiveMaxConsecutiveLosses = 2;
input double   LiveMinMarginLevel = 300.0;
input bool     UsePositionManager = true;
input int      PM_ScalingProfile = 2;            // Conservative
```

### Pattern 4: ML Training Focus

Optimize for ML training data quality:

```cpp
input bool     NoConstraintsMode = true;         // Max coverage
input bool     KBLogFeatures = true;             // Essential
input bool     TelemetryEnable = true;
input bool     TelemetryVerbose = true;          // Capture all details

// Diverse strategy exposure
input bool     SelectorEnable = true;
input int      SelectorTopN = 10;                // More strategies

// Policy fallback for coverage
input bool     UsePolicyGating = true;
input bool     DefaultPolicyFallback = true;
input bool     FallbackDemoOnly = false;         // Allow everywhere for data
```

---

## Gate Configuration

### Gate Threshold Tuning

Each gate supports dynamic threshold adjustment via learning system:

```cpp
// Initial thresholds (inputs)
G1_MinConfidence = 0.6
G2_MaxCorrelation = 0.8
G3_MinScore = 0.5
// ... etc

// Learning system adjusts based on outcomes
if (GateLearningEnable) {
    // Thresholds adjust automatically based on pass/fail success rates
    // Target: achieve configured success rate per gate
}
```

### Shadow Mode for Testing

Test gate changes without blocking trades:

```cpp
input bool     NoConstraintsMode = true;         // Enable shadow mode
input bool     TelemetryVerbose = true;          // Capture shadow decisions

// Gates still evaluate but don't block
// Check telemetry for: LogGatingShadow() events
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

**See Also:**
- [Execution-Pipeline.md](Execution-Pipeline.md) - Detailed execution flow
- [Observability-Guide.md](Observability-Guide.md) - Monitoring and telemetry
- [Policy-Exploration-Guide.md](Policy-Exploration-Guide.md) - Policy and exploration details
