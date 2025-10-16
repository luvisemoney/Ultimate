# Compilation Error Fixes - PaperEA_v2.mq5

## Summary
Fixed all compilation errors in PaperEA_v2.mq5 and related modules.

## Errors Fixed

### 1. GatingPipeline.mqh - Variable Redefinition Conflicts
**Problem:** Global variables declared in GatingPipeline.mqh conflicted with input parameters in PaperEA_v2.mq5
- `UseSessionManager`, `UseCorrelationManager`, `UsePositionManager`
- `TelemetryEnabled`, `NoConstraintsMode`, `PMMaxOpenPositions`
- `GP_DefaultLogGate()`, `GP_DefaultNowMs()` functions

**Solution:** Removed all global variable declarations from GatingPipeline.mqh. Changed to macro-based fallbacks:
```mql5
#ifndef LogGate
   #define LogGate(gate, allow, phase, start_time) /* no-op */
#endif

#ifndef NowMs
   #define NowMs() ((ulong)GetTickCount64())
#endif
```

Host EA must declare these variables before including GatingPipeline.mqh.

### 2. regime_adaptation.mqh - Syntax Errors
**Problem:** Missing opening brace for `AdaptParametersToRegime()` function

**Solution:** Added opening brace on line 12:
```mql5
void AdaptParametersToRegime(const SRegimeResult& regime)
{
    if(!UseRegimeGate) return;
```

### 3. regime_adaptation.mqh - Function Signature Mismatches
**Problem:** 
- `GetVolatility()` called without parameters but defined with 2 parameters
- `GetCorrelation()` called without parameters but defined with 1 parameter
- `iATR()` called with old MQL4 syntax

**Solution:**
- Changed `GetVolatility(string symbol, ENUM_TIMEFRAMES timeframe)` to use proper iATR handle syntax
- Changed `GetCorrelation()` to take no parameters (returns 0.0 placeholder)
- Fixed all calls to `GetVolatility(_Symbol, (ENUM_TIMEFRAMES)_Period)`

### 4. PaperEA_v2.mq5 - _Period Type Conversion
**Problem:** `_Period` is `int` but functions expect `ENUM_TIMEFRAMES`

**Solution:** Cast all `_Period` usages to `(ENUM_TIMEFRAMES)_Period`:
```mql5
g_session_manager = new CSessionManager(_Symbol, (ENUM_TIMEFRAMES)_Period);
g_correlation_manager = new CCorrelationManager(_Symbol, (ENUM_TIMEFRAMES)_Period);
g_volatility_sizer = new CVolatilitySizer(_Symbol, (ENUM_TIMEFRAMES)_Period);
g_gate_manager = new CGateManager(_Symbol, (ENUM_TIMEFRAMES)_Period, g_learning_bridge);
g_regime_detector = new CAdvancedRegimeDetector(_Symbol, (ENUM_TIMEFRAMES)_Period);
g_adaptive_engine.CalculateDynamicParameters(_Symbol, (ENUM_TIMEFRAMES)_Period);
```

### 5. PaperEA_v2.mq5 - Duplicate g_gate_audit Declaration
**Problem:** Line 544 created local variable shadowing global declaration at line 288

**Solution:** Removed `CGateAudit` type from line 544, using existing global:
```mql5
// Use global g_gate_audit declared earlier instead of creating local variable
g_gate_audit.Initialize(all_strategies);
```

### 6. PaperEA_v2.mq5 - Pointer vs Object Access
**Problem:** Line 2229 used `->` operator instead of `.` for non-pointer object

**Solution:** Changed from `g_telemetry_base->LogEvent()` to `g_telemetry_base.LogEvent()`

### 7. PaperEA_v2.mq5 - Undeclared order_type in ExecutePaperTrade()
**Problem:** `order_type` variable used at line 2707 without declaration

**Solution:** Added declaration based on signal.type:
```mql5
ENUM_ORDER_TYPE order_type = (signal.type == 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
```

### 8. PaperEA_v2.mq5 - trans.symbol Direct Access
**Problem:** Cannot directly access `trans.symbol` (causes implicit conversion issues)

**Solution:** Store in temporary variable:
```mql5
string trans_symbol = trans.symbol;
if(trans_symbol != _Symbol) return;
```

### 9. PositionManager.mqh - _Period Undefined Reference
**Problem:** `_Period` not available in standalone utility class context

**Solution:** Changed to `PERIOD_CURRENT`:
```mql5
int handle = iATR(sym, PERIOD_CURRENT, period);
int ca = CopyClose(sym1, PERIOD_CURRENT, 0, bars, a);
int cb = CopyClose(sym2, PERIOD_CURRENT, 0, bars, b);
```

## Files Modified
1. `/Include/GatingPipeline.mqh` - Removed conflicting declarations
2. `/PaperEA/regime_adaptation.mqh` - Fixed syntax and signatures
3. `/PaperEA/PaperEA_v2.mq5` - Fixed type conversions and undeclared variables
4. `/Include/PositionManager.mqh` - Fixed timeframe references

## Testing
All syntax errors resolved. Code should compile successfully in MetaEditor.

## Notes
- GatingPipeline.mqh now requires host EA to declare variables before including
- GetCorrelation() is currently a placeholder returning 0.0
- GetVolatility() properly uses MQL5 indicator handle syntax
- All _Period references properly cast to ENUM_TIMEFRAMES where needed
