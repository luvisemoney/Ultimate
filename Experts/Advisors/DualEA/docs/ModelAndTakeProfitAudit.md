# Model and take-profit audit

## Phase 1: codebase and requirements
### Cycle 1: structural audit
The deployed model is the native MQL5 logistic trainer in `Tests/Train_MarketModel.mq5`, exported into ONNX by the existing build/export scripts. The legacy Python files are not evidence that the active model uses Yahoo, LSTMs, 50 technical indicators, random splits or realized account P&L.

`Include/CMarketModelFeatures.mqh` constructs 12 completed-bar price/time/direction features and four interactions for each of 23 symbols: 104 inputs total. The trainer labels both directions using the log return from the decision bar's open to the open four bars later, after recorded spread. Features end at the preceding closed bar. Targets crossing a split boundary are purged. Scaling is fitted on training rows only. Recorded H1 spread is a historical execution-cost proxy, not an exact tick-level fill quotation; commission and slippage are zero in this training target.

### Cycle 2: requirements mapping
`Include/TradeManager.mqh::ExecuteOrder` already creates fallback protection and rejects missing SL/TP before submitting normal EA orders. `Tests/Benchmark_UniversalONNX.mq5` intentionally uses an SL and a four-hour timed exit without TP. That benchmark refuses use outside Strategy Tester and is separate from PaperEA.

The screenshot alone does not establish `POSITION_TP=0`: a target above the chart's visible range would also lack a visible line. No matching entry record was found in this terminal's available October 28 logs, so the screenshot's specific position cannot be attributed to a module or claimed repaired. Its ticket, magic, comment and actual server TP are needed. `Scripts/Inspect_PositionProtection.mq5` is a read-only inspector that reports these fields and whether the TP lies inside the current chart range. It sends no trade requests. No existing account position was modified by this repair.

### Cycle 3: risk closure
A real defect was found in all four trailing branches: after selecting a position by ticket, they called `PositionModify(symbol,...)`. On hedging accounts that overload selects the lowest-ticket position. A later position could therefore write its TP onto a different position, including overwriting an existing TP with zero if the selected source position had none. Each call now passes the selected ticket. This is a demonstrated code defect, not proof of the screenshot's cause.

## Phase 2: implementation and validation
### Cycle 1: task decomposition
1. Preserve per-ticket protection during trailing updates.
2. Reject non-finite entry protection and log the server-retained SL/TP after a fill.
3. Independently reproduce model scores and saved metrics from all real dataset rows.
4. Separate verified causes, plausible limitations and unsupported claims.

### Cycle 2: implementation and review
`TradeManager.mqh` now uses ticket-based modification, rejects non-finite SL/TP at the final order guard and emits `[POSITION-PROTECTION]` with requested and server-observed prices for the filled position identifier. A missing server-side level raises `[PROTECTION-WARNING]`; it does not report an already-filled order as unsent, trigger a duplicate order or silently rewrite a position.

`ML/ModelDiagnostics.cs` independently reconstructs the 104-input standardized score from the compact real dataset, including inactive symbol zeros. `ML/Audit-ModelDiagnostics.ps1` requires each split's reproduced AUC to agree with saved metrics within 1e-10. Its output is `ML/artifacts/universal/diagnostic-audit.json`. It also reports per-symbol, per-direction and daily cohorts, probability ranges and seeded shuffled-label controls. The controls shuffle labels for fixed predictions; they are a scoring sanity check, not a retrained leakage audit.

### Cycle 3: quantitative findings

| Split | Rows | Reproduced AUC | Predictions >=0.55 | Maximum probability |
|---|---:|---:|---:|---:|
| Train | 380,892 | 0.533583 | 2,369 | 0.827243 |
| Validation | 44,296 | 0.533221 | 172 | 0.622849 |
| Test | 22,036 | 0.515794 | 95 | 0.590600 |

Test accuracy is 51.393%, below the 51.783% majority baseline. Test log loss is 0.692259 versus the training-prior baseline 0.692516: a small improvement, not evidence of economic profitability. Five fixed-score shuffled-label AUCs range from 0.497613 to 0.504887, as expected for chance-like ranking. They need not equal exactly 0.5.

Test cohorts vary materially: EURUSD AUC 0.460764, GBPUSD 0.464048, USDCHF 0.599795 and WTI 0.596134. These are the already-inspected September cohorts, not independently validated symbol-selection rules. Daily pooled AUC ranges from 0.394162 to 0.683036 across 30 days; daily cohorts differ in symbol composition and are not independent confidence intervals. Adjacent four-hour labels overlap and paired directions share price paths, so 22,036 rows do not mean 22,036 independent market outcomes.

The model captures little stable ranking information from this short price-only window. The train-to-test drop is consistent with changing relationships and weak generalization, but this audit does not identify a single exclusive cause. Its linear score has limited conditional interactions; no historical news, volume, regime, order book or strategy identity enters this contract. Removing all costs from labels would change the objective, not automatically improve trading. Correlation alone does not prove PCA is needed, and monotonic calibration cannot create ranking information that is absent.

Another concrete mismatch is the objective: positive four-hour terminal return is not the same event as reaching an individual strategy's TP before SL. The model is not a TP/SL first-hit classifier. The EA's configured default G6 threshold is 0.55; only 0.431% of these test rows reach that raw-score level. This is not the actual acceptance rate: `CMLPolishGateEnhanced` also penalizes confidence by volatility and dynamically lowers the threshold to 0.495 in its low-volatility branch (or raises it in high volatility). Candidate filtering, optimizer adjustments and runtime settings further differ. Threshold coverage does not explain the low AUC itself. No threshold was lowered by this repair to manufacture trades.

## Phase 3: documentation and operating limits
### Cycle 1: compiler compatibility
The pending `Include/Tools/DateTime.mqh` method-hiding failure was present and is repaired: its MqlDateTime setter copies all eight fields explicitly. `Include/Controls/DateDropList.mqh` delegates to that setter. Derived-to-derived assignment remains supported. This avoids converting through datetime and preserves calendar metadata. `Tests/Test_DateTimeCompatibility.mq5` exercises leap-day date/time fields, metadata, derived copies and the drop-list setter.

### Cycle 2: regression evidence
MetaEditor compiled the date test, TP test, feature test, native parity test, read-only inspector and PaperEA with zero errors and zero warnings. The date test passed 5 checks. The TP regression creates two same-symbol tester positions with distinct targets, forces the fixed trailing branch, then verifies each server target and improved SL by ticket: 11 checks passed. Its first attempt received market-closed rejections at rollover; the test was corrected to begin during the active session. These orders are simulated Strategy Tester orders only.

`Audit-MarketDataset.ps1` revalidated all 447,224 real rows, paired directions, four-hour target horizons, purged chronological boundaries and training-only scaling. The independent model audit reproduced all three saved AUCs. The dashboard now exposes these split metrics and the low threshold-coverage count rather than equating ONNX loading with predictive quality. Recompiling a file does not prove that an already attached chart has reloaded it.

Final native validation also passed 38 causal-feature checks and 1,767 parity checks (maximum probability error 3.821692052e-08). A fresh actual-PaperEA EURUSD H1 M1-OHLC run over October 1–28 exclusive produced 18 completed trades and 18 server-observed protection records; every record retained a positive SL and TP. Net result remained -10.72, profit factor 0.632373. Maximum observed handler duration was 4.219 ms over 106,978 completions, with no warning or critical exceedances. These are historical observations, not a live latency guarantee or profitability proof. Logs: `Tests/Tester/model-evidence/paper_tp_audit-agent.log`, `take_profit_preservation-agent.log`, `date_compatibility-agent.log`, `market_features_audit-agent.log`, `parity_audit-agent.log`.

The rebuilt EA subsequently passed all eight October 5–7 H1 M1-OHLC integration cases: 378 classification events, nine simulated entry-request records, 89,570 handler completions, maximum observed handler 5.483 ms and zero critical exceedances. Unsupported symbols and M15 were rejected as expected. The refreshed `integration-verification.json` links this evidence to the rebuilt executable hash. This broader test does not convert the negative month-long economics into a positive result.

### Cycle 3: five research recommendations
1. Align candidate labels with the intended exit rule: compare terminal returns with cost-aware TP/SL first-hit outcomes. Resolve same-bar barrier ambiguity using finer history or flag it; never invent the hit order.
2. Use rolling, timestamp-grouped temporal folds across all symbols, purging at least the label horizon. Reserve a fresh final window: September and the October benchmarks have already been inspected.
3. Compare modest nonlinear and regime-conditioned candidates against the fixed logistic baseline. Fit scalers, PCA if justified, feature selection and hyperparameters inside training folds only.
4. Add news only with point-in-time historical availability and target/currency relevance. Today's collected headlines cannot be backfilled into past rows as if they were known then.
5. Evaluate calibration and costs on a separate chronological window; require stable per-symbol economic results and risk limits. Neither AUC >0.52 nor >0.55 alone proves tradable edge.

## Review Q&A and adversarial trace
- Q: Is the model failing to load or silently returning random numbers? A: The independent score reconstruction reproduces saved metrics; native parity is separately tested. This is weak predictive performance, not evidence of a random fallback.
- Q: Must labels exclude transaction costs? A: No. The label should match the research objective and use defensible cost estimates; predicting gross movement and evaluating net economics is another valid experiment.
- Q: Would full-dataset z-scoring, qcut and PCA fix leakage? A: Fitting those transforms on future validation/test data introduces leakage. The pasted example must not be copied as-is.
- Q: Did we fix the pictured position? A: Its actual server TP remains unverified. The demonstrated hedging defect is repaired and tested; the open account position was left untouched.
- Expert rebuttal: choosing only the symbols whose September AUC exceeded 0.55 after looking at that month is model selection on the test set, not independent confirmation.
- Controlled boundary trace: two hedged positions with different targets, forced immediate trailing activation in a tester-only EA, invalid protection guard, leap-day metadata and seeded shuffled-label scoring. No fabricated training samples or gate-acceptance labels were introduced.

Sources: [MetaQuotes PositionModify hedging behavior](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionmodify), [MetaQuotes CDateTime setter](https://www.mql5.com/en/docs/standardlibrary/controls/cdatetime/cdatetimedatetime), [scikit-learn time-series validation](https://scikit-learn.org/stable/modules/cross_validation.html#time-series-split), [probability calibration](https://scikit-learn.org/stable/modules/calibration.html).
