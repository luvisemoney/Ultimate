# Knowledge Base CSV Schemas (DualEA)

This document defines the exact CSV schemas produced and consumed by DualEA components. All files live under MT5 Common Files.

- Typical path: `C:\Users\<you>\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DualEA\`
- Alternate path: `C:\ProgramData\MetaQuotes\Terminal\Common\Files\DualEA\`

## Global Conventions
- Delimiter: comma `,`
- Header row: always present; created automatically on first write
- Timestamp format: `TimeToString(..)` default (date + time with seconds), e.g. `2025.08.10 16:12:34`
- File API: MT5 `FileOpen(..., FILE_CSV | FILE_COMMON, ',')`; exploration counters use `FILE_ANSI`
- Share mode: writers generally use `FILE_SHARE_WRITE` to permit concurrent access

Source of truth: `Include/KnowledgeBase.mqh`, `PaperEA/PaperEA.mq5`.

---

## knowledge_base.csv
Header (exact):
```
timestamp,symbol,type,entry_price,stop_loss,take_profit,close_price,profit,strategy_id
```
Defined by `CKnowledgeBase::CKnowledgeBase()` and written in `CKnowledgeBase::WriteRecord()`.

Columns:
- timestamp: datetime (string) — order execution time
- symbol: string — instrument symbol (e.g., `EURUSD`)
- type: int — MT5 `ENUM_ORDER_TYPE` as integer (e.g., `0` buy, `1` sell)
- entry_price: double — formatted with `_Digits`
- stop_loss: double — formatted with `_Digits`
- take_profit: double — formatted with `_Digits`
- close_price: double — formatted with `_Digits`
- profit: double — formatted with 2 decimals
- strategy_id: string — strategy name/ID that generated the trade

Notes:
- Path: `DualEA\knowledge_base.csv`
- Open flags: `FILE_CSV | FILE_COMMON` with `FILE_SHARE_WRITE`

---

## knowledge_base_events.csv
Header (exact):
```
timestamp,strategy,retcode,deal,order
```
Written by `CKnowledgeBase::LogTrade()`.

Columns:
- timestamp: datetime (now)
- strategy: string — strategy name
- retcode: int — MT5 trade result code (`MqlTradeResult.retcode`)
- deal: int — deal ticket
- order: int — order ticket

Notes:
- Path: derived from main KB path (e.g., `DualEA\knowledge_base_events.csv`)
- Open flags: `FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_COMMON`

---

## features.csv (long format)
Header (exact):
```
timestamp,symbol,strategy,feature,value
```
Created by `CFeaturesKB::EnsureHeader()` and appended by `CFeaturesKB::WriteKV()`.

Columns:
- timestamp: datetime — event time for feature
- symbol: string — instrument symbol
- strategy: string — strategy name
- feature: string — feature key (e.g., `r_multiple`, indicators, regime flags)
- value: double — 8 decimal places

Notes:
- Path: `DualEA\features.csv`
- Writers: `FILE_READ|FILE_WRITE|FILE_CSV|FILE_SHARE_WRITE|FILE_COMMON`
- Readers: sometimes parsed as text (`FILE_TXT|FILE_ANSI`) in `Include/StrategySelector.mqh` (recency scoring expects `r_multiple` rows)

---

## explore_counts.csv (weekly)
Header (exact):
```
key,week_monday_yyyymmdd,count
```
Managed by `SaveExploreCounts()`, `LoadExploreCounts()` in `PaperEA/PaperEA.mq5`.

Columns:
- key: string — slice key `strategy|symbol|timeframe`
- week_monday_yyyymmdd: int — week bucket computed by `WeekMondayId()` (Monday of week)
- count: int — number of explorations used for the week

Notes:
- Path: `DualEA\explore_counts.csv`
- Open flags: `FILE_*|FILE_CSV|FILE_ANSI|FILE_COMMON`

## explore_counts_day.csv (daily)
Header (exact):
```
key,day_yyyymmdd,count
```
Managed by `SaveExploreCountsDay()`, `LoadExploreCountsDay()`.

Columns:
- key: string — slice key `strategy|symbol|timeframe`
- day_yyyymmdd: int — daily bucket computed by `DayId()`
- count: int — number of explorations used for the day

Notes:
- Path: `DualEA\explore_counts_day.csv`
- Open flags: `FILE_*|FILE_CSV|FILE_ANSI|FILE_COMMON`

---

## Log Prefix Reference (for schema consumers)
Common journal prefixes related to these files:
- `Policy gating: min_conf=... slices=N`
- `Insights gating: loaded N slices`
- `GATE: explore allow ... (day=d/D, week=w/W)`
- `GATE: blocked ... reason=explore_cap_day|explore_cap_week ...`
- `FALLBACK: policy slice missing -> neutral scaling used for <strat> on <symbol>/<tf> demo=<true|false>`
- `FALLBACK: no policy loaded -> neutral scaling used for <strat> on <symbol>/<tf> demo=<true|false>`

These strings are emitted by `PaperEA/PaperEA.mq5` and help interpret how counters and CSV rows are produced.
