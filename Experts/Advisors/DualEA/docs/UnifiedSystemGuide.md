# DualEA Unified System Integration Guide

## Overview

The DualEA Unified System eliminates redundancy between the Insights Handshake/Auto-Reload system and the Gating Pipeline/Telemetry system by providing a centralized architecture with shared components.

## Core Components

### 1. ConfigManager (Singleton)
- **Purpose**: Centralized configuration management for all system components
- **Features**:
  - Gate-specific configuration (thresholds, success rate targets, enabled/disabled)
  - Insights configuration (auto-reload, freshness, polling intervals)
  - System-wide settings (no constraints mode, verbose logging)
  - Configuration persistence (save/load from files)

### 2. EventBus (Singleton)
- **Purpose**: Unified event system for cross-component communication
- **Features**:
  - Event types: Gate processing, signal generation, insights updates, trade execution, system status, errors, performance metrics
  - Subscriber pattern with up to 10 subscribers per event type
  - Event history (last 100 events)
  - Priority-based logging (low, normal, high, critical)

### 3. SystemMonitor (Singleton)
- **Purpose**: Consolidated health monitoring and performance metrics
- **Features**:
  - Real-time system health scoring
  - Gate-specific success rate tracking
  - Performance metrics (processing times, events per second)
  - Automatic event subscription and processing
  - Health reports and statistics

## Integration Benefits

### Before (Redundant Systems)
```
Insights System ←→ File I/O ←→ Gating System
     ↓                           ↓
Independent Config      Independent Monitoring
Independent Logging     Independent Events
```

### After (Unified System)
```
ConfigManager ←→ EventBus ←→ SystemMonitor
     ↓              ↓              ↓
GateManager ←→ InsightsManager ←→ LearningBridge
```

## Usage Examples

### Basic Integration
```cpp
// Initialize unified system
CConfigManager* config = CConfigManager::GetInstance();
CEventBus* eventBus = CEventBus::GetInstance();
CSystemMonitor* monitor = CSystemMonitor::GetInstance();

// Configure system
config->SetVerboseLogging(true);
config->SetNoConstraintsMode(false);

// Create gate manager with unified system
CGateManager* gateManager = new CGateManager(symbol, timeframe, learning, true);
```

### Event Subscription
```cpp
class MySubscriber : public IEventSubscriber {
public:
    void OnEvent(const EventData& event) override {
        if(event.type == EVENT_GATE_PROCESSED) {
            // Handle gate events
        }
    }
    string GetSubscriberName() override { return "MySubscriber"; }
};

MySubscriber* subscriber = new MySubscriber();
eventBus->Subscribe(EVENT_GATE_PROCESSED, subscriber);
```

### Configuration Management
```cpp
// Get gate configuration
GateConfig config = configManager->GetGateConfig(0); // SignalRinse gate
config.threshold = 0.7;
config.enabled = true;
configManager->SetGateConfig(0, config);

// System-wide settings
configManager->SetNoConstraintsMode(true); // Disable all gates for testing
```

### Monitoring and Health Checks
```cpp
// Get system health
SystemHealth health = monitor->GetSystemHealth();
Print("System Status: ", health.status);
Print("Gate Success Rate: ", health.gate_success_rate * 100, "%");

// Get gate-specific metrics
double gateSuccessRate = monitor->GetGateSuccessRate("SignalRinse");
```

## Migration from Legacy System

### Step 1: Update Includes
```cpp
// Old way
#include "LearningBridge.mqh"

// New way
#include "LearningBridge.mqh"
#include "ConfigManager.mqh"
#include "EventBus.mqh"
#include "SystemMonitor.mqh"
```

### Step 2: Update Constructor Calls
```cpp
// Old way
CGateManager* gateManager = new CGateManager(symbol, timeframe, learning);

// New way (unified mode enabled by default)
CGateManager* gateManager = new CGateManager(symbol, timeframe, learning, true);

// Legacy mode (for backward compatibility)
CGateManager* gateManager = new CGateManager(symbol, timeframe, learning, false);
```

### Step 3: Replace Direct Configuration
```cpp
// Old way - direct gate threshold setting
gate->SetThreshold(0.7);

// New way - through configuration manager
CConfigManager* config = CConfigManager::GetInstance();
config->SetGateThreshold(0, 0.7); // Gate index 0
```

### Step 4: Replace Direct Logging
```cpp
// Old way
Print("Gate processed: ", result);

// New way - through event bus
CEventBus* eventBus = CEventBus::GetInstance();
eventBus->PublishGateEvent(gateName, passed, reason);
```

## Configuration Options

### Gate Configuration
```cpp
struct GateConfig {
    bool enabled;                    // Gate enabled/disabled
    double threshold;               // Gate threshold value
    int cooldown_sec;              // Cooldown period
    double success_rate_target;    // Target success rate
    string name;                   // Gate name
};
```

### Insights Configuration
```cpp
struct InsightsConfig {
    bool auto_reload;              // Enable auto-reload
    int freshness_minutes;         // Freshness threshold
    int poll_interval_sec;         // Polling interval
    int stale_hours;              // Staleness threshold
    int min_source_advance_hours;  // Minimum source advance
    int min_interval_hours;        // Minimum rebuild interval
    int rebuild_timeout_ms;        // Rebuild timeout
};
```

### System Configuration
```cpp
struct SystemConfig {
    bool no_constraints_mode;      // Disable all constraints
    bool verbose_logging;          // Enable verbose logging
    string data_path;             // Data storage path
    int max_records;              // Maximum records to keep
};
```

## Event Types

| Event Type | Description | Priority | Usage |
|------------|-------------|----------|-------|
| `EVENT_GATE_PROCESSED` | Gate processing completed | Normal | Gate performance tracking |
| `EVENT_SIGNAL_GENERATED` | New trading signal | Normal | Signal flow monitoring |
| `EVENT_INSIGHTS_UPDATED` | Insights data updated | Normal | Data freshness tracking |
| `EVENT_TRADE_EXECUTED` | Trade execution completed | High | Trade result tracking |
| `EVENT_SYSTEM_STATUS` | System status change | Normal | System state monitoring |
| `EVENT_CONFIG_CHANGED` | Configuration updated | Normal | Configuration tracking |
| `EVENT_ERROR_OCCURRED` | Error event | Critical | Error handling |
| `EVENT_PERFORMANCE_METRIC` | Performance metric update | Normal | Performance monitoring |

## Performance Considerations

### Memory Usage
- ConfigManager: ~1KB (configuration data)
- EventBus: ~10KB (event history + subscribers)
- SystemMonitor: ~5KB (statistics + metrics)
- Total overhead: ~16KB

### Processing Overhead
- Event publishing: ~0.1ms per event
- Configuration lookup: ~0.01ms per call
- Health monitoring: ~1ms per update
- Gate processing: +10% overhead for unified features

### Scalability
- Maximum 10 subscribers per event type
- Event history limited to 100 events
- Configuration supports up to 8 gates
- Statistics tracking for unlimited signals

## Troubleshooting

### Common Issues

1. **Compilation Errors**
   - Ensure all include files are present
   - Check for circular dependencies
   - Verify MQL5 syntax compatibility

2. **Runtime Errors**
   - Check singleton initialization order
   - Verify pointer validity before use
   - Ensure proper cleanup in OnDeinit()

3. **Performance Issues**
   - Disable verbose logging in production
   - Reduce event history size if needed
   - Monitor memory usage with large datasets

### Debug Mode
```cpp
// Enable debug mode
config->SetVerboseLogging(true);
eventBus->SetVerboseLogging(true);

// Print system status
gateManager->PrintSystemStatus();
eventBus->PrintEventHistory(10);
monitor->PrintHealthReport();
```

## Best Practices

1. **Initialization Order**
   ```cpp
   // Correct order
   CConfigManager* config = CConfigManager::GetInstance();
   CEventBus* eventBus = CEventBus::GetInstance();
   CSystemMonitor* monitor = CSystemMonitor::GetInstance();
   CGateManager* gates = new CGateManager(...);
   ```

2. **Event Handling**
   - Subscribe to only necessary events
   - Keep event handlers lightweight
   - Avoid blocking operations in event handlers

3. **Configuration Management**
   - Use configuration manager for all settings
   - Save/load configuration for persistence
   - Validate configuration values

4. **Error Handling**
   - Check pointer validity
   - Handle singleton cleanup properly
   - Use try-catch for critical operations

5. **Performance Optimization**
   - Disable verbose logging in production
   - Use appropriate event priorities
   - Monitor system health regularly

## Future Enhancements

1. **Configuration Persistence**
   - JSON/XML configuration files
   - Runtime configuration updates
   - Configuration validation

2. **Advanced Monitoring**
   - Real-time dashboards
   - Performance alerts
   - Automated health checks

3. **Event System Extensions**
   - Remote event publishing
   - Event filtering and routing
   - Event persistence and replay

4. **Integration APIs**
   - REST API for external monitoring
   - WebSocket for real-time updates
   - Database integration for analytics
