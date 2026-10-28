# Existing news section: headlines and sentiment

## Phase 1: audit
### Cycle 1: existing architecture
PaperEA's existing NEWS & SESSION FILTERING inputs, CheckNewsFilter, LoadNewsEvents, and timer maintenance are the integration points. Existing news data is scheduled blackout data, not a working headline sentiment classifier. CNewsImpactAnalyzer has calendar/market-response heuristics; its heuristic profitability score is not a realized return label and is not used by the universal model training pipeline.
### Cycle 2: requirements
The selected priority is headlines and sentiment with scheduled blackouts preserved. Sentiment is external context, not a new ONNX tensor. The native model remains a 104-feature price-based model with its existing supported-symbol contract. No bridge DLL or local Python server is required. HTTP work remains outside tick callbacks in a separate PowerShell publisher.
### Cycle 3: source checks
A direct Forex Factory news request returned HTTP 403. No cookies, passwords, challenge bypasses, or private-profile access were attempted. The Bank of Canada's official RSS/RDF feed was accessible and supplied three timestamp-valid records. The ECB and Fed feeds were accessible but had no records within the configured freshness window. An initial Fed parse failure was traced to its UTF-8 byte-order mark and corrected; all three feeds now parse successfully. Source status is recorded in ML/artifacts/news/news_sentiment.tsv.status.json. A successful transport response is not treated as a successful data parse.

## Phase 2: implementation and validation
### Cycle 1: publisher
ML/Update-NewsSentiment.ps1 reads actual RSS, RDF, or Atom entries, retains source URLs/publication/observation/expiry timestamps, removes duplicates, rejects missing/future/stale timestamps, prohibits XML external entities, and atomically replaces a TSV snapshot. Impact is UNKNOWN (zero) where a feed supplies no folder rating. Refreshing a story cannot extend its publication-based expiry. The default freshness window is 720 minutes; publication timestamps are used as supplied, without silently changing their timezone. A saved XML feed can be passed through -InputFile. This does not parse arbitrary saved Forex Factory HTML.

ML/Update-NewsContextBundle.ps1 merges configured feeds, preserving unexpired per-source cache during failed fetches. ML/news_sources.json contains official CAD, USD, and EUR sources. Add an accessible feed and explicit target to extend coverage; absence of coverage is unknown context. ML/Watch-NewsContext.ps1 provides bounded periodic refresh outside the EA thread.

The initial named method, headline_policy_lexicon_v1, measures explicit hawkish/dovish or rate-hike/cut wording. Mixed or negated wording is unscored. Its -1/0/+1 values are transparent rules, not calibrated probabilities or proven currency-return directions. Neutral headlines remain visible as context. No comments, expected volatility multipliers, geopolitical indices, impact ratings, or confidence scores are fabricated.

### Cycle 2: existing EA integration
Include/CNewsSentimentStore.mqh validates UTF-8 TSV schema and numeric fields, commits only complete snapshots, deduplicates identities, filters by observation/publication/expiry time, and computes relevant symbol context. Quote-currency tone is inverted relative to base-currency tone; explicit SYMBOL: targets support asset-specific feeds. Missing context returns no evidence rather than a predicted neutral market. Broker symbol metadata is used instead of hardcoding USDCHF.

PaperEA/PaperEA_v2.mq5 exposes UseNewsSentiment, NewsSentimentFile, NewsSentimentBlockOpposing, and NewsSentimentOppositionThreshold in the existing news section. RefreshHeadlineContext runs on the maintenance timer, at most once per minute. Both execution overloads retain the scheduled news blackout check and optional opposing-context check. Default sentiment behavior is observation only. It neither changes the trained model's probabilities nor closes positions or widens stops. When explicitly enabled, the opposing-context rule can block entry; missing/expired context leaves the original blackout policy in force.

### Cycle 3: validation
Tests/Test_NewsPublisher.ps1 checks directional wording, negation, deduplication, stale/future exclusion, fixed expiry, malformed-document retention and XML entity rejection. Tests/Test_NewsSentiment.mq5 exercises native parsing, FX direction inversion, unrelated-symbol isolation, future observation exclusion, expiry, malformed numeric values, truncated rows, retained prior snapshots, explicit asset targets and empty valid snapshots. Fixtures are tests only and never become training samples.

## Phase 3: setup, limits, and follow-up
### Cycle 1: running the publisher
From this Experts workspace:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Advisors\DualEA\ML\Update-NewsContextBundle.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Advisors\DualEA\ML\Watch-NewsContext.ps1 -DurationMinutes 60 -IntervalSeconds 300
```

The default destination is ML/artifacts/news/news_sentiment.tsv. For the main terminal, publish it as DualEA/news_sentiment.tsv in Common Files and enable UseNewsSentiment in the intended EA instance. Keep NewsSentimentBlockOpposing=false for observation. The isolated live-demo launcher stages the snapshot and enables observation itself; it does not modify your active chart or enable trading.

For historical tests, supply a causally timestamped historical snapshot in agent-local Files and use UTC test data. Current headlines are not a historical training set; observation timestamps prevent them from appearing before collection. No global tester_file property transfers today's news into every historical test.

### Cycle 2: four-source proposal review
| Source in the screenshots | Treatment |
|---|---|
| Calendar | Existing blackout policy remains; actual/forecast fields require exact units, release timestamps and revision history before surprise modeling. |
| Headlines | Implemented source-linked publisher and existing news-section consumer. Forex Factory direct automation remains blocked; accessible official feeds are used. |
| Trades / positioning | Public sample positioning is neither complete market flow nor realized forward-return labels. No automated Forex Factory trade-feed collector is claimed. |
| Forums | Opinions need permitted access, timestamps, symbol attribution, deduplication and a separately evaluated model. No local fine-tuned BERT model is assumed to exist. |
| Own history | Existing realized-trade logging/import remains the appropriate route. Public leaderboard rankings do not supply missing trade outcomes or drawdowns. |

The pasted percentage-surprise calculation is not the same quantity as a standardized surprise using historical forecast-error deviation. Its hardcoded CSS selectors and assumed fine-tuned NLP model were not adopted as working implementations. Screenshots are references, not a continuously updating data feed.

### Cycle 3: five next checks
1. Collect timestamped headline snapshots before attempting any supervised news-model training.
2. Validate policy-tone direction against actual forward market outcomes; do not interpret +1 as a calibrated probability.
3. Add permitted news feeds for other currencies/assets and measure their real coverage and publication delay.
4. Evaluate forum opinions and retail positioning as separate channels with their own evidence and failure states.
5. Repeat demo observation around scheduled releases while retaining blackout protection and measuring timer stalls as well as tick work.

## Q&A / review decisions
- Does a sentiment module already exist? The news-filter section exists; current-source searches found no implemented headline scorer there. It now has a timestamped context consumer.
- Why not poll HTTP every tick? A network request blocks event processing and undermines the latency work. Publishing is external; the EA reads a bounded local snapshot on its timer.
- Why not extend the ONNX vector now? The installed model was trained without news. Adding fields requires a new causal dataset, retraining and native parity validation.
- Adversarial trace: future timestamps, stale refreshes, duplicate headlines, malformed numeric scores, truncated files and external XML entities map to the two news tests.

## Verifiable sources
- [Forex Factory news](https://www.forexfactory.com/news)
- [Bank of Canada feed directory](https://www.bankofcanada.ca/rss-feeds/) and [actual RDF feed](https://www.bankofcanada.ca/utility/news/feed/)
- [Federal Reserve monetary policy feed](https://www.federalreserve.gov/feeds/press_monetary.xml)
- [ECB press feed](https://www.ecb.europa.eu/rss/press.html)
- [VADER source](https://github.com/cjhutto/vaderSentiment): reference only; not installed or represented as a financial-return model.
- [Reddit discussion of latency endpoints](https://www.reddit.com/r/algotrading/comments/1whf25x/what_e2e_latency_are_you_guys_trading_with/): contextual discussion, not correctness evidence.

## Actual integration observation
The isolated USDCAD demo observation on October 28, 2026 loaded three real CAD headlines and logged fresh=1, evidence=3, rule_score=-0.333, mode=OBSERVE. The USDCHF observation loaded the same records but logged fresh=0 and evidence=0, because those CAD records do not apply to USDCHF. This verifies symbol mapping and quote-currency inversion; it is not an accuracy or profitability test. Scheduled blackout checks remain present in both PaperEA execution overloads.

USDCAD produced 90 observed handlers over 69.502 seconds: p99 0.173 ms, maximum 0.173 ms, zero warning/critical exceedances. Its timer maximum was 451.577 ms. Demo account mode, disabled EA execution, shadow mode and disabled terminal autotrading were verified before initialization. No entry request was observed in the retained observer logs. Evidence: Tests/Tester/live-evidence/20261028T160324Z-USDCAD.

A bounded publisher was started on this machine: every 300 seconds for 60 minutes, writing DualEA/news_sentiment.tsv in MT5 Common Files. Its PID/start time are in ML/artifacts/news/watcher.json; stdout/stderr logs are beside that file. This is a temporary worker, not a permanently installed service or scheduled task. Existing chart inputs were not changed. Load Tests/Tester/news_sentiment_observe.set on the intended demo EA instance when ready to observe its news context; the preset disables order execution and enables shadow observation.

Stop the recorded worker safely with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Advisors\DualEA\ML\Stop-NewsContext.ps1
```

Run native regressions and the eight-symbol integration suite with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Advisors\DualEA\Tests\Tester\Run-NewsLatencyValidation.ps1
```

## Final validation for this change
All 80 targeted checks passed: 8 publisher checks, 15 native sentiment checks, 24 native regime checks and 33 native latency checks. The rebuilt EA passed all eight supported-symbol model integration workloads and both unsupported-contract rejection cases. Compilation of PaperEA, LiveEA, UnifiedSystemExample, the observer and new native tests completed with zero errors and warnings.

[Combined machine-readable verification](../Tests/Tester/model-evidence/news-latency-validation.json) contains the exact tested EA hash, four completed live observations, per-source coverage status and test counts. The only enabled background activity is the bounded news publisher. The isolated observation terminal has closed and its temporary encrypted account store was removed. The user's original terminal remained running.
