# DualEA Nuclear Redis Schema

## Overview
Redis serves as the central nervous system for DualEA, replacing file-based KB with real-time, in-memory state management.

---

## Key Naming Convention

```
dualea:{category}:{subcategory}:{identifier}
```

---

## 1. TRADES & POSITIONS

### Keys (Hashes)
```
dualea:trade:{ticket}          # Individual trade data
dualea:position:{symbol}       # Current position state per symbol
dualea:stats:global            # Global statistics
```

### Fields (Trade Hash)
```json
{
  "ticket": "123456",
  "strategy": "ADXStrategy",
  "symbol": "EURUSD",
  "timeframe": "15",
  "direction": "BUY",
  "entry_price": "1.0850",
  "stop_loss": "1.0800",
  "take_profit": "1.0950",
  "lot_size": "0.1",
  "entry_time": "1696800000",
  "exit_time": "1696810000",
  "exit_price": "1.0920",
  "profit": "70.00",
  "pips": "70",
  "result": "WIN",
  "regime": "trending",
  "ml_confidence": "0.75"
}
```

### Sorted Sets (Time-series)
```
dualea:trades:history          # ZADD with timestamp as score
dualea:trades:wins             # Winning trades sorted by profit
dualea:trades:losses           # Losing trades sorted by loss
```

---

## 2. SIGNALS & STRATEGY STATE

### Keys (Hashes)
```
dualea:signal:{strategy}:{symbol}:{tf}    # Latest signal per strategy/symbol/tf
dualea:strategy:{name}:state              # Strategy runtime state
dualea:strategy:{name}:metrics            # Strategy performance metrics
```

### Sets (Active tracking)
```
dualea:strategies:active       # SADD active strategy names
dualea:strategies:disabled     # Disabled strategies
dualea:symbols:trading         # Currently trading symbols
```

---

## 3. ML & POLICY

### Keys (Hashes)
```
dualea:policy:{strategy}:{symbol}:{tf}    # ML policy slice
dualea:ml:features:latest                 # Latest feature vector
dualea:ml:model:info                      # Model metadata
```

### Fields (Policy Hash)
```json
{
  "confidence": "0.75",
  "predicted_return": "0.015",
  "position_size_mult": "0.8",
  "sl_mult": "1.2",
  "tp_mult": "1.5",
  "min_pf": "1.35",
  "min_wr": "0.52",
  "allow_trade": "true",
  "timestamp": "1696800000"
}
```

### Lists (Feature queue)
```
dualea:ml:features:queue       # LPUSH features for batch processing
```

---

## 4. GATES & RISK

### Keys (Hashes)
```
dualea:gate:{name}:state       # Gate state (passed/blocked counts)
dualea:risk:circuit_breaker    # Circuit breaker state
dualea:risk:correlation        # Correlation matrix
```

### Fields (Circuit Breaker)
```json
{
  "active": "false",
  "triggered_at": "0",
  "reason": "",
  "daily_loss": "0.0",
  "daily_loss_limit": "5.0",
  "drawdown": "0.0",
  "drawdown_limit": "10.0",
  "cooldown_until": "0"
}
```

---

## 5. REGIME & MARKET STATE

### Keys (Hashes)
```
dualea:regime:current          # Current market regime
dualea:regime:history          # Sorted set of regime changes
```

### Fields (Regime)
```json
{
  "regime": "trending",
  "confidence": "0.85",
  "atr": "0.0015",
  "adx": "32.5",
  "volatility": "high",
  "duration_bars": "45",
  "timestamp": "1696800000"
}
```

---

## 6. TELEMETRY & EVENTS

### Keys (Streams - Redis 5.0+)
```
dualea:events                  # XADD event stream
dualea:telemetry               # XADD telemetry stream
```

### Lists (Fallback if no streams)
```
dualea:events:queue            # LPUSH events
dualea:telemetry:queue         # LPUSH telemetry
```

---

## 7. PUB/SUB CHANNELS

### Channels
```
dualea:events                  # General events
dualea:trades                  # Trade execution events
dualea:signals                 # Signal generation events
dualea:ml:predictions          # ML prediction results
dualea:ml:features             # Feature vectors for ML
dualea:gates                   # Gate pass/block events
dualea:risk                    # Risk events (CB, margin, etc.)
dualea:regime                  # Regime change events
dualea:telemetry               # Telemetry data
dualea:commands                # Control commands (reload, etc.)
dualea:ui:updates              # Dashboard UI updates
```

### Message Format (JSON)
```json
{
  "type": "trade_executed",
  "timestamp": "1696800000.123",
  "data": {
    "ticket": "123456",
    "strategy": "ADXStrategy",
    "symbol": "EURUSD",
    "direction": "BUY",
    "price": "1.0850",
    "lot_size": "0.1"
  }
}
```

---

## 8. CONFIGURATION & HOT-RELOAD

### Keys (Hashes)
```
dualea:config:global           # Global EA configuration
dualea:config:strategy:{name}  # Per-strategy config
dualea:config:gates            # Gate configuration
```

### Versioning
```
dualea:config:version          # Config version number (increment on change)
```

---

## 9. EXPLORATION MODE

### Keys (Hashes)
```
dualea:explore:{strategy}:{symbol}:{tf}:week:{yyyymmdd}   # Weekly exploration count
dualea:explore:{strategy}:{symbol}:{tf}:day:{yyyymmdd}    # Daily exploration count
```

---

## 10. INSIGHTS & STATISTICS

### Keys (Hashes)
```
dualea:insights:{strategy}:{symbol}:{tf}    # Performance insights
```

### Fields (Insights)
```json
{
  "trade_count": "150",
  "win_rate": "0.58",
  "profit_factor": "1.45",
  "expectancy_r": "0.35",
  "max_dd_r": "2.5",
  "sharpe": "1.2",
  "last_updated": "1696800000"
}
```

---

## Data Retention & Eviction

### Eviction Policy
```
maxmemory-policy: allkeys-lru
maxmemory: 512mb
```

### TTL Strategy
- **Real-time data**: No TTL (evicted by LRU)
- **Historical trades**: 30 days TTL
- **Telemetry**: 7 days TTL
- **Exploration counters**: 90 days TTL
- **ML features**: 1 day TTL

### Persistence
- **Disabled** for maximum speed (in-memory only)
- Critical data backed up to files periodically by EA

---

## Access Patterns

### High-Frequency (Every Tick)
- `dualea:signal:{strategy}:{symbol}:{tf}` - Read/Write
- `dualea:policy:{strategy}:{symbol}:{tf}` - Read
- `dualea:regime:current` - Read

### Medium-Frequency (Every Trade)
- `dualea:trade:{ticket}` - Write
- `dualea:trades:history` - ZADD
- Pub/Sub: `dualea:trades` - Publish

### Low-Frequency (Periodic)
- `dualea:insights:*` - Read/Write (hourly)
- `dualea:config:*` - Read (on reload)
- `dualea:ml:model:info` - Read (on startup)

---

## Example Usage (MQL5)

```mql5
CRedisClient redis;

// Connect
redis.Connect();

// Store trade
redis.HSet("dualea:trade:123456", "strategy", "ADXStrategy");
redis.HSet("dualea:trade:123456", "profit", "70.00");

// Publish event
string event = "{\"type\":\"trade\",\"ticket\":123456}";
redis.Publish("dualea:trades", event);

// Get policy
string confidence = redis.HGet("dualea:policy:ADXStrategy:EURUSD:15", "confidence");

// Check circuit breaker
string cb_active = redis.HGet("dualea:risk:circuit_breaker", "active");
```

---

## Monitoring Commands

```bash
# Monitor all activity
redis-cli MONITOR

# Check memory usage
redis-cli INFO memory

# List all keys
redis-cli KEYS "dualea:*"

# Subscribe to events
redis-cli SUBSCRIBE dualea:events

# Get key count
redis-cli DBSIZE
```
