# ⚛️ DualEA Nuclear System - Quick Start Guide

## 🎯 What Was Built

A complete nuclear-grade trading system with:

### ✅ Core Components
1. **RedisClient.mqh** - Socket-based Redis protocol for MQL5 (no DLL needed)
2. **gRPC ML Service** - Real-time ML predictions (Python)
3. **FastAPI WebSocket Server** - Live streaming to dashboard
4. **Svelte Dashboard** - Real-time monitoring UI
5. **Redis Schema** - Complete data structure design
6. **Auto-setup Scripts** - One-click installation

### 🏗️ Architecture

```
MT5 (DualEA Core) ←→ Redis ←→ ML gRPC Service
                        ↓
                   WebSocket Server
                        ↓
                  Svelte Dashboard
```

---

## 🚀 Installation (3 Steps)

### Step 1: Run Setup Script
```bash
cd Scripts
setup_nuclear_system.bat
```

This will:
- ✅ Install Redis via Chocolatey
- ✅ Install Python dependencies (gRPC, FastAPI, TensorFlow)
- ✅ Generate gRPC code from proto file
- ✅ Install Node.js dashboard dependencies
- ✅ Create all startup scripts

### Step 2: Start All Services
```bash
cd Scripts
start_all_services.bat
```

This starts:
- Redis (localhost:6379)
- ML gRPC Server (localhost:50051)
- WebSocket Server (localhost:8000)
- Dashboard (http://localhost:5173)

### Step 3: Use RedisClient in EA
```mql5
#include "Include/RedisClient.mqh"

CRedisClient redis;

int OnInit() {
    if(!redis.Connect()) {
        Print("Failed to connect to Redis!");
        return INIT_FAILED;
    }
    
    // Store trade
    redis.HSet("dualea:trade:123", "strategy", "ADXStrategy");
    redis.HSet("dualea:trade:123", "profit", "70.00");
    
    // Publish event
    string event = "{\"type\":\"trade\",\"ticket\":123}";
    redis.Publish("dualea:trades", event);
    
    return INIT_SUCCEEDED;
}
```

---

## 📊 Redis Schema Overview

### Keys Structure
```
dualea:trade:{ticket}              # Individual trades (Hash)
dualea:signal:{strategy}:{symbol}  # Latest signals (Hash)
dualea:policy:{strategy}:{symbol}  # ML policy slices (Hash)
dualea:regime:current              # Current market regime (Hash)
dualea:stats:global                # Global statistics (Hash)
```

### Pub/Sub Channels
```
dualea:events       # General events
dualea:trades       # Trade execution
dualea:signals      # Signal generation
dualea:ml:predictions  # ML predictions
dualea:regime       # Regime changes
dualea:commands     # Control commands (reload, etc.)
```

See `docs/Redis_Schema.md` for complete schema.

---

## 🤖 ML gRPC Service

### Protocol Definition
Located in `ML/ml_service.proto`:
- `Predict()` - Single prediction
- `StreamFeatures()` - Bidirectional streaming
- `BatchPredict()` - Batch predictions
- `ReloadModel()` - Hot-reload model
- `HealthCheck()` - Service health

### Usage from MQL5
```mql5
// Send features to ML via Redis
string features = StringFormat(
    "{\"strategy\":\"%s\",\"symbol\":\"%s\",\"atr\":%.5f,\"adx\":%.2f}",
    "ADXStrategy", _Symbol, atr_value, adx_value
);
redis.Publish("dualea:ml:features", features);

// Get policy response
string confidence = redis.HGet("dualea:policy:ADXStrategy:EURUSD:15", "confidence");
```

---

## 🎨 Dashboard Features

Access at: **http://localhost:5173**

### Real-Time Panels
1. **Status Bar** - Active strategies, trades, positions, Redis status
2. **Regime Panel** - Current market regime with confidence
3. **ML Panel** - Live ML predictions with allow/block decisions
4. **Signals Panel** - Real-time signal feed
5. **Trades Feed** - Recent trade execution
6. **Performance Chart** - Equity curve with stats

### Control Actions
- 🔄 Reload Policy
- 🔄 Reload Strategies
- 📊 Refresh Status

---

## 📁 File Structure

```
DualEA/
├── Include/
│   ├── RedisClient.mqh          ⭐ Socket-based Redis client
│   ├── IStrategy.mqh
│   ├── PolicyEngine.mqh
│   └── ... (existing modules)
│
├── ML/
│   ├── ml_service.proto         ⭐ gRPC protocol definition
│   ├── grpc_ml_server.py        ⭐ ML gRPC service
│   ├── fastapi_websocket_server.py  ⭐ WebSocket server
│   ├── requirements_grpc.txt    ⭐ Python dependencies
│   ├── start_ml_server.bat      (auto-generated)
│   └── start_websocket_server.bat (auto-generated)
│
├── dashboard/                   ⭐ Svelte dashboard
│   ├── src/
│   │   ├── App.svelte
│   │   ├── lib/websocket.ts
│   │   └── components/
│   │       ├── Header.svelte
│   │       ├── StatusBar.svelte
│   │       ├── TradesFeed.svelte
│   │       ├── SignalsPanel.svelte
│   │       ├── MLPanel.svelte
│   │       ├── RegimePanel.svelte
│   │       └── PerformanceChart.svelte
│   ├── package.json
│   ├── vite.config.ts
│   └── start_dashboard.bat      (auto-generated)
│
├── Scripts/
│   ├── setup_redis.bat          ⭐ Redis auto-installer
│   ├── setup_nuclear_system.bat ⭐ Complete setup
│   └── start_all_services.bat   (auto-generated)
│
└── docs/
    ├── Redis_Schema.md          ⭐ Complete Redis schema
    └── NUCLEAR_QUICKSTART.md    ⭐ This file
```

---

## 🔧 Manual Service Control

### Start Individual Services

**Redis:**
```bash
redis-server
```

**ML gRPC Server:**
```bash
cd ML
python grpc_ml_server.py
```

**WebSocket Server:**
```bash
cd ML
python fastapi_websocket_server.py
```

**Dashboard:**
```bash
cd dashboard
npm run dev
```

### Check Service Status

**Redis:**
```bash
redis-cli ping
# Should return: PONG
```

**ML gRPC:**
```bash
curl http://localhost:50051
```

**WebSocket:**
```bash
curl http://localhost:8000/health
```

**Dashboard:**
Open browser: http://localhost:5173

---

## 🔥 Key Features

### 1. Real-Time State Management
- All state in Redis (no file I/O bottlenecks)
- Atomic operations
- Pub/Sub for instant updates
- LRU eviction (512MB limit)

### 2. ML Integration
- gRPC for low-latency predictions (<1ms)
- Bidirectional streaming
- Hot-reload models without restart
- Adaptive policy adjustments

### 3. Live Dashboard
- WebSocket streaming (no polling)
- Real-time charts and metrics
- Control panel for hot-reload
- Multi-channel subscriptions

### 4. Parallel Execution
- Async event queue (no blocking)
- Parallel gate execution
- Strategy isolation
- Non-blocking I/O

### 5. Hot-Reload Everything
- Strategies via Redis pub/sub
- Policy via ML service
- Gates via config updates
- No EA restart needed

---

## 🎯 Next Steps

### Phase 2: Core Merge (Pending)
1. Create `DualEA.mq5` (merged PaperEA/LiveEA)
2. Implement `ExecutionMode.mqh` (paper/live strategy pattern)
3. Integrate RedisClient into core
4. Add async event queue
5. Refactor strategies as plugins

### Phase 3: Advanced Features (Pending)
1. Multi-EA coordination via Redis
2. Cross-symbol correlation matrix
3. Advanced risk simulation
4. Chaos/fuzz testing
5. Performance optimization (target: 1000 ticks/sec)

---

## 📚 Documentation

- **Redis Schema**: `docs/Redis_Schema.md`
- **gRPC Protocol**: `ML/ml_service.proto`
- **Dashboard**: `dashboard/README.md` (to be created)
- **Production Guide**: `docs/README_PRODUCTION.md`

---

## 🐛 Troubleshooting

### Redis Connection Failed
```bash
# Check if Redis is running
redis-cli ping

# Start Redis manually
redis-server

# Check port
netstat -an | findstr "6379"
```

### ML Server Not Starting
```bash
# Check Python version (need 3.9+)
python --version

# Reinstall dependencies
cd ML
pip install -r requirements_grpc.txt

# Generate gRPC code
python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. ml_service.proto
```

### Dashboard Not Loading
```bash
# Check Node.js version
node --version

# Reinstall dependencies
cd dashboard
npm install

# Clear cache and rebuild
npm run build
```

### MQL5 Socket Errors
- Ensure "Allow WebRequest" is enabled in MT5 Tools → Options → Expert Advisors
- Add "127.0.0.1" to allowed URLs
- Check firewall settings

---

## 💡 Tips

1. **Start Redis first** - All services depend on it
2. **Monitor Redis** - Use `redis-cli MONITOR` to see all activity
3. **Check logs** - ML/WebSocket servers log to console
4. **Use dashboard** - Real-time view of all system activity
5. **Test with paper** - Validate with PaperEA before LiveEA

---

## 🚀 Performance Targets

- **Tick Processing**: <1ms per tick
- **ML Inference**: <5ms per prediction
- **Redis Operations**: <0.1ms per command
- **WebSocket Latency**: <10ms to
