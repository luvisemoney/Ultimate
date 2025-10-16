# DualEA - Production Multi-Strategy Trading System

**Paper EA + Live EA with ML Policy Engine**

## System Overview

**DualEA** is a production-ready, multi-strategy Expert Advisor ecosystem for MetaTrader 5 that combines:

1. **PaperEA_v2** - Advanced paper trading system with 8-stage gate filtering, 21 strategies, ML integration
2. **LiveEA** - Real trading implementation consuming insights and ML policies from PaperEA
3. **ML Pipeline** - Python-based TensorFlow/Keras training with LSTM models and policy export
4. **Knowledge Base** - Shared CSV/JSON data store in Common Files for cross-system communication

## Core Architecture

```
MQL5/
├── Experts/
│   └── Advisors/
│       └── DualEA/
│           ├── PaperEA/                # Paper Trading System
│           │   ├── PaperEA_v2.mq5     # Enhanced Paper EA with 8-stage gates
│           │   └── PaperEA_backtest.ini
│           ├── LiveEA/                 # Live Trading System  
│           │   ├── LiveEA.mq5         # Live EA with advanced gating
│           │   ├── build_liveea.bat
│           ├── Include/                # Core System Components
│           │   ├── Strategies/         # Strategy Implementations
│           │   ├── Indicators/         # Technical Indicators
│           │   └── Managers/           # System Managers
│           ├── ML/                     # Machine Learning Pipeline
│           ├── Scripts/                # Utility Scripts
│           ├── docs/                   # Documentation
│           ├── config/                 # Configuration
│           └── build_*.bat             # Build scripts
```

## Key Features

### 8-Stage Gate System
1. **Signal Rinse**: Basic signal validation and confidence filtering
2. **Market Soap**: Market context analysis (volatility, correlation, regime)
3. **Strategy Scrub**: Strategy-specific validation and parameter adjustment
4. **Risk Wash**: Risk-based position sizing and validation
5. **Performance Wax**: Backtest-based performance validation
6. **ML Polish**: Machine learning confidence scoring
7. **Live Clean**: Live market condition validation
8. **Final Verify**: Final trade validation before execution

### Strategy Library (21 Active Strategies)

- **Trend Following**: ADXStrategy, SuperTrendADXKamaStrategy, DonchianATRBreakoutStrategy
- **Mean Reversion**: BollAveragesStrategy, MeanReversionBBStrategy, RSI2BBReversionStrategy
- **Momentum**: AwesomeOscillatorStrategy, AcceleratorOscillatorStrategy, KeltnerMomentumStrategy
- **Multi-Asset Specialized**: GoldVolatilityStrategy, IndicesEnergiesStrategy

## Getting Started

### Prerequisites

- Windows operating system
- MetaTrader 5 with MetaEditor installed
- Python 3.7+ for ML pipeline

### Quick Start

1. **Paper Trading Setup**:
   ```bash
   # Attach PaperEA/PaperEA_v2.mq5 to a chart
   # Set NoConstraintsMode=true for maximum data collection
   ```

2. **Generate Insights**:
   ```bash
   # Run Scripts/InsightsRebuild.mq5 to create insights.json
   ```

3. **Train ML Model**:
   ```bash
   cd ML
   run_train_and_export.bat
   ```

4. **Live Trading**:
   ```bash
   # Attach LiveEA/LiveEA.mq5 to a chart
   # Set UsePolicyGating=true and UseInsightsGating=true
   ```

## Documentation

For complete documentation, see the [docs](docs/) directory which contains:

### Core Documentation
- [README_PRODUCTION.md](docs/README_PRODUCTION.md) - Quick reference for production deployment
- [Configuration-Reference.md](docs/Configuration-Reference.md) - Complete guide to all input parameters
- [Execution-Pipeline.md](docs/Execution-Pipeline.md) - Detailed execution flow
- [Observability-Guide.md](docs/Observability-Guide.md) - Telemetry and monitoring

### System Components
- [Policy-Exploration-Guide.md](docs/Policy-Exploration-Guide.md) - ML policy gating and exploration
- [Phase-Implementation.md](docs/Phase-Implementation.md) - Development roadmap
- [KB-Schemas.md](docs/KB-Schemas.md) - Data schemas
- [Operations.md](docs/Operations.md) - Operational procedures

### Technical Guides
- [PaperEA_README.md](docs/PaperEA_README.md) - Paper trading system
- [LiveEA_README.md](docs/LiveEA_README.md) - Live trading system
- [UnifiedSystemGuide.md](docs/UnifiedSystemGuide.md) - Unified architecture
- [PositionManager_Guide.md](docs/PositionManager_Guide.md) - Position management

## Building

Use the provided build scripts:
- `build_all.bat` - Build entire project
- `PaperEA/build_paperea.bat` - Build PaperEA
- `LiveEA/build_liveea.bat` - Build LiveEA

## License

Copyright 2025, Windsurf Engineering.

This project is proprietary and confidential. Unauthorized copying or distribution is prohibited.
