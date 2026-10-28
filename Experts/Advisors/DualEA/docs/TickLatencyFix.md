# TickLatency: individual-duration enforcement

## Phase 1: audit and requirements
### Cycle 1: structural audit
`Include/CSystemMonitor.mqh` originally averaged five completed-work samples and normally evaluated every five seconds. A single spike could be diluted or detected late.
### Cycle 2: requirement mapping
Individual work above 10 ms must receive an immediate health check; work above 50 ms must trip the existing breaker. Record lifetime maxima and exceedance counts rather than inferring maxima from periodic averages.
### Cycle 3: scope and limits
A duration check detects a violation after the work completes. It cannot interrupt a blocking MT5 API call or provide a hard real-time deadline on Windows. The previous handler may already have sent an order before an overrun is detected. The breaker protects subsequent work under the existing controller policy.

## Phase 2: implementation and validation
### Cycle 1: measurement
`PaperEA/PaperEA_v2.mq5` starts GetMicrosecondCount at OnTick entry. OnTickUpdate records master-controller and P0P5 work. RecordHandlerCompletion then includes the monitor's normal update overhead. Final telemetry bookkeeping and violation-reporting overhead occur after that final stopwatch observation and are explicitly excluded. These are elapsed durations, including scheduling pauses inside the measured interval.
### Cycle 2: enforcement
`Include/CSystemMonitor.mqh` checks the larger of the latest individual work duration and the five-sample average. Above-warning samples bypass the periodic-check delay. The second completion observation independently trips on handler durations above 50 ms, including normal monitoring overhead. Exact 10 ms remains OK; exact 50 ms is warning; 50.001 ms is critical. The 15-minute cooldown remains intact. Lifetime maxima survive history wrap, recovery, and breaker resets; constructing a new monitor begins a new observation session.
### Cycle 3: adversarial tests
`Tests/Test_TickLatency.mq5` covers idle quote gaps, units, warning/critical boundaries, isolated spikes among fast samples, delayed periodic-check timing, history wrap, monitor overhead, retained cooldown, and a measured 60 ms CPU stall. Test-induced critical alerts are expected. `ML/Test-UniversalModel.ps1` requires a final TICK-SLA summary with nonzero samples and rejects any individual handler over 50 ms or critical exceedance, independently of rolling averages. Full logs and machine-readable results are in `Tests/Tester/model-evidence`.

## Phase 3: evidence and operating limits
### Cycle 1: log contract
At deinitialization, `[TICK-SLA]` reports samples, max_work_ms, max_handler_ms, warning_exceedances (>10 ms), and critical_exceedances (>50 ms). Warning counts include critical samples. The summary is session-wide and may be absent following a terminal crash. The tester rejects missing summaries.
### Cycle 2: live-feed assessment
`live_feed_guarantee=UNVERIFIED` is intentional. Strategy Tester validates historical workloads on this machine; it does not certify broker-to-terminal latency, packet delivery, every market tick, future CPU contention, order round trips, or a worst-case execution-time bound. Broker timestamps and local monotonic counters are different clock domains: subtracting them would fabricate network latency. MT5 may coalesce NewTick events when a tick handler is already running. Live qualification requires a separate demo observation session, a defined latency budget and measurement endpoints, synchronized clock evidence for any cross-system timestamps, and representative busy/disconnected periods. No chart was attached and no live trading was enabled for this repair.
### Cycle 3: five next checks
1. Keep new handler work inside the stopwatch scope; profile individual spikes before changing limits.
2. Repeat historical tests with real ticks and volatile sessions; the current integration suite uses M1 OHLC.
3. Collect a multi-session demo observation log on the actual intended terminal/VPS, including busy periods.
4. Specify separate budgets for handler work, feed delivery, quote freshness, and broker acknowledgements.
5. Requalify after broker, machine, VPS, terminal, or EA changes. A passed observation window is evidence, not a permanent latency guarantee.

## Review Q&A and decision trace
- Q: Can averages prove every handler passed? A: No; final lifetime maxima and exceedance counters now provide that evidence for the observed run.
- Q: Does a breaker guarantee a handler finishes below 50 ms? A: No; it detects completion above budget and restricts subsequent work.
- Q: Can tester timing certify the live feed? A: No. This remains explicitly unverified.
- Expert rebuttal: increasing the critical threshold would hide the original detection gap. The thresholds are unchanged; the sampling and enforcement changed instead.
- Adversarial trace: isolated 50.001 ms sample, fast-sample dilution, ring wrap, measured CPU stall, and monitoring-overhead overrun map directly to Test_TickLatency.mq5.

## Sources
- [MetaQuotes: NewTick event coalescing](https://www.mql5.com/en/docs/event_handlers/ontick)
- [MetaQuotes: monotonic microsecond counter](https://www.mql5.com/en/docs/common/getmicrosecondcount)
- [GitHub latency diagnostic example](https://gist.github.com/szmeku/5670eae695438de2a61241e2f44509ec) - contextual example only; not imported or used as correctness evidence.
- [Reddit: measurement endpoint discussion](https://www.reddit.com/r/algotrading/comments/1whf25x/what_e2e_latency_are_you_guys_trading_with/) - contextual discussion only; platform behavior is based on MetaQuotes documentation and local tests.

## Latest observed results
The October 5-7, 2026 M1-OHLC integration runs passed on all eight symbols: 89,570 observed handler completions, zero durations above 50 ms, and one duration above the 10 ms warning threshold. Maximum observed handler duration was 37.965 ms on WTI. The regression passed 33 checks with zero failures, including a measured CPU stall. The unsupported-symbol and unsupported-timeframe rejection checks also passed.

| Symbol | Maximum observed handler (ms) | Warning exceedances | Critical exceedances |
|---|---:|---:|---:|
| USDCHF | 0.219 | 0 | 0 |
| EURUSD | 0.125 | 0 | 0 |
| USDJPY | 0.298 | 0 | 0 |
| XAUUSD | 0.130 | 0 | 0 |
| US500 | 0.334 | 0 | 0 |
| WTI | 37.965 | 1 | 0 |
| BTCUSD | 0.231 | 0 | 0 |
| ETHUSD | 0.294 | 0 | 0 |

These are maxima of the observed measured scopes, not mathematically proven worst-case execution bounds. The large difference between WTI's work maximum (0.083 ms) and handler maximum (37.965 ms) shows why monitoring overhead and scheduling time must be included. These runs generated classifications but zero order-entry requests; execution-path timing under fills is outside this evidence.

[Individual-duration evidence](../Tests/Tester/model-evidence/tick_latency-results.json) - [Regression log](../Tests/Tester/model-evidence/tick_latency_contract-agent.log) - [Per-symbol integration results](../Tests/Tester/model-evidence/integration-results.json)

## Live demo measurements - October 28, 2026

The latency claim was tested against the actual FXCC demo feed in an isolated portable terminal. The user's main terminal was not closed or reconfigured. Both EA order execution and terminal autotrading were verified disabled by the observer before initialization. Account identity is redacted in retained evidence logs.

`Tests/LiveDemoLatency.mq5` wraps the real PaperEA initialization, tick, timer and shutdown handlers. It measures the full underlying tick-handler call, including its monitor update and final monitor observation, before the observer's own sample bookkeeping. It records raw callback durations in CSV, p50/p95/p99/max, warning/critical counts, maximum callback gap, timer duration, sampled connectivity and MT5's last-known broker ping. Callback gaps are arrival/processing gaps, not network latency. Repeated ping samples may all refer to the same last-known ping.

| Run | Symbol | Handlers | Maximum handler (ms) | Critical exceedances | Maximum timer (ms) |
|---|---|---:|---:|---:|---:|
| Initial live observation, 1-second timer instrumentation | USDCHF | 114 | 677.500 | 1 | 437.383 |
| Profiled baseline, normal 10-second timer cadence | USDCHF | 130 | 546.644 | 1 | 437.119 |
| After cached-handle/bulk-read repair, normal cadence | USDCHF | 124 | 0.154 | 0 | 452.335 |

The profiled baseline attributed 544.630 ms to regime detection. `Include/AdvancedRegimeDetector.mqh` repeatedly allocated ADX/ATR handles and read 100 ATR observations individually. It now owns reusable indicator handles, checks data readiness before reading, and copies the ATR window once. Its destructor releases the handles. `CRegimeAwareStrategy.mqh` retries a warming/undefined regime rather than caching it for an entire bar. Unknown regime still blocks the existing regime policy.

The live shutdown also exposed an orphaned monitor allocated during early initialization and overwritten by the master controller. `DualEA_MasterIntegration.mqh` now reuses the existing monitor singleton. The post-repair shutdown log no longer reports that leaked object. Stage profiling is compiled only into the observation build using DUALEA_TICK_PROFILING.

The observed last-known broker ping was 122.010 ms. No disconnection was seen at the timer sampling instants. Neither fact establishes packet-delivery time, quote freshness, order acknowledgement latency, or a permanent feed guarantee. Timer callbacks still reached 452.335 ms; events execute sequentially, so timer stalls remain a qualification gap even with fast OnTick handlers. Brief outages between samples are not ruled out. No order-entry or fill timing was measured because execution was disabled.

Evidence is under `Tests/Tester/live-evidence/20261028T154702Z-USDCHF`, `20261028T155049Z-USDCHF`, and `20261028T155849Z-USDCHF`. Each complete run includes a source-linked binary hash, sanitized terminal/EA logs, live-demo-summary.json and raw live-demo-durations.csv. Startup rejection attempts are retained separately and are not successful observations.

To repeat from Experts:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Advisors\DualEA\Tests\Tester\Run-LiveDemoLatency.ps1 -Symbol USDCHF -Seconds 180
```

The observer refuses non-demo accounts, enabled execution, missing shadow mode, enabled terminal autotrading and use outside its dedicated runtime. It exits the isolated terminal after the requested interval, measured at the normal timer cadence, so elapsed time may exceed the request by one timer period. The launcher removes its temporary encrypted account store and startup preset after closure. Feed measurements are live demo observations; tester results above remain a separate historical dataset.

[MetaQuotes: last-known ping is in microseconds](https://www.mql5.com/en/book/common/environment/env_connectivity) - [MT5 startup configuration](https://www.metatrader5.com/en/terminal/help/start_advanced/start)

### Additional relevant-symbol live check
USDCAD completed 90 handlers in 69.502 seconds, with p99 and maximum 0.173 ms and zero warning/critical exceedances. Timer work still reached 451.577 ms. It also verified fresh CAD headlines in the existing news section while shadow observation and terminal autotrading protections remained active. See Tests/Tester/live-evidence/20261028T160324Z-USDCAD and [NewsSentimentIntegration.md](NewsSentimentIntegration.md).

## Final historical revalidation after the live-derived repair
The rebuilt EA repeated the eight-symbol historical suite: 89,570 measured handlers, maximum 0.306 ms, zero warning or critical exceedances. The earlier 37.965 ms table documents the preceding implementation's observation; current per-symbol evidence is in tick_latency-results.json. All 33 latency checks and 24 regime-semantic checks passed. The cached bulk ATR percentile matches an independent scalar native-indicator reference. Combined current evidence: [news-latency-validation.json](../Tests/Tester/model-evidence/news-latency-validation.json).
