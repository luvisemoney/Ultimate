# News Filter Integration Guide

## Overview

The enhanced News Filter system provides **dynamic threshold adjustment** based on real-time economic calendar events and market response analysis. It integrates with the ML pipeline to improve trading decisions during news events.

## Key Features

1. **Dynamic Threshold Adjustment**: Automatically adjusts gate thresholds based on news impact
2. **MQL5 Economic Calendar API**: Direct integration with MetaTrader 5's built-in calendar
3. **Market Response Measurement**: Real-time volatility, spread, and price impact tracking
4. **ML Training Export**: Exports news impact data for model training
5. **Drop-in Replacement**: Easy integration with existing PaperEA/LiveEA code

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   News Filter System                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌──────────────────┐              │
│  │ Economic        │───▶│ News Impact      │              │
│  │ Calendar API    │    │ Analyzer         │              │
│  │ (MQL5 Native)   │    │                  │              │
│  └─────────────────┘    └────────┬─────────┘              │
│                                   │                         │
│                                   ▼                         │
│  ┌──────────────────────────────────────────┐             │
│  │     Threshold Adjustment Engine           │             │
│  │  ┌──────────────┐  ┌──────────────────┐  │             │
│  │  │ Confidence   │  │ Position Size    │  │             │
│  │  │ Multiplier   │  │ Multiplier       │  │             │
│  │  └──────────────┘  └──────────────────┘  │             │
│  └──────────┬───────────────────────────────┘             │
│             │                                               │
│             ▼                                               │
│  ┌──────────────────────────────────────────┐             │
│  │           EA Trading Logic               │             │
│  │        (PaperEA / LiveEA)                │             │
│  └──────────────────────────────────────────┘             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  ML Training     │
                    │  Data Export     │
                    └──────────────────┘
```

## Quick Start

### Option 1: Drop-in Integration (Recommended)

Replace existing news filter includes in `PaperEA_v2.mq5` and `LiveEA.mq5`:

```cpp
// OLD CODE (remove these):
// bool CheckNewsFilter() { ... }
// void LoadNewsEvents() { ... }

// NEW CODE (add this):
#include "..\Include\NewsFilterIntegration.mqh"

// In OnInit():
INIT_NEWS_FILTER(_Symbol);

// Replace CheckNewsFilter() calls with:
if(!CHECK_NEWS_FILTER())
   return; // Trading blocked due to news

// Adjust confidence before gate check:
double adjusted_conf = ADJUST_CONFIDENCE_FOR_NEWS(base_confidence);

// Adjust position size before execution:
double adjusted_lots = ADJUST_SIZE_FOR_NEWS(base_lots);
```

### Option 2: Direct Module Usage

For more control, use individual modules:

```cpp
#include "..\Include\CNewsImpactAnalyzer.mqh"

// Initialize
CNewsImpactAnalyzer* analyzer = CNewsImpactAnalyzer::Instance();
analyzer.SetUseMLPredictions(true);

// In OnTick():
SThresholdAdjustment adj = ANALYZE_NEWS(_Symbol);

if(!adj.should_trade)
   return;

double final_conf = base_confidence / adj.confidence_multiplier;
double final_lots = base_lots * adj.position_size_multiplier;
```

## Configuration Parameters

### Input Parameters (EA Level)

```cpp
// In your EA's input section:
input bool   UseNewsFilter       = true;      // Enable news filtering
input int    NewsBufferBeforeMin = 30;        // Minutes before event
input int    NewsBufferAfterMin  = 60;        // Minutes after event  
input int    NewsImpactMin       = 1;         // 0=low, 1=medium, 2=high
input bool   UseDynamicThresholds = true;     // Enable ML-based adjustment
input bool   ExportNewsForML     = true;      // Export training data
```

### Module-Level Configuration

```cpp
// In NewsFilterIntegration.mqh or analyzer:
// Set volatility spike threshold (2.0 = 200% of normal)
analyzer.SetVolatilityThreshold(2.0);

// Set spread widening threshold (1.5 = 150% of normal)
analyzer.SetSpreadThreshold(1.5);

// Set baseline measurement lookback (bars)
analyzer.SetBaselineLookback(20);
```

## Python News Fetcher

### Setup

```bash
cd MQL5/Experts/Advisors/DualEA/ML
python news_fetcher.py --fetch --generate-blackouts --days 7
```

### Daemon Mode (Auto-Update)

```bash
# Run as daemon, updating every 5 minutes
python news_fetcher.py --serve --interval 300 --generate-blackouts
```

### Enrich Features with News

```bash
# Add news features to existing training data
python news_fetcher.py --enrich-features features.csv --output features_enriched.csv
```

## Threshold Adjustment Logic

### News States

| State | Description | Confidence Multiplier | Position Size Multiplier | Risk Multiplier |
|-------|-------------|----------------------|-------------------------|-----------------|
| **QUIET** | No significant news | 1.0x | 1.0x | 1.0x |
| **WARNING** | News approaching (15 min) | 1.2x | 0.7x | 0.8x |
| **ACTIVE** | Medium impact news | 1.5x | 0.5x | 0.5x |
| **ACTIVE** | High impact news | BLOCK | 0.0x | 0.0x |
| **AFTERMATH** | Post-news volatility | 1.3x | 0.6x | 0.7x |

### Additional Adjustments

```cpp
// If volatility > 200% of baseline:
confidence_multiplier *= 1.2;

// If spread > 150% of baseline:
confidence_multiplier *= 1.1;
position_size_multiplier *= 0.8;
```

## ML Integration

### Training Data Export

The system automatically exports to `DualEA/news_impact_training.csv`:

```csv
timestamp,symbol,volatility_prediction,volatility_spike,spread_widening,volume_surge,price_change_pct,is_trending,threshold_direction,confidence_multiplier,should_trade,profitability_score,news_reason
```

### Feature Engineering

Use in `features.py`:

```python
from news_fetcher import NewsFetcher

# Enrich features with news
fetcher = NewsFetcher()
fetcher.fetch_from_mql5_calendar()
features_df = fetcher.enrich_features_with_news(features_df)
```

### Model Training

News features added to training:
- `time_to_next_event`: Seconds until next high-impact event
- `is_news_time`: Boolean for active news window
- `current_news_impact`: 0-2 importance level
- `upcoming_news_impact`: Next event importance
- `news_volatility_prediction`: 0-1 predicted volatility

## Testing

### Unit Test

```cpp
#include "..\Include\Tests\Test_NewsFilter.mqh"

void OnStart()
{
   CTestNewsFilter tester;
   tester.RunAllTests();
}
```

### Manual Verification

1. Check news state in Experts tab:
   ```cpp
   Print("News state: " + GET_NEWS_STATE());
   ```

2. Get statistics:
   ```cpp
   if(g_news_filter_integration != NULL)
      Print(g_news_filter_integration.GetStatistics());
   ```

3. Force refresh:
   ```cpp
   REFRESH_NEWS_CALENDAR();
   ```

## Troubleshooting

### Issue: News filter not blocking trades

**Check:**
1. `UseNewsFilter` input is `true`
2. `INIT_NEWS_FILTER()` called in `OnInit()`
3. `CHECK_NEWS_FILTER()` called before trade execution
4. `news_blackouts.csv` exists in `Common Files/DualEA/`

### Issue: Calendar not updating

**Check:**
1. Internet connection available
2. `MQL5 Calendar` functions not restricted
3. Check Journal for errors: `CErrorRecovery::GetErrorStats()`

### Issue: High CPU usage

**Fix:**
```cpp
// Increase check interval (default 1 second)
g_news_filter_integration.check_interval_sec = 5;
```

## Migration from Legacy News Filter

### Before (Legacy):
```cpp
bool CheckNewsFilter()
{
   if(!UseNewsFilter) return true;
   
   datetime now = TimeCurrent();
   for(int i = 0; i < ArraySize(g_news_from); i++)
   {
      if(now >= g_news_from[i] && now <= g_news_to[i])
         return false;
   }
   return true;
}
```

### After (Integrated):
```cpp
// Single include and init
#include "..\Include\NewsFilterIntegration.mqh"

int OnInit()
{
   INIT_NEWS_FILTER(_Symbol);
   // ... rest of init
}

// In trading logic:
if(!CHECK_NEWS_FILTER())
   return;

double adj_conf = ADJUST_CONFIDENCE_FOR_NEWS(signal.confidence);
```

## Performance Considerations

- **Check frequency**: Default 1 second, adjustable
- **Calendar updates**: Every 5 minutes (300 seconds)
- **Baseline metrics**: Updated every 5 minutes
- **Memory usage**: ~500 events cached (~50KB)
- **CPU impact**: Minimal (<0.1ms per check)

## API Reference

### CNewsFilterIntegration

```cpp
class CNewsFilterIntegration
{
   bool Initialize(string symbol, bool use_news, ...);
   bool CheckNewsFilter();
   double AdjustConfidence(double base_conf);
   double AdjustPositionSize(double base_lots);
   string GetNewsState();
   string GetStatistics();
   void RefreshCalendar();
};
```

### CNewsImpactAnalyzer

```cpp
class CNewsImpactAnalyzer
{
   SThresholdAdjustment AnalyzeNewsImpact(string symbol);
   SThresholdAdjustment GetCurrentAdjustment();
   bool ShouldTrade();
   ENUM_NEWS_STATE GetCurrentState();
   string GetStatistics();
};
```

### CEconomicCalendar

```cpp
class CEconomicCalendar
{
   bool UpdateEvents();
   SNewsImpact CheckNewsImpact(string symbol, int buffer_before, int buffer_after);
   SEconomicEvent GetNextEvent(int min_importance);
   bool ExportEventsToFile(string filename);
   string GetStatistics();
};
```

## Best Practices

1. **Always check news before gate system**: News filter should be first check in trading logic
2. **Use adjusted confidence**: Apply `ADJUST_CONFIDENCE_FOR_NEWS()` to all confidence values
3. **Log news blocks**: Enable verbose logging to understand why trades are blocked
4. **Monitor buffer usage**: Check `CUnifiedFileIO` buffer utilization in high-frequency trading
5. **Regular calendar updates**: Run `news_fetcher.py` as daemon for accurate data
6. **Test in simulation**: Use sample events to test news filter behavior

## Related Documentation

- [README.md](README.md) - Main system documentation
- [UnifiedSystemGuide.md](UnifiedSystemGuide.md) - ConfigManager/EventBus
- [Phase3.md](Phase3.md) - LiveEA implementation
- [DualEA_Action_Framework.md](DualEA_Action_Framework.md) - 3×3 process

## Support

For issues or questions:
1. Check `Experts` tab for news state messages
2. Run `Print(g_news_filter_integration.GetStatistics())`
3. Verify `news_blackouts.csv` in `Common Files/DualEA/`
4. Check `CErrorRecovery::Instance().GetErrorStats()`
