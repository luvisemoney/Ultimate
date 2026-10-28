# PaperEA runtime repair and Strategy Tester validation

## Result
All eight final Strategy Tester cases passed. PaperEA and affected examples/tests compile with zero errors and zero warnings. The full-EA USDCHF H1 smoke test ran from 2025-10-01 through 2025-10-07 (ToDate 2025-10-08), using M1 OHLC generation, a USD 10,000 deposit, and 0.01 fixed lots. It completed 28,200 generated ticks / 120 H1 bars without runtime exceptions or shutdown pointer errors.

This verifies the tested behavior, not profitability: 21 trades, net P&L -$47.73, final balance $9,952.27, profit factor 0.07, maximum equity drawdown $61.49 (0.61%). All 21 entry requests and broker-normalized volumes were exactly 0.01 lots. A repeated clean-data smoke run reproduced those figures.

[Machine-readable results](../Tests/Tester/evidence/results.json) · [MT5 HTML report](../Tests/Tester/evidence/smoke-report.htm) · [Build hashes](../Tests/Tester/evidence/build-manifest.json)

![Actual Strategy Tester balance curve](../Tests/Tester/evidence/smoke-report.png)

## Phase 1 — Inspection and requirements
### Cycle 1 — Structural findings
The supplied executive summary overstated its evidence: OrderSend retcode 10009 proves an executed request, not a real-money account. The existing terminal startup log explicitly identifies a demo account. PaperEA's own comments describe demo order execution. Missing account enforcement was nevertheless a real defect.

### Cycle 2 — Requirement mapping
PaperEA must reject real/contest accounts, honor disabled/shadow execution, preserve failed gate decisions, respect explicit lot sizes, and never silently replace a failed strategy with a differently named moving-average trade. Requested model inference must fail closed when its model is unavailable. Tester data must not contaminate live learning files.

### Cycle 3 — Infrastructure gaps
The DLL preprocessor check used MQL_TESTER as though it were a compile-time macro. It is a runtime enum. No compatible production signal_model.onnx and matching configuration were available. The actual Common CSV has UTF-16 headers strategy_id/profit/stop_loss/take_profit, and contains no trade rows. WebRequest is unavailable in Strategy Tester regardless of URL whitelist settings.

## Phase 2 — Implementation and verification
### Cycle 1 — Execution and dependencies
- PaperEA_v2.mq5 and PaperExecutionSafety.mqh: demo/tester account predicate at startup and both execution routes; shadow/disabled enforcement; NoConstraintsMode defaults false; mandatory exposure cap; explicit risk sizing for LotSize=0; fixed lot preservation; no strategy relabeling fallback; requested model failures block initialization/signals.
- TradeManager.mqh: final per-instance demo guard, disabled/shadow trailing guard, zero/invalid volume rejection, broker retcode validation. No imaginary shadow fills.
- EnhancedEfficientGateSystem.mqh and AdaptiveSignalOptimizer.mqh: return actual gate pass state; preserve mandatory gates under bypass modes; treat unevaluated budget-skipped validation as a failure; populate original fields and gate outcomes; preserve order type/confidence during decision copying; remove implicit 0.1-lot substitution.
- ModelPredictor.mqh: native MT5 ONNX replaces DLL imports. Model/scaler/tensor/probability validation returns explicit failures. No Visual Studio workload or VC++ runtime installation is required for this native path.
- PolicyHttpBridge.mqh and PaperEA: tester file policy path avoids HTTP; content-based freshness detects same-length edits; failed downloads preserve existing policies.
- RuntimeStorage.mqh and shared I/O headers: tester files/databases are agent-local; normal terminal Common Files behavior remains.
- CSQLiteKnowledgeBase.mqh: actual CSV aliases and encoding support; preserve close outcomes and formatted times; repeated preload suppression.

### Cycle 2 — Failures found by actual testing
The first executable smoke run crashed on UnifiedTradeLogger.mqh:235. An uninitialized journey_length indexed beyond a fixed 24-element array. The repair initializes records, bounds serialization, writes complete UTF-8 JSON atomically, preserves records on append, and replaces the exact trade on close. Tests cover escapes, malformed documents, and cross-midnight closes.

Review also found double-deletion of the master-owned position manager/system monitor through global aliases. Cleanup now has one owner, clears aliases, and releases the exploration counter. Tester scoring uses MT5's actual ENUM_STATISTICS and safely handles zero trades.

### Cycle 3 — Final test matrix
| Case | Final result | Evidence |
|---|---|---|
| Full PaperEA, USDCHF H1, Oct 1–8 2025 | PASS; 21 simulated trades, clean shutdown | smoke-agent.log / smoke-report.htm |
| Native/canonical CSV import | PASS; encoding, dates, quotes, P&L, duplicate handling | csv-agent.log |
| Native ONNX contract | PASS; 19 checks including actual inference | native-agent.log |
| Account/enabled/shadow matrix | PASS; 28 checks | safety-agent.log |
| Mandatory gates in all five modes, zero volume | PASS; 26 checks | gates-agent.log |
| Logger formatting and file lifecycle | PASS; 17 checks | logger-agent.log |
| Full EA shadow mode | PASS; zero order attempts | shadow-agent.log / shadow-report.htm |
| Requested ONNX model missing | PASS; expected initialization rejection, zero order attempts | missing_model-agent.log |

All logs above are under Tests/Tester/evidence. The runner checks newly appended agent output, assertion markers, runtime exceptions, and fresh reports. A zero terminal exit code alone is not accepted as a test pass. Earlier infrastructure attempts failed for absent account configuration/network restrictions; one terminal auto-update interrupted two cases. Those runs were not counted as successes; the final eight-case suite completed with every case passing.

## Phase 3 — Evidence and operating limits
### Cycle 1 — Reproduction
Tests/Tester/Prepare-PortableTester.ps1 prepares a separate portable terminal. Run-PortableTests.ps1 runs the eight cases and rotates only runtime-local test data. Use powershell.exe -NoProfile -ExecutionPolicy Bypass -File with each script. This changes execution policy for that process only. The current terminal's saved account identifier is resolved locally without printing it. A demo account must be signed into the portable terminal before rerunning; the temporary encrypted account store used during this session was removed afterward. The original terminal was left running and no EA was attached or reloaded on its charts.

The portable tester needed broker network access to synchronize history. Chart trading and DLL imports were disabled. Raw generated *-run.ini files and the temporary account-store copy were removed after validation; sanitized reports/logs remain. Production knowledge_base.csv was inspected read-only and not rewritten.

### Cycle 2 — Boundaries
The ONNX regression uses a clearly synthetic Identity-model fixture to test the inference implementation. It does not validate a trained trading model. With UseOnnxPredictor=true, the EA now refuses to start when its real model/config are missing. The tested heuristic preset explicitly uses UseOnnxPredictor=false, LoadONNXModels=false, and AutoReloadModels=false. For non-tester HTTP policy use, a functioning backend and the user's MT5 WebRequest allowlist are still required; a tester pass cannot validate that service.

The existing strategy_stats table uses a strategy-only key, so independent multi-symbol statistics still need a schema migration. Existing broader learning/optimization modules were not certified as complete. Runtime pass rate is eight of eight tested cases; profitability/production readiness is not established. M1 OHLC does not test real-tick slippage, all broker execution modes, every symbol, or long-run memory growth.

### Cycle 3 — Five next checks
1. Restore a genuine trained ONNX model plus matching feature/scaler metadata, then rerun model-enabled inference and full-EA tests.
2. Validate the actual local policy backend and allowlist outside Strategy Tester; use frozen file policies for historical tests.
3. Migrate strategy statistics to a composite strategy/symbol key before trusting multi-symbol learning.
4. Run real-tick, variable-spread, restart, and rejected-order tests over a longer historical period.
5. Investigate the losing strategy results with out-of-sample data before considering live-account deployment.

## Q&A and review record
Q: Did the original log establish real-money trading? A: No; the saved account was demo. The missing real-account guard was still repaired.
Q: Was compilation sufficient? A: No; real tester execution uncovered the logger crash that compilation could not detect.
Reviewer: A failed gate still returned true. Resolution: actual pass state now propagates; 26 regression checks verify the contract.
Reviewer: Shared global aliases were deleted twice. Resolution: single-owner cleanup and detached aliases; full shutdown completed cleanly.
Q: Does native inference passing mean the trading model is ready? A: No; missing production model assets are explicitly blocked.
No fabricated expert deliberations, exploit traces, or model training results are claimed. No event attendance is involved in this task, so there is no attendance payment to apply for.

## Direct references
- [MetaQuotes: WebRequest cannot run in Strategy Tester](https://www.mql5.com/en/docs/network/webrequest)
- [MetaQuotes: native ONNX execution](https://www.mql5.com/en/docs/onnx/onnxrun)
- [MetaQuotes: tester statistics identifiers](https://www.mql5.com/en/docs/constants/environment_state/Statistics)
- [MetaTrader: startup and tester configuration](https://www.metatrader5.com/en/terminal/help/start_advanced/start)
- [GitHub example inspected for CLI configuration](https://github.com/psyb0t/mt5-httpapi/blob/master/docs/compiling.md)
- [Reddit lifecycle-test discussion; anecdotal, not technical authority](https://www.reddit.com/r/algotrading/comments/1x2k03e/any_tips_on_how_to_migrate_an_ea_from_mql4_to_mql5/)
## Subsequent universal model setup
The missing production-model asset limitation was subsequently resolved. See [UniversalONNXGuide.md](UniversalONNXGuide.md) for the built/installed 23-symbol H1 model, real-history training audit, native parity, actual classification tests, and weak held-out predictive results.

