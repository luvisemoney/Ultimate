# Universal symbol-aware ONNX model — build, setup, and verification

## Delivered result
One trained ONNX model now conditions its classification on the chart symbol. It supports **23 broker symbols on H1**, through MT5's native ONNX runtime. It produces two conditional directional-return scores and the derived states **LONG_BIAS**, **SHORT_BIAS**, or **NO_EDGE**. It does not pretend that an untrained symbol is supported.

The verified bundle is installed in this terminal's local `MQL5/Files/DualEA` and shared `Terminal/Common/Files/DualEA` folders. The default filenames are `signal_model.onnx`, `onnx_config.ini`, and `onnx_config.json`. Existing defaults are backed up under the versioned `DualEA/models/` folders. No chart attachment or order activation is performed by the installer.

**Predictive quality is weak.** September 2026 held-out AUC is **0.515794**, accuracy **51.393%**, compared with **51.783%** for the constant training-prior classifier. Log loss is **0.692259**, compared with **0.692516** for that baseline. These results establish a functioning experimental pipeline, not a profitable trading system.

[Model file](../ML/artifacts/universal/signal_model.onnx) · [Model metadata](../ML/artifacts/universal/onnx_config.json) · [Held-out metrics](../ML/artifacts/universal/metrics.json) · [Dataset audit](../ML/artifacts/universal/dataset_audit.json) · [Native verification](../ML/artifacts/universal/verification.json) · [EA verification](../ML/artifacts/universal/integration-verification.json)

![September 2026 held-out AUC by symbol](../ML/artifacts/universal/heldout_auc.png)

## Supported universe
| Group | Exact broker symbols |
|---|---|
| FX | EURUSD, GBPUSD, USDCHF, USDJPY, USDCAD, AUDUSD, NZDUSD, EURGBP, EURJPY, GBPJPY |
| Metals | XAUUSD, XAGUSD, XAUEUR |
| Indices | AUS200, GER40, NAS100, UK100, US30, US500 |
| Energy | BRENT, WTI |
| Crypto | BTCUSD, ETHUSD |

This is one shared model with symbol-conditioned coefficients, not 23 unrelated model files. Broker suffix aliases and additional symbols require matching training data and a rebuilt bundle. H1 is the only trained timeframe. Unknown symbols and other timeframes stop initialization rather than silently receiving guessed features.

## Phase 1 — Requirements and data inspection
### Cycle 1 — Existing pipeline failures
The previous snapshot trainer could use gate/status acceptance as the target, fit a scaler before temporal splitting, and fabricate bootstrap examples when labels had a single class. Those paths are removed from the supported training entry points. Passing an EA gate is not an observed market outcome.

### Cycle 2 — Target and feature contract
`CMarketModelFeatures.mqh` defines twelve causal completed-H1-bar features. For each supported symbol it adds an identity flag and three symbol-specific interactions. With 23 symbols the model has **104 inputs**. Feature names and order come from the same MQL code during training and runtime.

The target is a positive return over the next four consecutive H1 bars after recorded spread costs. BUY uses entry ask and exit bid; SELL uses entry bid and exit ask. Labels use actual broker history. Missing/open outcomes are not replaced by losses, missing classes are not invented, and future outcomes are never input features. This target is not the probability that a strategy's TP will beat its SL.

### Cycle 3 — Chronological separation
Requested history starts January 2024; the broker history actually used in this build begins **2025-01-01 15:00**. The last decision is **2026-09-30 19:00**, in broker bar-time coordinates.

| Partition | Window | Directional rows |
|---|---|---:|
| Train | Before July 1, 2026 | 380,892 |
| Validation | July–August 2026 | 44,296 |
| Locked test | September 2026 | 22,036 |
| Total | Available history through September 2026 | 447,224 |

Both directions for a symbol/time stay in the same partition. A label's future endpoint must remain strictly before that partition's end. Symbol eligibility uses training data only. Hourly samples have overlapping four-hour targets, so these are correlated observations, not 447,224 independent trades.

## Phase 2 — Implementation and adversarial checks
### Cycle 1 — Rebuilt training commands
- `ML/Build-MarketModel.ps1` compiles/runs the real-history MQL trainer, exports ONNX, preserves the training CSV, and runs shared-feature/native-parity checks.
- `Tests/Train_MarketModel.mq5` fits a deterministic regularized logistic classifier with train-only scaling and fixed hyperparameters. Validation/test outcomes do not select a winner.
- `ML/Export-MarketModel.ps1` exports standard ONNX MatMul/Add/Sigmoid operations and matching metadata; no fabricated model, custom DLL, pickle loading, or Python ML environment is required.
- `ML/train.py`, `snapshot_train.py`, and `snapshot_export_onnx.py` route to the supported native build/export commands. Retired status-label APIs reject calls explicitly.
- `ML/snapshot_dataset.py`, `dataset.py`, and `features.py` reject unknown outcomes or unsafe feature selection. `Audit-MarketDataset.ps1` independently audits the actual CSV and recomputes preprocessing.

The ONNX file is compact because this is a linear logistic model with 104 learned coefficients and an intercept. Its 710-byte size does not mean it is a mock model.

### Cycle 2 — Integration corrections
`PaperEA_v2.mq5` checks the model contract, symbol list, feature order, and timeframe before prediction. It classifies both directions once per fresh H1 bar and logs `[MODEL-CLASSIFY]`. The classifier runs even when no strategy produces an entry signal. Predictions do not manufacture trades or bypass existing strategy/risk gates.

Startup waits for a current bar instead of classifying a stale Friday bar on Monday. Explicit model failures block the requested model path. Old gate-reloader defaults are disabled; the actual inference path uses the verified native model. Tester model files are transferred using `tester_file`; the parity harness embeds the exact real bundle so agent-file cleanup cannot remove its inputs.

### Cycle 3 — Executed verification
| Check | Actual result |
|---|---|
| Shared causal feature fixtures | 38 checks, zero failures |
| Trained/native ONNX parity | 552 samples across all 23 symbols; 1,767 checks, zero failures |
| Maximum probability difference | 3.821692052e-08 |
| Maximum training/runtime feature difference | 2.220446049e-16 |
| Full dataset audit | All 447,224 rows pass target, horizon, split, finite-value, and paired-direction checks |
| Independent train-only scaler recomputation | Maximum difference 3.1361579999611422e-12 |
| Full EA, October 5–7, 2026 | USDCHF, EURUSD, USDJPY, XAUUSD, US500, WTI, BTCUSD, ETHUSD all pass |
| Actual full-EA classification events | 378 |
| Unsupported symbol | EURCAD rejected as expected |
| Unsupported timeframe | M15 rejected as expected |
| Final main EA compilation | Zero errors, zero warnings |

Full-EA checks used M1 OHLC generation and produced zero entry requests; they validate initialization, classification, domain guards, and shutdown, not trading profitability. Reports and sanitized logs are in `Tests/Tester/model-evidence/`. Python compatibility tests exist but were not executed because no Python interpreter is installed. The supported MQL/PowerShell build does not depend on Python.

Model SHA-256: `73e604c067ea197be3f14f093fd13bf7e67c5acdeb1e5a55804855bf4e54b325`.

## Phase 3 — Operation, limits, and roadmap
### Cycle 1 — Observation and reproduction
Use [universal_observe.set](../Tests/Tester/universal_observe.set) on a supported H1 demo chart to observe classifications with order execution disabled. The separate `universal.set` is the tester/demo execution preset. The existing PaperEA account guard rejects real accounts.

One-command rebuild, verification, and installation from the Experts workspace:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Advisors\DualEA\ML\Setup-UniversalModel.ps1
```

Build/export only:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Advisors\DualEA\ML\Build-MarketModel.ps1
```

A custom universe can be provided with `-Symbols 'EURUSD,GBPUSD,XAUUSD,BTCUSD'`. Requested symbols must be real broker names with sufficient history. MT5, its MetaEditor compiler, a saved demo account, and broker-history access are prerequisites. The prepared isolated tester lives under `Tests/Tester/runtime`; `Prepare-PortableTester.ps1` prepares it when needed. The process-only execution-policy flag does not change the machine's policy settings.

The default training dates are explicit and reproducible. Change the trainer's date inputs and the corresponding tester date when intentionally advancing the training window. Do not repeatedly tune against the same locked test period.

### Cycle 2 — What remains unproven
Recorded H1 spread is a proxy for executable tick spreads. Commission/slippage are zero in these labels. Four-hour directional-return classification is not complete strategy P&L or TP/SL-path simulation. Per-symbol held-out results vary; several symbols perform below chance. Model scores are conditional estimates and the NO_EDGE state is derived from a 0.5 threshold, not a separately trained class.

Native parity and EA smoke checks do not establish live-execution quality, long-run stability, calibration, or economic value. The broader historical learning/optimization components are not certified by this model build. No fabricated labels, profits, or statistical confidence are substituted for missing evidence.

### Cycle 3 — Five next checks
1. Add commission, variable spread, and slippage to outcome evaluation before making economic claims.
2. Evaluate the frozen model over additional unseen periods using real-tick strategy tests and actual strategy exits.
3. Check probability calibration and per-symbol performance; do not assume pooled AUC guarantees every symbol works.
4. Expand supported symbols only by adding real broker history, rebuilding metadata, and rerunning parity/domain checks.
5. Train separate, explicitly identified contracts for other timeframes; do not apply this H1 model to M15 or H4.

## Review Q&A
Q: Does the model switch behavior by symbol? A: Yes. The chart symbol selects its trained identity/interactions inside one shared model.
Q: Does every broker symbol work automatically? A: No. The metadata lists 23 supported names; unknown names are rejected.
Q: Were fake bootstrap examples or gate-pass labels used? A: No. The supported trainer uses observed future price/spread outcomes and rejects inadequate training data.
Q: Is it ready to claim profitability? A: No. Held-out ranking is weak and accuracy is below the constant-prior baseline.
Q: Was the installed model the tested model? A: Yes. Native proof, EA proof, and installed files are bound to the same SHA-256, with the tested EA executable hash recorded separately.

## Direct references
- [MetaQuotes: native ONNX execution](https://www.mql5.com/en/docs/onnx/onnxrun)
- [MetaQuotes: tester files and sandbox behavior](https://www.mql5.com/en/book/automation/tester/tester_directives)
- [MetaQuotes: terminal/tester startup configuration](https://www.metatrader5.com/en/terminal/help/start_advanced/start)
- [scikit-learn: chronological splitting and gaps](https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.TimeSeriesSplit.html)
- [GitHub CLI compilation example inspected](https://github.com/psyb0t/mt5-httpapi/blob/master/docs/compiling.md)
- [Reddit leakage discussion; anecdotal, not a technical authority](https://www.reddit.com/r/MachineLearning/comments/1jzwuiz/)
## TickLatency maintenance update
See [TickLatencyFix.md](TickLatencyFix.md). The monitor now measures completed OnTick work instead of quote-arrival gaps; the rebuilt EA and the model integration proof were revalidated across eight symbols.


## Timestamped news context
Headline context is now connected to PaperEA's existing news/filter section, with scheduled blackouts preserved and observation-only defaults. See [NewsSentimentIntegration.md](NewsSentimentIntegration.md). This is separate from the 104-feature ONNX input and does not retrain or alter its probability outputs.
