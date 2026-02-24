# DualEA Documentation Index

**Last Updated**: February 2026  
**System Version**: PaperEA v2 with P0-P5 Advanced Hardening  
**Compilation Status**: ✅ **0 errors, 0 warnings**

---

## 📚 Core Documentation

| Document | Purpose |
|----------|---------|
| **[README.md](README.md)** | Main system overview, architecture, and quick start |
| **[Configuration-Reference.md](Configuration-Reference.md)** | Complete input parameter reference (180+ settings) |
| **[MQL5_Migration_Notes.md](MQL5_Migration_Notes.md)** | MQL5 syntax fixes and migration guide |

---

## 🛡️ System Components

| Document | Purpose |
|----------|---------|
| **[NUCLEAR_IMPLEMENTATION_COMPLETE.md](NUCLEAR_IMPLEMENTATION_COMPLETE.md)** | Nuclear-grade optimization (VaR, Kelly, correlation engine) - **MQL5 Verified** |
| **[ONNX_INTEGRATION_README.md](ONNX_INTEGRATION_README.md)** | ML model integration via ONNX Runtime |
| **[EFFICIENT_GATE_SYSTEM_IMPLEMENTATION.md](EFFICIENT_GATE_SYSTEM_IMPLEMENTATION.md)** | 8-stage gate system architecture |
| **[ENHANCED_STRATEGIES.md](ENHANCED_STRATEGIES.md)** | 23 signal generator strategies |

---

## 🔧 Operational Guides

| Document | Purpose |
|----------|---------|
| **[Observability-Guide.md](Observability-Guide.md)** | Monitoring, telemetry, and health checks |
| **[Operations.md](Operations.md)** | Day-to-day operations and maintenance |
| **[Execution-Pipeline.md](Execution-Pipeline.md)** | Trade execution flow and pipeline |

---

## 📊 Data & Schema

| Document | Purpose |
|----------|---------|
| **[KB-Schemas.md](KB-Schemas.md)** | Knowledge Base CSV schemas |
| **[Redis_Schema.md](Redis_Schema.md)** | Redis data structures for coordination |
| **[PolicySchema.md](PolicySchema.md)** | Policy.json structure and validation |
| **[Policy-Exploration-Guide.md](Policy-Exploration-Guide.md)** | Policy exploration and optimization |
| **[PositionManager_Guide.md](PositionManager_Guide.md)** | Position management internals |

---

## 🚀 Quick Reference

### P0-P5 Priority System
- **P0**: Production Risk (Nuclear Risk Engine, SQLite, Shadow Logging)
- **P1**: Architectural Hardening (Feature Cache, System Monitor, Volatility Exits)
- **P2**: Intelligence (Concept Drift, Auto-Promotion, MTF Gate, Correlation Pruner)
- **P3**: Performance (CPU Budgeting, Ring Buffers, Batch Telemetry)
- **P4**: Evolution (gRPC ML Bridge, Adversarial Fuzzer)

### Key Files
- `PaperEA/PaperEA_v2.mq5` - Main EA (3109+ lines)
- `Include/CDualEAController.mqh` - P0-P5 Master Controller
- `Include/PaperEA_v2_P0P5_Integration.mqh` - Integration layer

### Common Data Locations
```
Terminal/Common/Files/DualEA/
├── features.csv       # Feature data for ML
├── knowledge_base.csv  # Trade execution records
├── insights.json      # Performance analytics
└── policy.json        # ML-generated trading policy
