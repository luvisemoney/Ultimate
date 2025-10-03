# Observability Guide — DualEA System

**Telemetry, monitoring, and debugging reference**

---

## Table of Contents

1. [Telemetry System](#telemetry-system)
2. [Event Types Reference](#event-types-reference)
3. [SystemMonitor](#systemmonitor)
4. [EventBus](#eventbus)
5. [Logging Levels](#logging-levels)
6. [Debugging Techniques](#debugging-techniques)
7. [Performance Monitoring](#performance-monitoring)

---

## Telemetry System

### Overview

DualEA uses **TelemetryStandard** wrapper for unified event logging across both PaperEA and LiveEA.

**Output Formats**:
- MT5 Journal (real-time)
- CSV files (Common/Files/DualEA/telemetry_YYYYMMDD.csv)
- JSON logs (Common/Files/DualEA/logs/trades_YYYYMMDD.json)

### Configuration

```cpp
input bool     TelemetryEnable = true;           // Enable telemetry
input bool     TelemetryVerbose = false;         // Verbose logging
input bool     TelemetryStandard = true;         // Use TelemetryStandard wrapper
input int      TelemetryFlushSeconds = 300;      // Flush every 5 minutes
```

### Event Structure

**CSV Format**:
```csv
timestamp,event_type,symbol,timeframe,strategy,gate,result,reason,latency_ms,metadata
2025-01-15T10:30:00Z,gate_decision,EURUSD,60,ADXStrategy,signal_rinse,pass,,5,confidence=0.85
2025-01-15T10:30:01Z,gate_decision,EURUSD,60,ADXStrategy,insights,block,below_winrate,2,winrate=0.42
```

**JSON Format** (UnifiedTradeLogger):
```json
{
  "timestamp": "2025-01-15T10:30:00Z",
  "event_type": "trade_execution",
  "symbol": "EURUSD",
  "timeframe": 60,
  "strategy": "ADXStrategy",
  "direction": 1,
  "entry": 1.0850,
  "sl": 1.0800,
  "tp": 1.0950,
  "lots": 0.10,
  "gates": ["signal_rinse:pass", "market_soap:pass", ...],
  "policy": {"confidence": 0.75, "sl_mult": 1.0},
  "profit": 15.50,
  "r_multiple": 1.2
}
```

---

## Event Types Reference

### Core Events

**gate_decision**
- **When**: Each gate pass/block decision
- **Fields**: `gate`, `result` (pass/block), `reason`, `latency_ms`
- **Example**: `gate_decision,EURUSD,60,ADXStrategy,market_soap,block,high_correlation,8,corr=0.82`

**trade_execution**
- **When**: Order placed (or paper position created)
- **Fields**: `direction`, `entry`, `lots`, `sl`, `tp`, `retcode` (LiveEA only)
- **Example**: `trade_execution,EURUSD,60,ADXStrategy,BUY,1.0850,0.10,1.0800,1.0950,retcode=10009`

**trade_closed**
- **When**: Position closed (SL/TP hit or manual close)
- **Fields**: `entry`, `exit`, `profit`, `r_multiple`, `duration_sec`, `reason`
- **Example**: `trade_closed,EURUSD,60,ADXStrategy,1.0850,1.0950,15.50,1.2,3600,tp_hit`

**policy_load**
- **When**: policy.json loaded or reloaded
- **Fields**: `slices`, `min_confidence`, `file_size`, `load_time_ms`
- **Example**: `policy_load,,,,,45,0.55,12345,25`

**insights_rebuild**
- **When**: insights.json regenerated
- **Fields**: `slices`, `source_trades`, `rebuild_time_sec`
- **Example**: `insights_rebuild,,,,,123,4567,45`

**threshold_adjust**
- **When**: GateLearningSystem adjusts gate thresholds
- **Fields**: `gate`, `old_threshold`, `new_threshold`, `success_rate`
- **Example**: `threshold_adjust,,,,,signal_rinse,0.60,0.58,0.72`

### Risk Events

**risk4_spread**
- **When**: Spread check (Gate 7 or early phase)
- **Fields**: `spread_pips`, `max_allowed`, `result`
- **Example**: `risk4_spread,EURUSD,60,,,,block,spread_too_wide,spread=4.2 max=3.0`

**risk4_margin**
- **When**: Margin level check
- **Fields**: `margin_level`, `min_required`, `result`
- **Example**: `risk4_margin,EURUSD,60,,,,block,margin_low,level=180% min=200%`

**risk4_drawdown**
- **When**: Drawdown check
- **Fields**: `current_dd_pct`, `max_allowed`, `result`
- **Example**: `risk4_drawdown,,,,,12.5,10.0,block`

**risk4_daily_loss**
- **When**: Daily loss circuit breaker
- **Fields**: `daily_pnl_pct`, `max_loss_pct`, `result`
- **Example**: `risk4_daily_loss,,,,,−5.2,−5.0,block`

**risk4_consecutive**
- **When**: Consecutive loss check
- **Fields**: `consecutive_losses`, `max_allowed`, `result`
- **Example**: `risk4_consecutive,,,,,5,5,block`

### Position Manager Events

**pm_corr_sizing**
- **When**: Correlation-adjusted sizing applied
- **Fields**: `avg_corr`, `base_lots`, `adjusted_lots`, `dampening`
- **Example**: `pm_corr_sizing,GBPUSD,60,,0.68,0.10,0.066,0.66`

**pm_corr_floor**
- **When**: Correlation floor applied
- **Fields**: `floor_type` (mult/lots), `floor_value`, `final_lots`
- **Example**: `pm_corr_floor,GBPUSD,60,,mult,0.25,0.025`

**pm_corr_scale_in**
- **When**: Scale-in with correlation adjustment
- **Fields**: Same as `pm_corr_sizing`

**pm_adaptive_sizing**
- **When**: Adaptive sizing based on performance
- **Fields**: `perf_factor`, `base_lots`, `adjusted_lots`

### Selector Events (Phase 5)

**p5_refresh**
- **When**: Strategy selector refreshed
- **Fields**: `strategies_count`, `refresh_time_ms`

**p5_rescore**
- **When**: Strategies rescored
- **Fields**: `strategy`, `old_score`, `new_score`, `reason`

**p5_auto_tune**
- **When**: Selector thresholds auto-tuned
- **Fields**: `threshold_type`, `old_value`, `new_value`

**p5_selector_cfg**
- **When**: Selector configuration changed
- **Fields**: `param`, `old_value`, `new_value`

### Exploration Events

**explore_allow**
- **When**: Exploration trade allowed
- **Fields**: `day_count`, `day_max`, `week_count`, `week_max`
- **Example**: `explore_allow,EURUSD,60,ADXStrategy,1,2,2,3`

**explore_block_day**
- **When**: Daily exploration cap reached
- **Fields**: Same as `explore_allow`

**explore_block_week**
- **When**: Weekly exploration cap reached
- **Fields**: Same as `explore_allow`

### Policy Fallback Events

**policy_fallback**
- **When**: Fallback mode triggered
- **Fields**: `fallback_type` (no_policy/slice_miss), `demo`, `allowed`
- **Example**: `policy_fallback,EURUSD,60,ADXStrategy,no_policy,true,true`

---

## SystemMonitor

### Purpose

Real-time health monitoring and performance tracking for the entire system.

### Initialization

```cpp
input bool     MonitorEnable = true;
input int      MonitorUpdateSeconds = 60;
input double   MonitorHealthThreshold = 70.0;
input bool     MonitorAlertOnDegradation = true;

CSystemMonitor* monitor = CSystemMonitor::GetInstance();
```

### Metrics Tracked

**Gate Success Rates**:
```cpp
double GetGateSuccessRate(int gateNum);  // 0.0-1.0
```
- Tracks pass/fail ratio per gate over rolling window
- Target: configurable per gate (default 0.7-0.8)

**Processing Times**:
```cpp
double GetAvgGateLatency(int gateNum);   // milliseconds
double GetAvgPipelineLatency();          // milliseconds
```

**System Health Score** (0-100):
```cpp
double GetSystemHealthScore();
```
Calculated from:
- Gate success rates vs targets
- Processing latencies vs thresholds
- Memory usage
- Error rates
- Event queue depth

**Degradation Detection**:
- Triggers alert if health score drops below `MonitorHealthThreshold`
- Logs degradation reason (which metric failed)

### Usage Example

```cpp
void OnTimer() {
    if(MonitorEnable) {
        double health = monitor.GetSystemHealthScore();
        
        if(health < MonitorHealthThreshold) {
            Print(StringFormat("[ALERT] System health degraded: %.1f < %.1f",
                health, MonitorHealthThreshold));
            telemetry.Event("system_alert", "health_degraded", health);
        }
        
        // Log metrics
        for(int i = 1; i <= 8; i++) {
            double successRate = monitor.GetGateSuccessRate(i);
            double latency = monitor.GetAvgGateLatency(i);
            Print(StringFormat("[MONITOR] Gate %d: SR=%.2f Latency=%.1fms",
                i, successRate, latency));
        }
    }
}
```

---

## EventBus

### Purpose

Cross-component communication with priority-based event logging.

### Configuration

```cpp
input bool     EventBusEnable = true;
input int      EventBusPriority = 2;         // 0=ALL, 1=LOW, 2=MED, 3=HIGH, 4=CRITICAL
input int      EventBusMaxQueueSize = 1000;
```

### Priority Levels

- **0 (ALL)**: Debug/verbose events
- **1 (LOW)**: Informational events (gate passes, normal operations)
- **2 (MEDIUM)**: Warnings (gate blocks, threshold adjustments)
- **3 (HIGH)**: Errors (file I/O failures, policy load failures)
- **4 (CRITICAL)**: System failures (circuit breakers, broker errors)

### Event Emission

```cpp
CEventBus* eventBus = CEventBus::GetInstance();

// Emit event
eventBus.Emit(
    EVENT_PRIORITY_MEDIUM,              // Priority
    "gate_decision",                     // Event type
    symbol,                              // Symbol
    timeframe,                           // Timeframe
    "ADXStrategy",                       // Strategy
    "insights",                          // Gate/component
    "block",                             // Result
    "below_winrate",                     // Reason
    telemetry                            // Telemetry sink
);
```

### Event Queue

- Events queued if `EventBusEnable=true`
- Filtered by `EventBusPriority` (only events at or above priority level are logged)
- Flushed periodically or on demand
- Max queue size: `EventBusMaxQueueSize` (oldest events dropped if exceeded)

---

## Logging Levels

### Log Level Configuration

```cpp
input int      LogLevel = 2;             // 0=None, 1=Error, 2=Warning, 3=Info, 4=Debug
input bool     LogToFile = true;
input bool     LogToJournal = true;
```

### Level Definitions

**0 - None**: No logging (not recommended)

**1 - Error**: Only critical errors
- File I/O failures
- Broker retcode errors
- Parse errors (policy.json, insights.json)

**2 - Warning** (Default): Errors + warnings
- Gate blocks
- Policy fallbacks
- Circuit breaker trips
- Threshold adjustments

**3 - Info**: Errors + warnings + informational
- Trade executions
- Gate passes
- Policy loads
- Insights rebuilds

**4 - Debug**: All events including verbose details
- Every gate decision with full context
- Signal generation details
- File I/O operations
- Learning system updates

### Log Output

**MT5 Journal**:
```
2025.01.15 10:30:00.123 DualEA (EURUSD,H1) [GATE] signal_rinse: pass - confidence=0.85
2025.01.15 10:30:00.156 DualEA (EURUSD,H1) [GATE] insights: block - below_winrate (WR=0.42 < 0.50)
```

**File Logs** (if `LogToFile=true`):
- Path: `Common/Files/DualEA/logs/ea_YYYYMMDD.log`
- Rotation: Daily, keeps last 30 days
- Format: Same as Journal with timestamp prefix

---

## Debugging Techniques

### Debug Flags

Enable specific debug output:

```cpp
input bool     DebugTrailing = false;    // Trailing stop operations
input bool     DebugGates = false;       // Gate decisions
input bool     DebugStrategies = false;  // Strategy signals
input bool     DebugPolicy = false;      // Policy loading/application
input bool     DebugInsights = false;    // Insights loading
input bool     DebugKB = false;          // KB writes
```

### Shadow Mode (NoConstraintsMode)

Test gate changes without blocking trades:

```cpp
input bool     NoConstraintsMode = true;     // Enable shadow mode
input bool     TelemetryVerbose = true;      // Capture all shadow decisions
```

**Shadow Logging**:
```
[SHADOW] gate=insights result=block reason=below_winrate (but allowing due to NoConstraintsMode)
```

All gate decisions logged via `LogGatingShadow()` but trades proceed regardless.

### Telemetry Analysis

**Query gate block reasons**:
```powershell
Import-Csv telemetry_20250115.csv | 
    Where-Object {$_.event_type -eq 'gate_decision' -and $_.result -eq 'block'} |
    Group-Object reason | 
    Select-Object Count, Name | 
    Sort-Object Count -Descending
```

**Analyze latencies**:
```powershell
Import-Csv telemetry_20250115.csv | 
    Where-Object {$_.event_type -eq 'gate_decision'} |
    Measure-Object latency_ms -Average -Maximum
```

### Common Issues

**High gate block rate**:
1. Check `SystemMonitor.GetGateSuccessRate(gateNum)`
2. Review telemetry for most common `reason`
3. Adjust threshold or disable gate temporarily
4. Use shadow mode to observe impact

**Policy fallback always triggering**:
1. Check if policy.json exists: `Common/Files/DualEA/policy.json`
2. Verify `policyData.slices > 0`
3. Check slice coverage for your symbols/timeframes/strategies
4. Review `DebugPolicy=true` logs

**Exploration caps reached quickly**:
1. Check counters: `explore_counts.csv`, `explore_counts_day.csv`
2. Increase caps or reset counters (delete files)
3. Verify `NoConstraintsMode=false` (otherwise caps bypassed)

**KB writes failing**:
1. Enable `DebugKB=true`
2. Check Common Files path exists: `FolderCreate("DualEA", FILE_COMMON)`
3. Verify file permissions
4. Check disk space

---

## Performance Monitoring

### Latency Targets

**Per-Component**:
- Signal generation: <5ms
- Single gate: <10ms
- 8-stage gates total: <50ms
- Policy/insights lookup: <2ms (cached)
- KB write: <10ms
- Telemetry emit: <1ms
- **Total pipeline**: <100ms

**Monitoring**:
```cpp
double pipelineStart = GetTickCount();
// ... pipeline execution ...
double pipelineEnd = GetTickCount();
double latency = pipelineEnd - pipelineStart;

if(latency > 100) {
    Print(StringFormat("[PERF] Pipeline slow: %.1fms", latency));
    telemetry.Event("performance_alert", "pipeline_slow", latency);
}
```

### Memory Usage

**Tracking**:
```cpp
long memUsed = TerminalInfoInteger(TERMINAL_MEMORY_USED);  // KB
int handles = IndicatorsTotal();

if(memUsed > 50000) {  // 50MB
    Print(StringFormat("[PERF] High memory: %d KB", memUsed));
}
```

**Expected Footprint**:
- Single EA instance: ~1.5MB
- With all strategies loaded: ~2MB
- High telemetry volume: ~5MB

### File I/O Monitoring

**Batch Writes**:
- KB writes: Buffer every 10 trades
- Features export: Buffer every 50 trades
- Telemetry flush: Every 5 minutes or 1000 events

**Monitoring**:
```cpp
int writeCount = 0;
double totalWriteTime = 0;

void WriteToKB(...) {
    double start = GetTickCount();
    // ... write operation ...
    double end = GetTickCount();
    
    writeCount++;
    totalWriteTime += (end - start);
    
    if(writeCount % 100 == 0) {
        double avgTime = totalWriteTime / writeCount;
        Print(StringFormat("[PERF] KB writes: %d total, %.2fms avg", 
            writeCount, avgTime));
    }
}
```

---

## Telemetry Best Practices

1. **Use appropriate log levels**: Debug only during development, Info/Warning for production
2. **Enable TelemetryStandard**: Provides consistent formatting across EAs
3. **Flush regularly**: Don't let event queue grow unbounded
4. **Rotate logs**: Keep file sizes manageable (<100MB)
5. **Monitor health score**: Set up alerts for degradation
6. **Use shadow mode**: Test gate changes safely
7. **Archive old telemetry**: Compress and move to cold storage after 30 days

---

**See Also:**
- [Configuration-Reference.md](Configuration-Reference.md) - Telemetry input parameters
- [Execution-Pipeline.md](Execution-Pipeline.md) - When events are emitted
- [Policy-Exploration-Guide.md](Policy-Exploration-Guide.md) - Policy/exploration events
