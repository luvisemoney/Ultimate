//+------------------------------------------------------------------+
//| AdvancedRegimeDetector.mqh                                       |
//| Sophisticated regime detection with ADX/ATR/HHLL classification  |
//+------------------------------------------------------------------+
#property copyright "DualEA Advanced Regime System"
#property version   "1.00"

//+------------------------------------------------------------------+
//| REGIME TYPES ENUM                                                |
//+------------------------------------------------------------------+
enum ENUM_REGIME_TYPE
{
    REGIME_TRENDING_UP,      // Strong upward trend
    REGIME_TRENDING_DOWN,    // Strong downward trend
    REGIME_RANGING_LOW,      // Low volatility range
    REGIME_RANGING_HIGH,     // High volatility range
    REGIME_VOLATILE_UP,      // Volatile upward movement
    REGIME_VOLATILE_DOWN,    // Volatile downward movement
    REGIME_CHOPPY,           // Choppy/noisy market
    REGIME_BREAKING_UP,      // Breaking out upward
    REGIME_BREAKING_DOWN,    // Breaking out downward
    REGIME_UNDEFINED         // Undefined/transition
};

//+------------------------------------------------------------------+
//| REGIME INDICATORS STRUCT                                         |
//+------------------------------------------------------------------+
struct SRegimeIndicators
{
    double adx_value;           // ADX value
    double adx_plus;            // ADX+ value
    double adx_minus;           // ADX- value
    double atr_value;           // ATR value
    double atr_percentile;      // ATR percentile (0-100)
    double hhll_range;          // High-Low range
    double avg_true_range;      // Average true range
    double volatility_percentile; // Volatility percentile
    double trend_strength;      // Trend strength (0-1)
    double range_strength;      // Range strength (0-1)
    double breakout_strength;   // Breakout strength (0-1)
    
    SRegimeIndicators() : 
        adx_value(0), adx_plus(0), adx_minus(0), atr_value(0), atr_percentile(0),
        hhll_range(0), avg_true_range(0), volatility_percentile(0), 
        trend_strength(0), range_strength(0), breakout_strength(0) {}
};

//+------------------------------------------------------------------+
//| REGIME RESULT STRUCT                                             |
//+------------------------------------------------------------------+
struct SRegimeResult
{
    ENUM_REGIME_TYPE current_regime;
    ENUM_REGIME_TYPE previous_regime;
    double confidence;          // Confidence level (0-1)
    string description;         // Human-readable description
    datetime timestamp;         // Regime timestamp
    int duration_bars;          // Duration in bars
    SRegimeIndicators indicators; // Supporting indicators
    
    SRegimeResult() : 
        current_regime(REGIME_UNDEFINED), previous_regime(REGIME_UNDEFINED),
        confidence(0), duration_bars(0), timestamp(0) {}
};

//+------------------------------------------------------------------+
//| ADVANCED REGIME DETECTOR CLASS                                   |
//+------------------------------------------------------------------+
class CAdvancedRegimeDetector
{
private:
    string m_symbol;
    int m_timeframe;
    int m_adx_period;
    int m_atr_period;
    int m_hhll_period;
    int m_lookback_bars;
    
    // Historical data
    double m_adx_buffer[];
    double m_atr_buffer[];
    double m_high_buffer[];
    double m_low_buffer[];
    double m_close_buffer[];
    
    // Thresholds
    double m_adx_trend_threshold;
    double m_adx_strong_trend_threshold;
    double m_atr_high_threshold;
    double m_atr_low_threshold;
    double m_volatility_percentile_high;
    double m_volatility_percentile_low;
    
    // State tracking
    SRegimeResult m_last_regime;
    int m_regime_duration;
    
public:
    CAdvancedRegimeDetector(const string symbol, const int timeframe);
    ~CAdvancedRegimeDetector();
    
    // Configuration
    void SetADXPeriod(const int period) { m_adx_period = period; }
    void SetATRPeriod(const int period) { m_atr_period = period; }
    void SetHHLLPeriod(const int period) { m_hhll_period = period; }
    void SetLookbackBars(const int bars) { m_lookback_bars = bars; }
    void SetADXThresholds(const double trend, const double strong) 
    { 
        m_adx_trend_threshold = trend; 
        m_adx_strong_trend_threshold = strong; 
    }
    void SetATRThresholds(const double high, const double low)
    {
        m_atr_high_threshold = high;
        m_atr_low_threshold = low;
    }
    void SetVolatilityThresholds(const double high, const double low)
    {
        m_volatility_percentile_high = high;
        m_volatility_percentile_low = low;
    }
    
    // Main detection methods
    SRegimeResult DetectCurrentRegime();
    SRegimeResult GetLastRegime() const { return m_last_regime; }
    
    // Indicator calculations
    double CalculateADX(const int shift = 0);
    double CalculateATR(const int shift = 0);
    double CalculateHHLLRange(const int shift = 0);
    double CalculateVolatilityPercentile(const int bars);
    double CalculateTrendStrength();
    double CalculateRangeStrength();
    double CalculateBreakoutStrength();
    
    // Utility methods
    string RegimeToString(const ENUM_REGIME_TYPE regime) const;
    ENUM_REGIME_TYPE DetermineRegime(const SRegimeIndicators& indicators);
    double CalculateRegimeConfidence(const ENUM_REGIME_TYPE regime, const SRegimeIndicators& indicators);
    
private:
    void UpdatePriceBuffers();
    void CalculateIndicators(SRegimeIndicators& indicators);
    bool IsTrending(const SRegimeIndicators& indicators);
    bool IsRanging(const SRegimeIndicators& indicators);
    bool IsVolatile(const SRegimeIndicators& indicators);
    bool IsBreakingOut(const SRegimeIndicators& indicators);
    bool IsChoppy(const SRegimeIndicators& indicators);
};

//+------------------------------------------------------------------+
//| CONSTRUCTOR                                                      |
//+------------------------------------------------------------------+
CAdvancedRegimeDetector::CAdvancedRegimeDetector(const string symbol, const int timeframe)
{
    m_symbol = symbol;
    m_timeframe = timeframe;
    
    // Default parameters
    m_adx_period = 14;
    m_atr_period = 14;
    m_hhll_period = 20;
    m_lookback_bars = 100;
    
    // Default thresholds
    m_adx_trend_threshold = 25.0;
    m_adx_strong_trend_threshold = 35.0;
    m_atr_high_threshold = 2.0;
    m_atr_low_threshold = 0.5;
    m_volatility_percentile_high = 75.0;
    m_volatility_percentile_low = 25.0;
    
    m_regime_duration = 0;
    m_last_regime.current_regime = REGIME_UNDEFINED;
    m_last_regime.timestamp = 0;
    
    ArrayResize(m_adx_buffer, m_lookback_bars);
    ArrayResize(m_atr_buffer, m_lookback_bars);
    ArrayResize(m_high_buffer, m_lookback_bars);
    ArrayResize(m_low_buffer, m_lookback_bars);
    ArrayResize(m_close_buffer, m_lookback_bars);
    
    ArrayInitialize(m_adx_buffer, 0);
    ArrayInitialize(m_atr_buffer, 0);
    ArrayInitialize(m_high_buffer, 0);
    ArrayInitialize(m_low_buffer, 0);
    ArrayInitialize(m_close_buffer, 0);
}

//+------------------------------------------------------------------+
//| DESTRUCTOR                                                       |
//+------------------------------------------------------------------+
CAdvancedRegimeDetector::~CAdvancedRegimeDetector()
{
    // Cleanup handled automatically
}

//+------------------------------------------------------------------+
//| DETECT CURRENT REGIME                                            |
//+------------------------------------------------------------------+
SRegimeResult CAdvancedRegimeDetector::DetectCurrentRegime()
{
    SRegimeResult result;
    result.timestamp = TimeCurrent();
    result.previous_regime = m_last_regime.current_regime;
    
    // Update price buffers
    UpdatePriceBuffers();
    
    // Calculate indicators
    SRegimeIndicators indicators;
    CalculateIndicators(indicators);
    
    // Determine regime
    result.current_regime = DetermineRegime(indicators);
    result.confidence = CalculateRegimeConfidence(result.current_regime, indicators);
    result.description = RegimeToString(result.current_regime);
    result.indicators = indicators;
    
    // Update duration
    if(result.current_regime == result.previous_regime)
    {
        m_regime_duration++;
    }
    else
    {
        m_regime_duration = 1;
    }
    result.duration_bars = m_regime_duration;
    
    // Store result
    m_last_regime = result;
    
    return result;
}

//+------------------------------------------------------------------+
//| UPDATE PRICE BUFFERS                                             |
//+------------------------------------------------------------------+
void CAdvancedRegimeDetector::UpdatePriceBuffers()
{
    // Shift arrays
    for(int i = m_lookback_bars - 1; i > 0; i--)
    {
        m_high_buffer[i] = m_high_buffer[i-1];
        m_low_buffer[i] = m_low_buffer[i-1];
        m_close_buffer[i] = m_close_buffer[i-1];
    }
    
    // Add latest data
    m_high_buffer[0] = iHigh(m_symbol, (ENUM_TIMEFRAMES)m_timeframe, 0);
    m_low_buffer[0]  = iLow(m_symbol, (ENUM_TIMEFRAMES)m_timeframe, 0);
    m_close_buffer[0]= iClose(m_symbol, (ENUM_TIMEFRAMES)m_timeframe, 0);
}

//+------------------------------------------------------------------+
//| CALCULATE INDICATORS                                             |
//+------------------------------------------------------------------+
void CAdvancedRegimeDetector::CalculateIndicators(SRegimeIndicators& indicators)
{
    // Calculate ADX
    indicators.adx_value = CalculateADX();
    {
        int adx_handle = iADX(m_symbol, (ENUM_TIMEFRAMES)m_timeframe, m_adx_period);
        if(adx_handle != INVALID_HANDLE)
        {
            double plus[1], minus[1];
            if(CopyBuffer(adx_handle, 1 /*PLUSDI*/, 0, 1, plus) > 0) indicators.adx_plus = plus[0];
            if(CopyBuffer(adx_handle, 2 /*MINUSDI*/, 0, 1, minus) > 0) indicators.adx_minus = minus[0];
        }
    }
    
    // Calculate ATR
    indicators.atr_value = CalculateATR();
    indicators.avg_true_range = indicators.atr_value;
    
    // Calculate HHLL range
    indicators.hhll_range = CalculateHHLLRange();
    
    // Calculate percentiles
    indicators.atr_percentile = CalculateVolatilityPercentile(m_lookback_bars);
    indicators.volatility_percentile = indicators.atr_percentile;
    
    // Calculate strengths
    indicators.trend_strength = CalculateTrendStrength();
    indicators.range_strength = CalculateRangeStrength();
    indicators.breakout_strength = CalculateBreakoutStrength();
}

//+------------------------------------------------------------------+
//| CALCULATE ADX                                                    |
//+------------------------------------------------------------------+
double CAdvancedRegimeDetector::CalculateADX(const int shift)
{
    int handle = iADX(m_symbol, (ENUM_TIMEFRAMES)m_timeframe, m_adx_period);
    if(handle == INVALID_HANDLE) return 0.0;
    double buf[1];
    if(CopyBuffer(handle, 0 /*MAIN*/, shift, 1, buf) <= 0) return 0.0;
    return buf[0];
}

//+------------------------------------------------------------------+
//| CALCULATE ATR                                                    |
//+------------------------------------------------------------------+
double CAdvancedRegimeDetector::CalculateATR(const int shift)
{
    int handle = iATR(m_symbol, (ENUM_TIMEFRAMES)m_timeframe, m_atr_period);
    if(handle == INVALID_HANDLE) return 0.0;
    double buf[1];
    if(CopyBuffer(handle, 0, shift, 1, buf) <= 0) return 0.0;
    return buf[0];
}

//+------------------------------------------------------------------+
//| CALCULATE HHLL RANGE                                             |
//+------------------------------------------------------------------+
double CAdvancedRegimeDetector::CalculateHHLLRange(const int shift)
{
    int hi_index = iHighest(m_symbol, (ENUM_TIMEFRAMES)m_timeframe, MODE_HIGH, m_hhll_period, shift);
    int lo_index = iLowest(m_symbol, (ENUM_TIMEFRAMES)m_timeframe, MODE_LOW, m_hhll_period, shift);
    double highest = iHigh(m_symbol, (ENUM_TIMEFRAMES)m_timeframe, hi_index);
    double lowest  = iLow(m_symbol, (ENUM_TIMEFRAMES)m_timeframe, lo_index);
    return highest - lowest;
}

//+------------------------------------------------------------------+
//| CALCULATE VOLATILITY PERCENTILE                                  |
//+------------------------------------------------------------------+
double CAdvancedRegimeDetector::CalculateVolatilityPercentile(const int bars)
{
    if(bars <= 0) return 50.0;
    
    double atr_values[];
    ArrayResize(atr_values, bars);
    
    for(int i = 0; i < bars; i++)
    {
        int h = iATR(m_symbol, (ENUM_TIMEFRAMES)m_timeframe, m_atr_period);
        if(h == INVALID_HANDLE) { atr_values[i] = 0.0; continue; }
        double b[1];
        if(CopyBuffer(h, 0, i, 1, b) <= 0) atr_values[i] = 0.0; else atr_values[i] = b[0];
    }
    
    double current_atr = atr_values[0];
    double percentile = 0;
    
    for(int i = 0; i < bars; i++)
    {
        if(atr_values[i] <= current_atr)
            percentile++;
    }
    
    return (percentile / bars) * 100.0;
}

//+------------------------------------------------------------------+
//| CALCULATE TREND STRENGTH                                         |
//+------------------------------------------------------------------+
double CAdvancedRegimeDetector::CalculateTrendStrength()
{
    double adx = CalculateADX();
    
    // Normalize ADX to 0-1 range
    if(adx >= m_adx_strong_trend_threshold)
        return 1.0;
    else if(adx <= m_adx_trend_threshold)
        return 0.0;
    else
        return (adx - m_adx_trend_threshold) / (m_adx_strong_trend_threshold - m_adx_trend_threshold);
}

//+------------------------------------------------------------------+
//| CALCULATE RANGE STRENGTH                                         |
//+------------------------------------------------------------------+
double CAdvancedRegimeDetector::CalculateRangeStrength()
{
    double atr_percentile = CalculateVolatilityPercentile(m_lookback_bars);
    
    // Lower volatility suggests ranging
    if(atr_percentile <= m_volatility_percentile_low)
        return 1.0;
    else if(atr_percentile >= m_volatility_percentile_high)
        return 0.0;
    else
        return 1.0 - ((atr_percentile - m_volatility_percentile_low) / 
                     (m_volatility_percentile_high - m_volatility_percentile_low));
}

//+------------------------------------------------------------------+
//| CALCULATE BREAKOUT STRENGTH                                      |
//+------------------------------------------------------------------+
double CAdvancedRegimeDetector::CalculateBreakoutStrength()
{
    double atr_percentile = CalculateVolatilityPercentile(m_lookback_bars);
    double adx = CalculateADX();
    
    // High volatility + strong trend = breakout
    double volatility_factor = (atr_percentile - m_volatility_percentile_low) / 
                              (m_volatility_percentile_high - m_volatility_percentile_low);
    
    double trend_factor = CalculateTrendStrength();
    
    return MathMin(1.0, volatility_factor * trend_factor);
}

//+------------------------------------------------------------------+
//| DETERMINE REGIME                                                 |
//+------------------------------------------------------------------+
ENUM_REGIME_TYPE CAdvancedRegimeDetector::DetermineRegime(const SRegimeIndicators& indicators)
{
    // Check for undefined regime
    if(indicators.adx_value < 0 || indicators.atr_value <= 0)
        return REGIME_UNDEFINED;
    
    // Check for trending conditions
    bool is_trending = IsTrending(indicators);
    bool is_ranging = IsRanging(indicators);
    bool is_volatile = IsVolatile(indicators);
    bool is_breaking_out = IsBreakingOut(indicators);
    bool is_choppy = IsChoppy(indicators);
    
    // Determine regime based on conditions
    if(is_breaking_out && indicators.breakout_strength > 0.7)
    {
        if(indicators.adx_plus > indicators.adx_minus)
            return REGIME_BREAKING_UP;
        else
            return REGIME_BREAKING_DOWN;
    }
    
    if(is_trending && indicators.trend_strength > 0.8)
    {
        if(indicators.adx_plus > indicators.adx_minus)
            return REGIME_TRENDING_UP;
        else
            return REGIME_TRENDING_DOWN;
    }
    
    if(is_volatile && indicators.volatility_percentile > 75)
    {
        if(indicators.adx_plus > indicators.adx_minus)
            return REGIME_VOLATILE_UP;
        else
            return REGIME_VOLATILE_DOWN;
    }
    
    if(is_ranging && indicators.range_strength > 0.7)
    {
        if(indicators.volatility_percentile < 25)
            return REGIME_RANGING_LOW;
        else
            return REGIME_RANGING_HIGH;
    }
    
    if(is_choppy)
    {
        return REGIME_CHOPPY;
    }
    
    return REGIME_UNDEFINED;
}

//+------------------------------------------------------------------+
//| CHECK IF TRENDING                                                |
//+------------------------------------------------------------------+
bool CAdvancedRegimeDetector::IsTrending(const SRegimeIndicators& indicators)
{
    return indicators.adx_value >= m_adx_trend_threshold;
}

//+------------------------------------------------------------------+
//| CHECK IF RANGING                                                 |
//+------------------------------------------------------------------+
bool CAdvancedRegimeDetector::IsRanging(const SRegimeIndicators& indicators)
{
    return indicators.adx_value < m_adx_trend_threshold && 
           indicators.volatility_percentile <= m_volatility_percentile_high;
}

//+------------------------------------------------------------------+
//| CHECK IF VOLATILE                                                |
//+------------------------------------------------------------------+
bool CAdvancedRegimeDetector::IsVolatile(const SRegimeIndicators& indicators)
{
    return indicators.volatility_percentile > m_volatility_percentile_high;
}

//+------------------------------------------------------------------+
//| CHECK IF BREAKING OUT                                            |
//+------------------------------------------------------------------+
bool CAdvancedRegimeDetector::IsBreakingOut(const SRegimeIndicators& indicators)
{
    return indicators.breakout_strength > 0.6 && 
           indicators.adx_value >= m_adx_strong_trend_threshold;
}

//+------------------------------------------------------------------+
//| CHECK IF CHOPPY                                                  |
//+------------------------------------------------------------------+
bool CAdvancedRegimeDetector::IsChoppy(const SRegimeIndicators& indicators)
{
    return indicators.adx_value < m_adx_trend_threshold && 
           indicators.volatility_percentile > m_volatility_percentile_low &&
           indicators.volatility_percentile < m_volatility_percentile_high;
}

//+------------------------------------------------------------------+
//| CALCULATE REGIME CONFIDENCE                                      |
//+------------------------------------------------------------------+
double CAdvancedRegimeDetector::CalculateRegimeConfidence(const ENUM_REGIME_TYPE regime, 
                                                         const SRegimeIndicators& indicators)
{
    double confidence = 0.0;
    
    switch(regime)
    {
        case REGIME_TRENDING_UP:
        case REGIME_TRENDING_DOWN:
            confidence = indicators.trend_strength;
            break;
            
        case REGIME_RANGING_LOW:
        case REGIME_RANGING_HIGH:
            confidence = indicators.range_strength;
            break;
            
        case REGIME_VOLATILE_UP:
        case REGIME_VOLATILE_DOWN:
            confidence = indicators.volatility_percentile / 100.0;
            break;
            
        case REGIME_BREAKING_UP:
        case REGIME_BREAKING_DOWN:
            confidence = indicators.breakout_strength;
            break;
            
        case REGIME_CHOPPY:
            confidence = 0.5; // Medium confidence for choppy
            break;
            
        default:
            confidence = 0.0;
            break;
    }
    
    return MathMin(1.0, MathMax(0.0, confidence));
}

//+------------------------------------------------------------------+
//| REGIME TO STRING                                                 |
//+------------------------------------------------------------------+
string CAdvancedRegimeDetector::RegimeToString(const ENUM_REGIME_TYPE regime) const
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
