# Unified System Guide

## Overview

The DualEA system features a **Unified Architecture** that eliminates redundancy by consolidating insights management and gating pipeline into three core components: `ConfigManager`, `EventBus`, and `SystemMonitor`.

## Core Components

### 1. ConfigManager (`ConfigManager.mqh`)

Singleton configuration manager providing centralized configuration for gates, insights, and system settings.

```cpp
// Access the singleton instance
CConfigManager* config = CConfigManager::GetInstance();

// Configure gate parameters
config->SetGateThreshold("SignalRinse", 0.65);
config->SetGateEnabled("MarketSoap", true);

// Configure insights
config->SetInsightsAutoReload(true);
config->SetInsightsFreshnessMinutes(60);

// System settings
config->SetVerboseLogging(true);
config->SetNoConstraintsMode(false);
```

**Key Features:**
- Per-gate configuration (8 gates with individual thresholds)
- Insights auto-reload settings
- System-wide flags (NoConstraintsMode, verbose logging)
- Thread-safe singleton pattern

### 2. EventBus (`EventBus.mqh`)

Cross-component communication with priority-based event logging.

```cpp
// Log events with priority
EventBus.Info("strategy_signal", "ADXStrategy generated buy signal");
EventBus.Warning("gate_blocked", "RiskWash blocked entry: spread too high");
EventBus.Error("policy_load", "Failed to parse policy.json");

// Query recent events
string recentErrors[];
int count = EventBus.GetRecentErrors(recentErrors, 10);
```

**Event Priorities:**
- `LOG_ERROR` (0): Critical failures requiring immediate attention
- `LOG_WARNING` (1): Anomalies and gating blocks
- `LOG_INFO` (2): Normal operations and signals
- `LOG_DEBUG` (3): Detailed diagnostics (verbose mode only)

### 3. SystemMonitor (`SystemMonitor.mqh`)

Real-time health monitoring and performance metrics.

```cpp
// Record gate processing time
SystemMonitor.RecordGateTime("SignalRinse", elapsedMicroseconds);

// Update health score
SystemMonitor.UpdateHealthScore(gateSuccessRate);

// Get status report
string report = SystemMonitor.GetStatusReport();
```

**Metrics Tracked:**
- Gate success rates per slice
- Average processing times
- Memory usage
- Health score (0.0 - 1.0)
- System alerts

## Integration Architecture

### Unified Gate System

```cpp
// Initialize unified system (enabled by default)
CGateManager* gateManager = new CGateManager(symbol, timeframe, learning, true);

// The unified system automatically:
// 1. Loads configuration from ConfigManager
// 2. Logs all events via EventBus
// 3. Reports metrics to SystemMonitor
```

### Backward Compatibility

Legacy code continues to work with unified components:

```cpp
// Old approach (still works)
CGateManager* gateManager = new CGateManager();
gateManager.Initialize(config);

// New unified approach (recommended)
CConfigManager* config = CConfigManager::GetInstance();
CEfficientGateManagerEnhanced* gateManager = new CEfficientGateManagerEnhanced();
gateManager.InitializeUnified();
```

## Configuration Parameters

### Gate Configuration
```cpp
// News filtering
UseNewsFilter, NewsBufferBeforeMin, NewsBufferAfterMin, NewsImpactMin

// Trading windows  
UsePromotionGate, PromoStartHour, PromoEndHour

// Market regime detection
UseRegimeGate, RegimeATRPeriod, RegimeMinATRPct, RegimeMaxATRPct

// Circuit breakers and insights
CircuitCooldownSec, NoConstraintsMode
InsightsAutoReload, InsightsLiveFreshMinutes, InsightsStaleHours
```

### Execution Pipeline
1. **Early Phase**: Market condition validation and news filtering
2. **8-Stage Gate Processing**: Signal refinement through unified gate system
3. **Risk Management**: Position sizing and portfolio risk assessment
4. **Execution**: Trade placement with full audit trail and telemetry

## Key Benefits

1. **Single Source of Truth**: All configuration in one place
2. **Event-Driven Architecture**: Unified logging with severity levels
3. **Real-Time Monitoring**: Health scoring and performance metrics
4. **Backward Compatibility**: Legacy mode support
5. **Cross-EA Consistency**: Identical behavior in PaperEA and LiveEA

## Migration Guide

### From Legacy GateManager

**Before:**
```cpp
#include "Include/GateManager.mqh"
CGateManager* gateManager = new CGateManager();
gateManager.SetThreshold(0.6);
```

**After:**
```cpp
#include "Include/ConfigManager.mqh"
#include "Include/EventBus.mqh"

CConfigManager* config = CConfigManager::GetInstance();
config->SetGateThreshold("SignalRinse", 0.6);

EventBus.Info("init", "Gate system initialized");
```

### From Manual Logging

**Before:**
```cpp
if(verbose) Print("[DEBUG] Signal generated: ", signal);
```

**After:**
```cpp
EventBus.Debug("signal_gen", "Signal generated", signal);
```

## Best Practices

1. **Always use ConfigManager** for configuration changes
2. **Log all significant events** via EventBus for observability
3. **Monitor health scores** to detect system degradation
4. **Use appropriate log levels** (Error for failures, Warning for blocks)
5. **Enable verbose logging** only for debugging sessions

## Troubleshooting

### Events not appearing in logs
- Check `Verbosity` setting (must be >= event priority)
- Verify EventBus is initialized in `OnInit()`

### Config changes not taking effect
- Ensure `CConfigManager::GetInstance()` is used
- Check for conflicting direct gate configuration

### High memory usage
- SystemMonitor caches recent events (configurable limit)
- Reduce `TelemetryBufferMax` in inputs

## Related Documentation
- [README.md](README.md) - Main system documentation
- [ConfigManager.mqh](../Include/ConfigManager.mqh) - Implementation
- [EventBus.mqh](../Include/EventBus.mqh) - Event system
- [SystemMonitor.mqh](../Include/CSystemMonitor.mqh) - Monitoring
