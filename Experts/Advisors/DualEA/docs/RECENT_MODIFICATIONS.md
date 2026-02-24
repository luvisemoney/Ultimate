# Recent Modifications Log

This document tracks ongoing modifications to the DualEA system. For complete system documentation, see [README.md](README.md).

---

## 2026-02-15 Modifications

### 1. Fixed Sell Signal Generation
**Issue**: EA only opening long positions, no shorts  
**Root Cause**: Overly restrictive conditions in `GenerateSignal()`  
**Files Modified**: `PaperEA/PaperEA_v2.mq5` lines 3467-3508  
**Changes**:
```cpp
// OLD (broken):
if(fast_ma > slow_ma && fast_ma < current_price)      // Buy - worked
else if(fast_ma < slow_ma && fast_ma > current_price) // Sell - rarely triggered

// NEW (fixed):
if(fast_ma > slow_ma)      // Buy when fast > slow (uptrend)
else if(fast_ma < slow_ma) // Sell when fast < slow (downtrend)
```

### 2. Fixed Position Count Discrepancy
**Issue**: System status showed 0 positions despite tracking 16 positions  
**Root Cause**: `CPositionManager` not synced with actual MT5 positions  
**Files Modified**: `PaperEA/PaperEA_v2.mq5` lines 1791-1797  
**Changes**: Added `SyncPositions()` call after scanning existing positions
```cpp
if(CheckPointer(g_position_manager) != POINTER_INVALID)
{
   g_position_manager.SyncPositions(MagicNumber);
   LOG(StringFormat("[PositionManager] Synced with %d positions for magic=%d", 
           g_position_manager.GetPositionCount(), MagicNumber));
}
```

### 3. Fixed Memory Leaks on Deinitialization
**Issue**: Memory leaks for `Database`, `CPositionManager`, `CSQLiteExplorationCounter`  
**Root Cause**: Double deletion of objects managed by both EA and MasterController  
**Files Modified**: `PaperEA/PaperEA_v2.mq5` lines 1830-1854  
**Changes**: Removed double-delete, objects owned by MasterController only
```cpp
// SKIP: g_position_manager - owned by MasterController
// SKIP: g_explore_counter (CSQLiteExplorationCounter) - owned by MasterController
```

### 4. Fixed Position Limit Check
**Issue**: Position limit counted ALL MT5 positions (122) instead of just EA's positions  
**Root Cause**: `CheckMemoryLimits()` used `PositionsTotal()` without magic filter  
**Files Modified**: `PaperEA/PaperEA_v2.mq5` lines 3085-3106  
**Changes**: Added magic number filtering
```cpp
for(int i = PositionsTotal() - 1; i >= 0; i--)
{
   if(PositionGetTicket(i) > 0)
   {
      long pos_magic = PositionGetInteger(POSITION_MAGIC);
      if(MagicNumber == 0 || pos_magic == MagicNumber)
         total_positions++;
   }
}
```

### 5. Connected Insight Bridge to Trading Flow
**Issue**: Insight bridge stats showing 0 values (HitRate=0.0%, Latency=0.00us, Cache=0)  
**Root Cause**: Bridge never queried because trading flow bypassed it  
**Files Modified**: 
- `PaperEA/PaperEA_v2.mq5` lines 4239-4250
- `Include/DualEA_MasterIntegration.mqh` line 586  
**Changes**:
```cpp
// Added GetInsightBridge() getter
CInsightGateBridge* GetInsightBridge() { return m_insight_bridge; }

// Added insight bridge query in ProcessAllStrategySignals()
if(CheckPointer(g_master_controller) != POINTER_INVALID)
{
   CInsightGateBridge* bridge = g_master_controller.GetInsightBridge();
   if(CheckPointer(bridge) != POINTER_INVALID)
   {
      double insight_confidence = bridge.GetSignalConfidence(strategy_name, _Symbol);
      LOG(StringFormat("[Multi-Strategy] %s: Insight confidence=%.2f%%", 
         strategy_name, insight_confidence * 100));
   }
}
```

### 6. Added Timeframe-Based Position Review
**Issue**: Fixed position review interval not adapting to chart timeframe  
**Files Modified**: `PaperEA/PaperEA_v2.mq5` lines 312-324, 4497-4550, 4744-4762  
**Changes**: Dynamic review interval based on chart timeframe
- M1: 15s, M5: 30s, M15: 45s, M30: 60s, H1: 2min, H4: 4min, D1: 6min

### 7. Added Rate Limiting for Log Messages
**Issue**: Position limit and memory limit messages showing repeatedly  
**Files Modified**: `PaperEA/PaperEA_v2.mq5` lines 3057-3084, 3235-3253  
**Changes**: Static boolean flags ensure messages only show once ever

---

## Testing Status

All fixes have been implemented and are ready for testing:
- ✅ Sell signal generation fixed
- ✅ Position count discrepancy resolved  
- ✅ Memory leaks eliminated
- ✅ Position limit check corrected
- ✅ Insight bridge stats will populate on next strategy execution
- ✅ Timeframe-based position review active
- ✅ Log spam reduced

**Next Steps**: Recompile EA and test with real market data to verify all issues are resolved.

---

## Documentation Updates Required

- Update README.md with recent fixes
- Add troubleshooting section for common issues
- Document insight bridge integration
- Update operations guide for new timeframe features
