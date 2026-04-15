# Python ML Pipeline Integration Guide

## Overview

The DualEA Python ML pipeline has been fully integrated. Previously orphaned modules are now properly connected and accessible through the unified `ML` package.

## Integration Status

### Previously Orphaned → Now Integrated ✅

| Module | Previous Status | Current Integration | Usage |
|--------|----------------|-------------------|-------|
| `shadow_executor.py` | Standalone script | `ML.start_shadow_executor()` | Shadow trading on demo |
| `feature_export.py` | Standalone functions | `ML.write_batches_to_parquet()` | Protobuf → Parquet |
| `feature_export_dll.py` | Unreferenced | `ML.export_feature_batch()` | DLL export |
| `delta_ingest.py` | Standalone script | `ML.ingest_to_delta()` | Delta Lake ingestion |
| `online_learner.py` | Partially used | `ML.OnlineLearner` | Incremental learning |
| `continuous_trainer.py` | Standalone script | `ML.run_full_pipeline()` | Automated retraining |

## Quick Start

### Import All Modules

```python
from ML import (
    # Core training
    train,
    NewsFetcher,
    export_policy,
    
    # Previously orphaned - now integrated
    write_batches_to_parquet,
    ingest_to_delta,
    OnlineLearner,
    start_shadow_executor,
    run_full_pipeline
)
```

### Use Integration Runner

```bash
# Run full pipeline with all services
python -m ML.integration_runner --mode all-services \
    --account 123456 --password secret --server broker-Demo

# Run single service
python -m ML.integration_runner --mode shadow \
    --account 123456 --password secret --server broker-Demo

# Run feature export service
python -m ML.integration_runner --mode feature-export
```

## Module Details

### 1. Shadow Executor (`shadow_executor.py`)

**Purpose:** Execute trades on demo account to shadow live trading

**Integration:**
```python
from ML import start_shadow_executor

# Start shadow trading
start_shadow_executor(
    demo_account=123456,
    demo_password='secret',
    demo_server='broker-Demo'
)
```

**Features:**
- Reads orders from `DualEA/shadow/orders_pending.csv`
- Executes on MT5 demo account
- Records results to `DualEA/shadow/shadow_results.csv`
- Calculates R-multiples for performance tracking

**Files Used:**
- Input: `orders_pending.csv`
- Output: `orders_executed.csv`, `shadow_results.csv`

### 2. Feature Export (`feature_export.py`)

**Purpose:** Convert protobuf feature batches to Parquet format

**Integration:**
```python
from ML import write_batches_to_parquet

# Export protobuf bytes to Parquet
with open('features.pb', 'rb') as f:
    pb_bytes = f.read()

output_path = write_batches_to_parquet(pb_bytes, fname='features.parquet')
```

**Features:**
- Converts `FeatureBatchEnvelope` protobuf to PyArrow
- Writes compressed Parquet files
- Automatic retry with CSV fallback
- Batch processing support

**Configuration:**
```python
# Default export directory
EXPORT_DIR = r"C:\DualEA_FeatureBatches"
```

### 3. Delta Lake Ingestion (`delta_ingest.py`)

**Purpose:** Ingest Parquet files to Delta Lake for analytics

**Integration:**
```python
from ML import ingest_to_delta

# Ingest all Parquet files to Delta Lake
ingest_to_delta()
```

**Features:**
- Discovers all `.parquet` files in feature directory
- Appends to Delta Lake table
- Schema evolution support
- Time travel capabilities

**Configuration:**
```python
FEATURE_DIR = r"C:\DualEA_FeatureBatches"
DELTA_DIR = r"C:\DualEA_DeltaLake"
```

### 4. Online Learner (`online_learner.py`)

**Purpose:** Incremental model updates as trades complete

**Integration:**
```python
from ML import OnlineLearner

# Initialize online learner
learner = OnlineLearner(
    model_type='classifier',
    learning_rate=0.01
)

# Update with new trade
learner.partial_fit(features, outcome)

# Get updated predictions
probability = learner.predict(features)
```

**Features:**
- SGDClassifier/SGDRegressor for online learning
- Keras model support (if available)
- Automatic feature scaling
- Model versioning

### 5. Integration Runner (`integration_runner.py`)

**Purpose:** Unified service manager for all ML infrastructure

**Usage:**
```bash
# Run all services
python -m ML.integration_runner --mode all-services

# Available modes:
# - full-pipeline: Single training run
# - shadow: Shadow executor only
# - feature-export: Feature export service
# - delta-ingest: Delta Lake ingestion
# - continuous-train: Continuous retraining
# - news-fetch: Economic calendar updates
# - all-services: Everything in parallel
```

**Service Architecture:**
```
┌─────────────────────────────────────────────────────────────┐
│                    Service Manager                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ Shadow Executor  │  │ Feature Export   │                │
│  │ (MT5 Demo)       │  │ (Protobuf→Parq)  │                │
│  └──────────────────┘  └──────────────────┘                │
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ Delta Ingest     │  │ Continuous Train │                │
│  │ (Delta Lake)     │  │ (Auto-retrain)   │                │
│  └──────────────────┘  └──────────────────┘                │
│                                                             │
│  ┌──────────────────────────────────────────┐              │
│  │           News Fetcher                    │              │
│  │    (Economic Calendar Updates)          │              │
│  └──────────────────────────────────────────┘              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Package Structure

```
ML/
├── __init__.py              # Package initialization, exports all modules
├── integration_runner.py    # Master service manager
│
├── Core Training
├── train.py
├── model.py
├── features.py
├── dataset.py
├── policy.py
├── policy_export.py
│
├── Advanced Models
├── model_pytorch.py
├── model_ensemble.py
├── train_pytorch.py
├── train_neurobook.py
│
├── Previously Orphaned (Now Integrated)
├── shadow_executor.py       # ✅ Integrated via ML.start_shadow_executor()
├── feature_export.py        # ✅ Integrated via ML.write_batches_to_parquet()
├── feature_export_dll.py    # ✅ Integrated via ML.export_feature_batch()
├── delta_ingest.py          # ✅ Integrated via ML.ingest_to_delta()
├── online_learner.py        # ✅ Integrated via ML.OnlineLearner
├── continuous_trainer.py    # ✅ Integrated via ML.run_full_pipeline()
│
├── Infrastructure
├── news_fetcher.py          # ✅ Integrated via ML.NewsFetcher
├── experiment_runner.py
├── feature_store.py
├── feedback_watcher.py
├── gate_optimizer.py
├── policy_server.py
│
└── Advanced Training
    ├── snapshot_train.py
    ├── snapshot_dataset.py
    ├── snapshot_policy_export.py
    └── simple_optimizer.py
```

## Full Pipeline Example

```python
from ML import run_full_pipeline, start_shadow_executor, NewsFetcher

# 1. Run full training pipeline
result = run_full_pipeline(
    common_dir='DualEA',
    epochs=50,
    batch_size=32,
    min_conf=0.55,
    use_news=True
)

print(f"Training complete: {result['files']['policy']}")

# 2. Start shadow executor for validation
start_shadow_executor(
    demo_account=123456,
    demo_password='secret',
    demo_server='broker-Demo'
)

# 3. Fetch economic calendar
fetcher = NewsFetcher()
fetcher.fetch_from_mql5_calendar()
fetcher.generate_blackout_csv()
```

## Configuration

### Environment Variables

```bash
# MT5 Common Files directory
export DUALEA_COMMON_DIR="C:/Users/.../Common/Files/DualEA"

# Feature export directory
export DUALEA_FEATURE_DIR="C:/DualEA_FeatureBatches"

# Delta Lake directory
export DUALEA_DELTA_DIR="C:/DualEA_DeltaLake"

# Shadow executor credentials (optional)
export DUALEA_DEMO_ACCOUNT="123456"
export DUALEA_DEMO_PASSWORD="secret"
export DUALEA_DEMO_SERVER="broker-Demo"
```

### Default Paths

All modules use sensible defaults that can be overridden:

```python
from pathlib import Path
import os

# Common Files (auto-detected)
DEFAULT_COMMON_DIR = os.path.join(
    os.environ.get("APPDATA", ""),
    "MetaQuotes", "Terminal", "Common", "Files", "DualEA"
)

# Feature Batches
EXPORT_DIR = r"C:\DualEA_FeatureBatches"

# Delta Lake
DELTA_DIR = r"C:\DualEA_DeltaLake"

# Shadow Orders
PENDING_ORDERS_FILE = Path("DualEA/shadow/orders_pending.csv")
EXECUTED_ORDERS_FILE = Path("DualEA/shadow/orders_executed.csv")
RESULTS_FILE = Path("DualEA/shadow/shadow_results.csv")
```

## Service Mode Operation

### Docker-Style Service Management

```python
from ML.integration_runner import ServiceManager

# Create manager
manager = ServiceManager()

# Start services
manager.start_service('shadow', start_shadow_executor, account, password, server)
manager.start_service('features', run_feature_export_service, poll_dir, output_dir)
manager.start_service('delta', run_delta_ingest_service, interval)

# Get status
status = manager.get_status()
print(status)

# Stop all
manager.stop_all()
```

### Background Execution

```bash
# Run as background service
nohup python -m ML.integration_runner --mode all-services > integration.log 2>&1 &

# Check status
tail -f integration.log

# Stop gracefully
kill -INT <pid>
```

## Troubleshooting

### Issue: `ModuleNotFoundError: No module named 'ML'`

**Fix:** Ensure you're running from the correct directory:
```bash
cd MQL5/Experts/Advisors/DualEA
python -m ML.integration_runner --help
```

### Issue: `ImportError: No module named 'MetaTrader5'`

**Fix:** Install MT5 package or use shadow mode offline:
```bash
pip install MetaTrader5
# OR
python -m ML.integration_runner --mode feature-export  # No MT5 needed
```

### Issue: Delta Lake not available

**Fix:** Install deltalake or skip:
```bash
pip install deltalake
# OR
python -m ML.integration_runner --mode all-services --no-delta
```

### Issue: Feature export not finding protobuf files

**Fix:** Check directory structure:
```python
from pathlib import Path
poll_dir = Path("DualEA/protobuf_pending")
print(f"Looking in: {poll_dir.absolute()}")
print(f"Files found: {list(poll_dir.glob('*.pb'))}")
```

## Migration from Standalone Scripts

### Before (Standalone)

```python
# shadow_executor.py - standalone
import MetaTrader5 as mt5
# ... all logic in one file
# had to be run separately
# no integration with training pipeline
```

### After (Integrated)

```python
from ML import start_shadow_executor

# Part of unified package
# Can be called from training pipeline
# Shares configuration
# Managed by ServiceManager
start_shadow_executor(account, password, server)
```

## API Reference

### Core Functions

```python
# Run complete pipeline
ML.run_full_pipeline(common_dir, epochs, batch_size, min_conf, use_news)

# Start shadow executor
ML.start_shadow_executor(account, password, server)

# Export features to Parquet
ML.write_batches_to_parquet(pb_bytes, fname)

# Ingest to Delta Lake
ML.ingest_to_delta()

# Fetch news calendar
ML.NewsFetcher().fetch_from_mql5_calendar()

# Online learning
ML.OnlineLearner().partial_fit(X, y)
```

### Classes

```python
# Ensemble models
ML.EnsembleModel(models)

# Experiment runner
ML.ExperimentRunner(base_dir)

# Feature store
ML.FeatureStore()

# Policy management
ML.Policy(version, timestamp, min_confidence)
```

## Related Documentation

- [NewsFilter_Integration_Guide.md](NewsFilter_Integration_Guide.md) - News system
- [README.md](README.md) - Main documentation
- [ML/README.md](ML/README.md) - ML pipeline overview

---

**Integration Complete:** All previously orphaned Python modules are now properly integrated into the unified `ML` package.
