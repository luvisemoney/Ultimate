//+------------------------------------------------------------------+
//| AdaptiveEngine.mqh - NUCLEAR GRADE Universal Auto-Detection     |
//| Automatically adapts to ANY symbol and timeframe                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Symbol Profile Structure - Comprehensive Analysis               |
//+------------------------------------------------------------------+
struct SymbolProfile {
    string symbol;
    double avg_atr_ratio;          // ATR/Price ratio for volatility scaling
    double avg_spread_pct;         // Spread as % of price
    double volatility_percentile;  // Current volatility vs historical
    double liquidity_score;        // Volume-based liquidity assessment
    double optimal_sl_mult;        // Auto-calculated optimal SL
    double optimal_tp_mult;        // Auto-calculated optimal TP
    double risk_multiplier;        // Auto-calculated risk adjustment
    double timeframe_mult;         // Timeframe-specific multiplier
};

//+------------------------------------------------------------------+
//| Baseline Symbol Configurations (Fallback Only)                   |
//+------------------------------------------------------------------+
struct SymbolConfig {
    string symbol;
    double base_sl_mult;
    double base_tp_mult;
    double volatility_class;
    double spread_threshold;
};

SymbolConfig g_symbol_configs[] = {
    {"EURUSD", 150.0, 300.0, 1.0, 0.00020},
    {"GBPUSD", 180.0, 360.0, 1.2, 0.00025},
    {"USDJPY", 120.0, 240.0, 0.8, 0.00015},
    {"XAUUSD", 350.0, 700.0, 3.0, 0.50},
    {"AUDUSD", 150.0, 300.0, 1.1, 0.00022},
    {"USDCAD", 140.0, 280.0, 1.0, 0.00020},
    {"GBPJPY", 200.0, 400.0, 1.5, 0.00030},
    {"EURJPY", 160.0, 320.0, 1.2, 0.00025},
    {"BTCUSD", 800.0, 1600.0, 5.0, 10.0},
    {"USOIL", 500.0, 1000.0, 2.5, 0.05},
    {"NGAS", 400.0, 800.0, 3.5, 0.01}
};

//+------------------------------------------------------------------+
//| UNIVERSAL AUTO-DETECTION ENGINE - Works on ANY Symbol/Timeframe |
//+------------------------------------------------------------------+
class CUniversalDetector {
private:
    SymbolProfile m_profile;
    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    
public:
    CUniversalDetector() {}
    
    // Analyze any symbol and timeframe - returns optimized parameters
    SymbolProfile AnalyzeSymbol(const string symbol, const ENUM_TIMEFRAMES tf) {
        m_symbol = symbol;
        m_timeframe = tf;
        
        // Real-time ATR analysis
        int atr_handle = iATR(symbol, tf, 14);
        double atr_buffer[];
        ArraySetAsSeries(atr_buffer, true);
        double atr = 0.0;
        if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0) {
            atr = atr_buffer[0];
        }
        IndicatorRelease(atr_handle);
        
        // Current price for ratio calculation
        double price = SymbolInfoDouble(symbol, SYMBOL_BID);
        if(price <= 0) price = SymbolInfoDouble(symbol, SYMBOL_ASK);
        
        m_profile.symbol = symbol;
        m_profile.avg_atr_ratio = (price > 0) ? (atr / price) : 0.01;
        
        // Spread analysis
        double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
        m_profile.avg_spread_pct = (price > 0) ? ((spread / price) * 100.0) : 0.001;
        
        // Volatility percentile (20-period lookback)
        m_profile.volatility_percentile = CalculateVolatilityPercentile(symbol, tf, 20);
        
        // Liquidity score (volume-based)
        m_profile.liquidity_score = CalculateLiquidityScore(symbol, tf);
        
        // Timeframe multiplier
        m_profile.timeframe_mult = GetTimeframeMultiplier(tf);
        
        // Auto-calculate optimal parameters
        m_profile.optimal_sl_mult = CalculateOptimalSL(m_profile);
        m_profile.optimal_tp_mult = CalculateOptimalTP(m_profile);
        m_profile.risk_multiplier = CalculateOptimalRisk(m_profile);
        
        return m_profile;
    }
    
    SymbolProfile GetProfile() { return m_profile; }
    
private:
    // Calculate optimal SL based on symbol characteristics
    double CalculateOptimalSL(const SymbolProfile& profile) {
        double base_sl = 150.0;  // Default for EURUSD-like pairs
        
        // ATR-based scaling: higher volatility = wider SL
        double atr_scaling = 1.0 + (profile.avg_atr_ratio * 50.0);
        if(atr_scaling > 5.0) atr_scaling = 5.0;
        
        // Spread adjustment
        double spread_adj = MathMax(1.0, profile.avg_spread_pct * 20.0);
        if(spread_adj > 3.0) spread_adj = 3.0;
        
        // Timeframe scaling
        double tf_mult = profile.timeframe_mult;
        
        // Combined calculation
        double optimal_sl = base_sl * atr_scaling * spread_adj * tf_mult;
        
        // Clamp to reasonable range (50-2000 pips)
        return MathMax(50.0, MathMin(2000.0, optimal_sl));
    }
    
    // Calculate optimal TP based on SL and volatility
    double CalculateOptimalTP(const SymbolProfile& profile) {
        double sl = CalculateOptimalSL(profile);
        double base_ratio = 2.0;  // TP/SL ratio
        
        // Volatility bonus: higher volatility = higher TP potential
        double volatility_bonus = MapRange(profile.volatility_percentile, 0, 100, 0.0, 1.0);
        
        // Liquidity bonus: higher liquidity = tighter TP
        double liquidity_bonus = MapRange(profile.liquidity_score, 0, 100, 0.5, 0.0);
        
        double tp_ratio = base_ratio + volatility_bonus + liquidity_bonus;
        return sl * tp_ratio;
    }
    
    // Calculate optimal risk multiplier (AGGRESSIVE profile)
    double CalculateOptimalRisk(const SymbolProfile& profile) {
        double base_risk = 1.5;  // AGGRESSIVE: 1.5%
        
        // Reduce risk for high volatility
        double volatility_penalty = MapRange(profile.volatility_percentile, 0, 100, 1.2, 0.6);
        
        // Reduce risk for wide spreads
        double spread_penalty = MapRange(profile.avg_spread_pct, 0, 0.1, 1.0, 0.5);
        if(spread_penalty < 0.5) spread_penalty = 0.5;
        
        double optimal_risk = base_risk * volatility_penalty * spread_penalty;
        
        // Clamp to AGGRESSIVE range (0.5% - 3.0%)
        return MathMax(0.5, MathMin(3.0, optimal_risk));
    }
    
    // Calculate volatility percentile
    double CalculateVolatilityPercentile(const string symbol, const ENUM_TIMEFRAMES tf, const int lookback) {
        int atr_handle = iATR(symbol, tf, 14);
        double atr_values[];
        ArraySetAsSeries(atr_values, true);
        
        if(CopyBuffer(atr_handle, 0, 0, lookback, atr_values) < lookback) {
            IndicatorRelease(atr_handle);
            return 50.0;  // Default to median
        }
        
        double current_atr = atr_values[0];
        int count_below = 0;
        
        for(int i = 0; i < lookback; i++) {
            if(atr_values[i] <= current_atr) count_below++;
        }
        
        IndicatorRelease(atr_handle);
        return (double)count_below / (double)lookback * 100.0;
    }
    
    // Calculate liquidity score based on volume
    double CalculateLiquidityScore(const string symbol, const ENUM_TIMEFRAMES tf) {
        long volume[];
        ArraySetAsSeries(volume, true);
        
        if(CopyTickVolume(symbol, tf, 0, 20, volume) < 20) {
            return 50.0;  // Default to median
        }
        
        double avg_volume = 0.0;
        for(int i = 0; i < 20; i++) {
            avg_volume += (double)volume[i];
        }
        avg_volume /= 20.0;
        
        double current_volume = (double)volume[0];
        double ratio = (avg_volume > 0) ? (current_volume / avg_volume) : 1.0;
        
        return MathMin(100.0, ratio * 50.0);
    }
    
    // Timeframe multiplier
    double GetTimeframeMultiplier(const ENUM_TIMEFRAMES tf) {
        switch(tf) {
            case PERIOD_M1:  return 0.3;
            case PERIOD_M5:  return 0.5;
            case PERIOD_M15: return 0.75;
            case PERIOD_M30: return 1.0;
            case PERIOD_H1:  return 1.5;
            case PERIOD_H4:  return 2.5;
            case PERIOD_D1:  return 4.0;
            case PERIOD_W1:  return 8.0;
            default:         return 1.0;
        }
    }
    
    // Map value from input range to output range
    double MapRange(const double value, const double in_min, const double in_max,
                   const double out_min, const double out_max) {
        if(in_max == in_min) return out_min;
        double mapped = out_min + (value - in_min) * (out_max - out_min) / (in_max - in_min);
        return MathMax(out_min, MathMin(out_max, mapped));
    }
};

//+------------------------------------------------------------------+
//| LIVE ADAPTATION ENGINE - Evolves Parameters Based on Performance|
//+------------------------------------------------------------------+
class CLiveAdaptation {
private:
    struct PerformanceMetrics {
        double rolling_pf;      // Rolling profit factor
        double rolling_wr;      // Rolling win rate
        double rolling_dd;      // Rolling max drawdown
        double rolling_vol;     // Rolling volatility
        int trade_count;        // Total trades
        datetime last_update;   // Last update time
    };
    
    PerformanceMetrics m_metrics;
    
public:
    CLiveAdaptation() {
        m_metrics.rolling_pf = 1.0;
        m_metrics.rolling_wr = 0.5;
        m_metrics.rolling_dd = 0.0;
        m_metrics.rolling_vol = 1.0;
        m_metrics.trade_count = 0;
        m_metrics.last_update = 0;
    }
    
    // Update from live trading performance
    void UpdateFromLiveTrading(const double pf, const double wr, const double dd, const double vol) {
        m_metrics.rolling_pf = pf;
        m_metrics.rolling_wr = wr;
        m_metrics.rolling_dd = dd;
        m_metrics.rolling_vol = vol;
        m_metrics.trade_count++;
        m_metrics.last_update = TimeCurrent();
    }
    
    // Calculate adaptive adjustment multiplier
    double CalculateAdaptiveAdjustment() {
        if(m_metrics.trade_count < 10) return 1.0;  // Need minimum sample
        
        // Multi-factor adjustment
        double pf_component = MapRange(m_metrics.rolling_pf, 1.9, 3.0, 0.8, 1.2);
        double wr_component = MapRange(m_metrics.rolling_wr, 0.5, 1.0, 0.9, 1.1);
        double dd_component = MapRange(m_metrics.rolling_dd, 0.0, 0.05, 1.2, 0.7);
        double vol_component = MapRange(m_metrics.rolling_vol, 0.5, 2.0, 1.1, 0.9);
        
        // Weighted average
        double adjustment = (pf_component * 0.4 + wr_component * 0.3 + dd_component * 0.2 + vol_component * 0.1);
        
        // Clamp to reasonable range (0.7 - 1.3)
        return MathMax(0.7, MathMin(1.3, adjustment));
    }
    
    double GetProfitFactor() { return m_metrics.rolling_pf; }
    double GetWinRate() { return m_metrics.rolling_wr; }
    double GetDrawdown() { return m_metrics.rolling_dd; }
    int GetTradeCount() { return m_metrics.trade_count; }
    
private:
    double MapRange(const double value, const double in_min, const double in_max,
                   const double out_min, const double out_max) {
        if(in_max == in_min) return out_min;
        double mapped = out_min + (value - in_min) * (out_max - out_min) / (in_max - in_min);
        return MathMax(out_min, MathMin(out_max, mapped));
    }
};

//+------------------------------------------------------------------+
//| ENHANCED ADAPTIVE ENGINE - Integration Layer                    |
//+------------------------------------------------------------------+
class CAdaptiveEngine {
private:
    double m_current_atr;
    double m_current_spread;
    double m_volatility_percentile;
    double m_spread_percentile;
    CUniversalDetector m_detector;
    SymbolProfile m_current_profile;
    
public:
    CAdaptiveEngine() {
        m_current_atr = 0.0;
        m_current_spread = 0.0;
        m_volatility_percentile = 50.0;
        m_spread_percentile = 50.0;
    }
    
    // Calculate symbol-specific multipliers using UNIVERSAL DETECTOR
    void CalculateDynamicParameters(const string symbol, const ENUM_TIMEFRAMES timeframe) {
        // Use nuclear-grade universal detector
        m_current_profile = m_detector.AnalyzeSymbol(symbol, timeframe);
        
        // Legacy compatibility - extract key metrics
        int atr_handle = iATR(symbol, timeframe, 14);
        double atr_buffer[];
        ArraySetAsSeries(atr_buffer, true);
        if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0) {
            m_current_atr = atr_buffer[0];
        }
        IndicatorRelease(atr_handle);
        
        m_current_spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
        m_volatility_percentile = m_current_profile.volatility_percentile;
        m_spread_percentile = m_current_profile.avg_spread_pct;
        
        // Log auto-detection results
        PrintFormat("🎯 [AUTO-DETECT] %s %s | SL=%.1f TP=%.1f Risk=%.2f%% | ATR Ratio=%.4f Spread=%.3f%% Vol=%d%%",
                    symbol, EnumToString(timeframe),
                    m_current_profile.optimal_sl_mult,
                    m_current_profile.optimal_tp_mult,
                    m_current_profile.risk_multiplier,
                    m_current_profile.avg_atr_ratio,
                    m_current_profile.avg_spread_pct * 100,
                    (int)m_current_profile.volatility_percentile);
    }
    
    // Get adjusted stop loss in pips - USES UNIVERSAL DETECTOR RESULTS
    double GetDynamicSL(const string symbol, const ENUM_TIMEFRAMES timeframe) {
        // Return optimal SL calculated by universal detector
        if(m_current_profile.symbol == symbol) {
            return m_current_profile.optimal_sl_mult;
        }
        
        // Fallback: recalculate
        SymbolProfile profile = m_detector.AnalyzeSymbol(symbol, timeframe);
        return profile.optimal_sl_mult;
    }
    
    // Get adjusted take profit in pips - USES UNIVERSAL DETECTOR RESULTS
    double GetDynamicTP(const string symbol, const ENUM_TIMEFRAMES timeframe) {
        // Return optimal TP calculated by universal detector
        if(m_current_profile.symbol == symbol) {
            return m_current_profile.optimal_tp_mult;
        }
        
        // Fallback: recalculate
        SymbolProfile profile = m_detector.AnalyzeSymbol(symbol, timeframe);
        return profile.optimal_tp_mult;
    }
    
    // Get risk-adjusted position size - USES UNIVERSAL DETECTOR RESULTS
    double GetDynamicRisk(const string risk_profile) {
        // Use optimal risk from universal detector (already tuned for AGGRESSIVE)
        if(m_current_profile.symbol != "") {
            return m_current_profile.risk_multiplier;
        }
        
        // Fallback to manual calculation
        double base_risk = 1.0;
        if(risk_profile == "CONSERVATIVE") base_risk = 0.5;
        else if(risk_profile == "MODERATE") base_risk = 1.0;
        else if(risk_profile == "AGGRESSIVE") base_risk = 1.5;
        
        // Reduce risk in high volatility
        double volatility_penalty = MapRange(m_volatility_percentile, 0, 100, 1.2, 0.6);
        
        return base_risk * volatility_penalty;
    }
    
    // Get current symbol profile
    SymbolProfile GetCurrentProfile() {
        return m_current_profile;
    }
    
private:
    double GetSymbolBaseSL(const string symbol) {
        for(int i = 0; i < ArraySize(g_symbol_configs); i++) {
            if(StringFind(symbol, g_symbol_configs[i].symbol) >= 0) {
                return g_symbol_configs[i].base_sl_mult;
            }
        }
        return 10.0; // Default fallback
    }
    
    double GetSymbolBaseTP(const string symbol) {
        for(int i = 0; i < ArraySize(g_symbol_configs); i++) {
            if(StringFind(symbol, g_symbol_configs[i].symbol) >= 0) {
                return g_symbol_configs[i].base_tp_mult;
            }
        }
        return 20.0; // Default fallback
    }
    
    double GetTimeframeMultiplier(const int timeframe) {
        switch(timeframe) {
            case PERIOD_M1: return 0.25;
            case PERIOD_M5: return 0.5;
            case PERIOD_M15: return 0.75;
            case PERIOD_M30: return 1.0;
            case PERIOD_H1: return 1.5;
            case PERIOD_H4: return 2.5;
            case PERIOD_D1: return 5.0;
            default: return 1.0;
        }
    }
    
    double CalculateATRPercentile(const string symbol, const ENUM_TIMEFRAMES tf, const int lookback) {
        int atr_handle = iATR(symbol, tf, 14);
        double atr_values[];
        ArraySetAsSeries(atr_values, true);
        
        if(CopyBuffer(atr_handle, 0, 0, lookback, atr_values) < lookback) {
            IndicatorRelease(atr_handle);
            return 50.0;  // Default to median on error
        }
        
        double current_atr = atr_values[0];
        IndicatorRelease(atr_handle);
        
        return CalculatePercentile(atr_values, current_atr);
    }
    
    double CalculateSpreadPercentile(const string symbol, const int lookback) {
        double spread_values[];
        ArrayResize(spread_values, lookback);
        
        for(int i = 0; i < lookback; i++) {
            spread_values[i] = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
        }
        
        return CalculatePercentile(spread_values, 
                                  SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT));
    }
    
    double CalculatePercentile(const double &values[], const double current_value) {
        int count = 0;
        for(int i = 0; i < ArraySize(values); i++) {
            if(values[i] <= current_value) count++;
        }
        return (double)count / ArraySize(values) * 100.0;
    }
    
    double MapRange(const double value, const double in_min, const double in_max, 
                   const double out_min, const double out_max) {
        return out_min + (value - in_min) * (out_max - out_min) / (in_max - in_min);
    }
};

//+------------------------------------------------------------------+
//| Machine Learning Adaptation Engine                               |
//+------------------------------------------------------------------+
class CMLAdaptationEngine {
private:
    double m_recent_pf;
    double m_recent_wr;
    double m_recent_dd;
    double m_recent_vol;
    
public:
    CMLAdaptationEngine() {
        m_recent_pf = 1.2;
        m_recent_wr = 0.5;
        m_recent_dd = 0.1;
        m_recent_vol = 1.0;
    }
    
    // Calculate ML-based parameter adjustment
    double CalculateAdjustment(const double profit_factor, const double win_rate, 
                              const double max_drawdown, const double volatility) {
        
        // Performance score (0-100)
        double perf_score = 0.0;
        perf_score += profit_factor * 25.0;  // Max 50
        perf_score += win_rate * 50.0;       // Max 50
        perf_score -= max_drawdown * 200.0;  // Penalty for drawdown
        perf_score = MathMax(0.0, MathMin(100.0, perf_score));
        
        // Volatility adjustment factor
        double vol_factor = MapRange(volatility, 0.5, 3.0, 1.2, 0.8);
        
        // Combined adjustment
        double adjustment = 1.0 + (perf_score - 50.0) / 100.0 * vol_factor;
        return MathMax(0.5, MathMin(2.0, adjustment));
    }
    
    // Get recent performance metrics
    double GetRecentProfitFactor(const int lookback_trades) {
        // Implementation would query KnowledgeBase or trade history
        return 1.2 + (MathRand() % 100 - 50) / 500.0; // Simulated: 1.0 to 1.4
    }
    
    double GetRecentWinRate(const int lookback_trades) {
        // Implementation would query KnowledgeBase or trade history
        return 0.45 + (MathRand() % 20) / 100.0; // Simulated: 0.45 to 0.65
    }
    
    double GetRecentMaxDrawdown(const int lookback_trades) {
        // Implementation would query KnowledgeBase or trade history
        return 0.05 + (MathRand() % 15) / 100.0; // Simulated: 0.05 to 0.20
    }
    
    double GetRecentVolatility(const int lookback_bars) {
        // Calculate recent volatility from price data
        return 1.0 + (MathRand() % 100 - 50) / 100.0; // Simulated: 0.5 to 1.5
    }
    
private:
    double MapRange(const double value, const double in_min, const double in_max,
                   const double out_min, const double out_max) {
        if(in_max == in_min) return out_min;
        double mapped = out_min + (value - in_min) * (out_max - out_min) / (in_max - in_min);
        return MathMax(out_min, MathMin(out_max, mapped));
    }
};

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
double GetSymbolSLMultiplier(const string symbol) {
    for(int i = 0; i < ArraySize(g_symbol_configs); i++) {
        if(StringFind(symbol, g_symbol_configs[i].symbol) >= 0) {
            return g_symbol_configs[i].base_sl_mult;
        }
    }
    return 10.0; // Default fallback
}

double GetSymbolTPMultiplier(const string symbol) {
    for(int i = 0; i < ArraySize(g_symbol_configs); i++) {
        if(StringFind(symbol, g_symbol_configs[i].symbol) >= 0) {
            return g_symbol_configs[i].base_tp_mult;
        }
    }
    return 20.0; // Default fallback
}
