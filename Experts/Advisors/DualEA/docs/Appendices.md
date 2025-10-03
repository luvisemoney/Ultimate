# Appendices — DualEA System

**Schemas, red-team artifacts, CI hooks, and operational references**

---

## Table of Contents

1. [Red-Team Artifacts](#red-team-artifacts)
2. [Data Schemas](#data-schemas)
3. [CI/CD Integration](#cicd-integration)
4. [Operational Procedures](#operational-procedures)
5. [Troubleshooting Guide](#troubleshooting-guide)

---

## Red-Team Artifacts

### Overview

To operationalize the 3×3 red-team process, store artifacts in MT5 Common Files for both Tester and Live to access.

**Base Path**: `Common\Files\DualEA\jailbreak\`

**Run Layout**:
```
jailbreak/
├── runs/
│   └── YYYYMMDD_HHMMSS/
│       ├── qna.md              # Q&A log for the session
│       ├── rebuttals.jsonl     # Expert rebuttals (JSONL)
│       ├── traces.jsonl        # Jailbreak traces (JSONL)
│       └── summary.md          # Short session summary
└── latest/                     # Symlink/copy of most recent run
```

### A.1: Q&A Log (Markdown)

Minimal, structured template capturing prompts, answers, and references to code.

**Template**:
```markdown
# Red-Team Q&A — YYYY-MM-DD HH:MM:SS

## Q1: <question>
- **Context**: <module(s) e.g., `PaperEA/PaperEA_v2.mq5`>
- **Hypothesis**: <expected behavior>
- **Answer**: <observed behavior/decision>
- **Evidence**: <file refs, line ranges, logs>
- **Outcome**: pass | fail | needs-followup

## Q2: ...
```

**Example**:
```markdown
# Red-Team Q&A — 2025-01-15 10:30:00

## Q1: Does exploration bypass trigger with existing slice?
- **Context**: `PaperEA/PaperEA_v2.mq5`, lines 1200-1250
- **Hypothesis**: Exploration only bypasses when slice missing entirely
- **Answer**: Correct. Existing under-threshold slices are gated (no bypass)
- **Evidence**: Code at lines 1220-1235, test logs from Test_Exploration.mq5
- **Outcome**: pass
```

### A.2: Expert Rebuttals (JSONL)

One JSON per line with explicit links to files/modules and decisions.

**Format**:
```json
{"id":"rb_0001","claim":"Exploration bypass triggers with existing slice","rebuttal":"Bypass is no-slice-only; existing under-threshold slices are gated","evidence_files":["PaperEA/PaperEA_v2.mq5"],"decision_paths":["Gate->Insights->ExploreCaps"],"status":"resolved","timestamp":"2025-01-15T10:00:00Z"}
```

**Fields**:
- `id`: Stable rebuttal identifier
- `claim`: Red-team claim being challenged
- `rebuttal`: Concise counterargument
- `evidence_files`: Array of repository paths
- `decision_paths`: e.g., `Scan->Selector->Gate->Execute`
- `status`: open | resolved | needs-work
- `timestamp`: ISO8601 format

### A.3: Jailbreak Traces (JSONL)

Record adversarial tests, input mutations, expected vs observed behavior, and severity.

**Format**:
```json
{"ts":"2025-01-15T10:00:00Z","module":"PolicyLoader","file":"Include/StrategySelector.mqh","symbol":"EURUSD","timeframe":60,"case":"corrupt_policy_json","mutation":"truncated file","expected":"fallback to last-known-good policy with log and no crash","observed":"fallback engaged; neutral scaling applied","outcome":"safe","severity":"low","artifacts":["Common/Files/DualEA/policy.json","Common/Files/DualEA/policy.backup.json"],"notes":"Validated timer reload path and guardrails"}
```

**Fields**:
- `ts`: Timestamp
- `module`, `file`: Component and path under repo
- `symbol`, `timeframe`: Slice context when applicable
- `case`, `mutation`: Short names for cataloging
- `expected`, `observed`: Behaviors
- `outcome`: safe | unsafe | inconclusive
- `severity`: low | medium | high
- `artifacts`: Related files (Common Files paths allowed)
- `notes`: Free-form observations

### A.4: Traceability Rules

- **Always reference concrete files/paths**: e.g., `LiveEA/LiveEA.mq5`
- **Map each finding to a decision path**: `OnTick()->ScanStrategies()->Gating()->TradeManager.Execute()`
- **Prefer JSONL for machine-readable aggregation**: Keep Markdown summaries for humans
- **Attach log snippets**: Journal and KB rows when relevant

### A.5: CI Hooks

- Copy latest run into `jailbreak/latest/` after each session
- Optional validator: Assert each `case` has at least one `outcome=safe` or open issue
- Include red-team artifacts in reports alongside insights validation

### A.6: Operational Notes

- PaperEA and LiveEA do not read from `jailbreak/`: Write-only audit area
- Keep PII/broker identifiers out of logs: Sanitize before sharing
- Large artifacts should be rotated/compressed if size grows beyond operational limits

---

## Data Schemas

### Knowledge Base CSV

**knowledge_base.csv**:
```csv
timestamp,symbol,type,entry_price,stop_loss,take_profit,close_price,profit,strategy_id
2025-01-15T10:30:00Z,EURUSD,BUY,1.0850,1.0800,1.0950,1.0920,70.00,ADXStrategy
```

**Fields**:
- `timestamp`: Trade entry timestamp (ISO8601)
- `symbol`: Trading symbol
- `type`: BUY or SELL
- `entry_price`: Entry price
- `stop_loss`: Stop loss price
- `take_profit`: Take profit price
- `close_price`: Exit price (0 if still open)
- `profit`: Profit in account currency (0 if still open)
- `strategy_id`: Strategy name

**knowledge_base_events.csv**:
```csv
timestamp,strategy,retcode,deal,order
2025-01-15T10:30:00Z,ADXStrategy,10009,123456,789012
```

**Fields**:
- `timestamp`: Event timestamp (ISO8601)
- `strategy`: Strategy name
- `retcode`: Broker return code (10009=success)
- `deal`: Deal ticket number
- `order`: Order ticket number

### Features CSV

**features.csv** (long format, 50+ features):
```csv
timestamp,symbol,timeframe,strategy,direction,confidence,entry,sl,tp,lots,atr,rsi,adx,ma_fast,ma_slow,...
2025-01-15T10:30:00Z,EURUSD,60,ADXStrategy,1,0.85,1.0850,1.0800,1.0950,0.10,0.0012,65,28,1.0840,1.0820,...
```

**Key Features**:
- Market context: ATR, spread, volume, volatility percentile
- Technical indicators: RSI, ADX, MACD, Bollinger Bands, KAMA, etc.
- Price action: Highs, lows, opens, closes across multiple bars
- Time features: Hour, day of week, session
- Strategy-specific: Indicator values used by strategy

**Rotation**: Automatic at 100MB, compressed with timestamp.

### Insights JSON

**insights.json**:
```json
{
  "version": "1.0",
  "generated_at": "2025-01-15T10:00:00Z",
  "slices": [
    {
      "strategy": "ADXStrategy",
      "symbol": "EURUSD",
      "timeframe": 60,
      "win_rate": 0.58,
      "total_trades": 45,
      "avg_r_multiple": 0.72,
      "sharpe_ratio": 1.25,
      "last_trade_time": "2025-01-15T09:30:00Z"
    }
  ]
}
```

### Policy JSON

See [Policy-Exploration-Guide.md](Policy-Exploration-Guide.md) for complete schema.

---

## CI/CD Integration

### kb_check.bat

Validates insights and KB integrity:

```batch
@echo off
REM Run insights validation
MetaTrader5.exe /portable /config:tester.ini /script:ValidateInsights.mq5

REM Check exit code
if %ERRORLEVEL% NEQ 0 (
    echo [FAIL] Insights validation failed
    exit /b 1
)

echo [PASS] Insights validation successful
exit /b 0
```

### CI Pipeline Integration

```yaml
# .github/workflows/validate.yml (example)
name: Validate Knowledge Base
on: [push, pull_request]

jobs:
  validate-kb:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run KB validation
        run: .\kb_check.bat
      - name: Upload logs
        uses: actions/upload-artifact@v2
        with:
          name: validation-logs
          path: logs/
```

---

## Operational Procedures

### Insights Rebuild Procedure

**When to Rebuild**:
- Weekly (minimum)
- After significant data collection (>100 new trades)
- Before deploying to live
- When insights appear stale (>24 hours old)

**Steps**:
1. Stop all EAs
2. Run `Scripts/InsightsRebuild.mq5`
3. Check log for errors
4. Validate with `Scripts/ValidateInsights.mq5`
5. Restart EAs

### Policy Deployment Procedure

**Steps**:
1. Train model: `ML/run_train_and_export.bat`
2. Review metrics (ROC-AUC, Brier, Expected-R)
3. Copy `policy.json` to `Common/Files/DualEA/`
4. Backup existing policy to `policy.backup.json`
5. Test in PaperEA with shadow mode
6. If successful, deploy to LiveEA
7. Monitor for 24-48 hours

### Exploration Counter Reset

**When to Reset**:
- Start of new trading week (Monday)
- After insights rebuild with new slices
- Testing new strategies

**Steps**:
```powershell
Remove-Item "C:\Users\<username>\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DualEA\explore_counts*.csv"
```

---

## Troubleshooting Guide

### Issue: Insights not loading

**Symptoms**: Logs show "insights.json not found" or "failed to parse"

**Solutions**:
1. Run `InsightsRebuild.mq5`
2. Check file exists: `Common\Files\DualEA\insights.json`
3. Validate JSON format (use online validator)
4. Check file permissions

### Issue: Policy fallback always triggering

**Solutions**:
1. Verify `policy.json` exists and has `slices > 0`
2. Check policy covers your symbols/timeframes/strategies
3. Review `DebugPolicy=true` logs
4. Ensure `policy.json` is well-formed JSON

### Issue: Gate blocks everything

**Solutions**:
1. Enable `NoConstraintsMode=true` for data collection
2. Check `SystemMonitor.GetGateSuccessRate()` for which gate failing
3. Review telemetry for most common block reasons
4. Lower gate thresholds temporarily
5. Use shadow mode to observe without blocking

### Issue: KB writes failing

**Solutions**:
1. Enable `DebugKB=true`
2. Check `FolderCreate("DualEA", FILE_COMMON)` in code
3. Verify disk space available
4. Check file permissions on Common Files directory
5. Review Journal for specific error messages

### Issue: High memory usage

**Solutions**:
1. Check `TerminalInfoInteger(TERMINAL_MEMORY_USED)`
2. Review `IndicatorsTotal()` - release unused handles
3. Reduce telemetry verbosity
4. Clear old log files
5. Restart EA

---

## Quick Reference

### Common File Paths

**Windows**:
- Standard: `C:\Users\<username>\AppData\Roaming\MetaQuotes\Terminal\Common\Files\DualEA\`
- Portable: `C:\Program Files\MetaTrader 5\MQL5\Files\DualEA\`

### Important Files

- `knowledge_base.csv`: Trade records
- `features.csv`: ML training data
- `insights.json`: Performance analytics
- `policy.json`: ML policy
- `explore_counts.csv`: Weekly exploration caps
- `explore_counts_day.csv`: Daily exploration caps
- `logs/trades_YYYYMMDD.json`: Daily trade logs

### Useful Commands

**Check insights staleness**:
```powershell
Get-Item "...\insights.json" | Select-Object LastWriteTime
```

**Count features**:
```powershell
Import-Csv "...\features.csv" | Measure-Object
```

**Query telemetry**:
```powershell
Import-Csv "...\telemetry_YYYYMMDD.csv" | Where-Object {$_.event_type -eq 'gate_decision'} | Group-Object reason
```

---

**See Also:**
- [Configuration-Reference.md](Configuration-Reference.md) - All parameters
- [Execution-Pipeline.md](Execution-Pipeline.md) - Execution flow
- [Observability-Guide.md](Observability-Guide.md) - Telemetry details
- [Policy-Exploration-Guide.md](Policy-Exploration-Guide.md) - Policy system
- [Phase-Implementation.md](Phase-Implementation.md) - Development roadmap
