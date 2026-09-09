//+------------------------------------------------------------------+
//| regime_adaptation.mqh                                            |
//| Regime-based parameter adaptation functions for PaperEA_v2       |
#include "../Include/AdvancedRegimeDetector.mqh"
#include "../Include/CorrelationManager.mqh"


//+------------------------------------------------------------------+
//| REGIME-BASED PARAMETER ADAPTATION                                |
//+------------------------------------------------------------------+
void AdaptParametersToRegime(const SRegimeResult& regime)
{
    if(!UseRegimeGate) return;
    
    double risk_multiplier = 1.0;
    double sl_multiplier = 1.0;
    double tp_multiplier = 1.0;
    
    switch(regime.current_regime)
    {
        case REGIME_TRENDING_UP:
        case REGIME_TRENDING_DOWN:
            // Increase risk in trending markets
            risk_multiplier = 1.2;
            sl_multiplier = 1.1;
            tp_multiplier = 1.3;
            break;
            
        case REGIME_RANGING_LOW:
            // Conservative in low volatility ranges
            risk_multiplier = 0.7;
            sl_multiplier = 0.8;
            tp_multiplier = 0.9;
            break;
            
        case REGIME_RANGING_HIGH:
            // Moderate in high volatility ranges
            risk_multiplier = 0.9;
            sl_multiplier = 1.0;
            tp_multiplier = 1.1;
            break;
            
        case REGIME_VOLATILE_UP:
        case REGIME_VOLATILE_DOWN:
            // Reduce risk in volatile conditions
            risk_multiplier = 0.6;
            sl_multiplier = 1.2;
            tp_multiplier = 1.5;
            break;
            
        case REGIME_BREAKING_UP:
        case REGIME_BREAKING_DOWN:
            // Aggressive in breakout conditions
            risk_multiplier = 1.4;
            sl_multiplier = 0.9;
            tp_multiplier = 1.6;
            break;
            
        case REGIME_CHOPPY:
            // Minimal risk in choppy markets
            risk_multiplier = 0.5;
            sl_multiplier = 0.7;
            tp_multiplier = 0.8;
            break;
            
        default:
            // Default settings
            risk_multiplier = 1.0;
            sl_multiplier = 1.0;
            tp_multiplier = 1.0;
            break;
    }
    
    // Apply adaptations with confidence weighting
    double confidence_factor = regime.confidence;
    
    // Update dynamic parameters
    if(AllowManualOverride || VolSizerTargetRisk == VolSizerTargetRisk_Input)
    {
        VolSizerTargetRisk = VolSizerTargetRisk_Input * risk_multiplier * confidence_factor;
        VolSizerTargetRisk = MathMax(0.1, MathMin(5.0, VolSizerTargetRisk));
    }
    
    if(AllowManualOverride || StopLossPips == StopLossPips_Input)
    {
        StopLossPips = StopLossPips_Input * sl_multiplier * confidence_factor;
        StopLossPips = MathMax(50, MathMin(500, StopLossPips));
    }
    
    if(AllowManualOverride || TakeProfitPips == TakeProfitPips_Input)
    {
        TakeProfitPips = TakeProfitPips_Input * tp_multiplier * confidence_factor;
        TakeProfitPips = MathMax(100, MathMin(1000, TakeProfitPips));
    }
    
    // Update gating thresholds based on regime
    if(AllowManualOverride || P5_MinPF == P5_MinPF_Input)
    {
        P5_MinPF = P5_MinPF_Input * (2.0 - risk_multiplier) * confidence_factor;
        P5_MinPF = MathMax(1.0, MathMin(2.0, P5_MinPF));
    }
    
    if(AllowManualOverride || P5_MinWR == P5_MinWR_Input)
    {
        P5_MinWR = P5_MinWR_Input * (1.5 - risk_multiplier * 0.3) * confidence_factor;
        P5_MinWR = MathMax(0.3, MathMin(0.7, P5_MinWR));
    }
    
    if(AllowManualOverride || CBDailyLossLimitPct == CBDailyLossLimitPct_Input)
    {
        CBDailyLossLimitPct = CBDailyLossLimitPct_Input * (2.0 - risk_multiplier) * confidence_factor;
        CBDailyLossLimitPct = MathMax(1.0, MathMin(10.0, CBDailyLossLimitPct));
    }
    
    // Log parameter adaptations
    if(Verbosity >= 1)
    {
        PrintFormat("🔧 Regime Adaptation: %s (%.2f) -> Risk=%.2f%% SL=%.1f TP=%.1f PF=%.2f WR=%.2f",
                    RegimeToString(regime.current_regime),
                    regime.confidence,
                    VolSizerTargetRisk, StopLossPips, TakeProfitPips,
                    P5_MinPF, P5_MinWR);
    }
}

//+------------------------------------------------------------------+
//| REGIME TO STRING UTILITY                                         |
//+------------------------------------------------------------------+
string RegimeToString(const ENUM_REGIME_TYPE regime)
{
    switch(regime)
    {
        case REGIME_TRENDING_UP:     return "TRENDING_UP";
        case REGIME_TRENDING_DOWN:   return "TRENDING_DOWN";
        case REGIME_RANGING_LOW:     return "RANGING_LOW";
        case REGIME_RANGING_HIGH:    return "RANGING_HIGH";
        case REGIME_VOLATILE_UP:     return "VOLATILE_UP";
        case REGIME_VOLATILE_DOWN:   return "VOLATILE_DOWN";
        case REGIME_CHOPPY:          return "CHOPPY";
        case REGIME_BREAKING_UP:     return "BREAKING_UP";
        case REGIME_BREAKING_DOWN:   return "BREAKING_DOWN";
        case REGIME_UNDEFINED:       return "UNDEFINED";
        default:                     return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| GET MARKET REGIME STRING                                         |
//+------------------------------------------------------------------+
string GetMarketRegime()
{
    if(CheckPointer(g_regime_detector) != POINTER_INVALID && UseRegimeGate)
    {
        SRegimeResult regime = (*g_regime_detector).GetLastRegime();
        return RegimeToString(regime.current_regime);
    }
    return "REGIME_DISABLED";
}

//+------------------------------------------------------------------+
//| GET CURRENT VOLATILITY                                           |
//+------------------------------------------------------------------+
double GetVolatility(string symbol, ENUM_TIMEFRAMES timeframe)
{
    int atr_handle = iATR(symbol, timeframe, ATRRegimePeriod);
    if(atr_handle == INVALID_HANDLE) return 0.0;
    
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) <= 0)
    {
        IndicatorRelease(atr_handle);
        return 0.0;
    }
    double atr = atr_buffer[0];
    IndicatorRelease(atr_handle);
    
    if(atr <= 0) return 0.0;
    
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    if(price <= 0) return 0.0;
    
    return (atr / price) * 100.0;
}

//+------------------------------------------------------------------+
//| GET CORRELATION VALUE                                            |
//+------------------------------------------------------------------+
double GetCorrelation()
{
    if(CheckPointer(g_correlation_manager) != POINTER_INVALID && UseCorrelationManager)
    {
        // Return average correlation with other active positions
        // For simplicity, return 0.0 as placeholder
        return 0.0;
    }
    return 0.0;
}
