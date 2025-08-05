//+------------------------------------------------------------------+
//| AdvancedSignalProcessor.mqh                                      |
//| JAILBREAK LEVEL 5 - INSTITUTIONAL SIGNAL PROCESSING             |
//| High-Frequency Multi-Dimensional Signal Analysis                |
//+------------------------------------------------------------------+
#property copyright "EscapeEA - Jailbreak Level 5 Signal Processing"
#property version   "1.00"
#property strict

//--- JAILBREAK SIGNALS: Signal processing constants
#define MAX_SIGNAL_HISTORY 1000
#define SIGNAL_CONFIDENCE_THRESHOLD 0.7
#define MAX_SIGNAL_AGE_SECONDS 60
#define SIGNAL_VALIDATION_LAYERS 6

//--- JAILBREAK SIGNALS: Signal types
enum ENUM_SIGNAL_TYPE
{
    SIGNAL_NONE = 0,
    SIGNAL_BUY = 1,
    SIGNAL_SELL = 2,
    SIGNAL_CLOSE_BUY = 3,
    SIGNAL_CLOSE_SELL = 4
};

//--- JAILBREAK SIGNALS: Signal sources
enum ENUM_SIGNAL_SOURCE
{
    SOURCE_TECHNICAL = 1,
    SOURCE_FUNDAMENTAL = 2,
    SOURCE_SENTIMENT = 4,
    SOURCE_ML = 8,
    SOURCE_PATTERN = 16,
    SOURCE_VOLUME = 32
};

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Signal Result Structure                      |
//+------------------------------------------------------------------+
struct CSignalResult
{
    ENUM_SIGNAL_TYPE type;
    double confidence;
    double strength;
    datetime timestamp;
    int sources;  // Bitfield of ENUM_SIGNAL_SOURCE
    double entryPrice;
    double stopLoss;
    double takeProfit;
    string reason;
    bool isValid;
    
    // Constructor
    CSignalResult()
    {
        type = SIGNAL_NONE;
        confidence = 0.0;
        strength = 0.0;
        timestamp = 0;
        sources = 0;
        entryPrice = 0.0;
        stopLoss = 0.0;
        takeProfit = 0.0;
        reason = "";
        isValid = false;
    }
};

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Market Data Structure                        |
//+------------------------------------------------------------------+
struct CMarketData
{
    double bid;
    double ask;
    double spread;
    long volume;
    datetime timestamp;
    
    // Technical indicators
    double ma_fast;
    double ma_slow;
    double rsi;
    double macd_main;
    double macd_signal;
    double bb_upper;
    double bb_lower;
    double bb_middle;
    double atr;
    
    CMarketData()
    {
        bid = 0.0;
        ask = 0.0;
        spread = 0.0;
        volume = 0;
        timestamp = 0;
        ma_fast = 0.0;
        ma_slow = 0.0;
        rsi = 0.0;
        macd_main = 0.0;
        macd_signal = 0.0;
        bb_upper = 0.0;
        bb_lower = 0.0;
        bb_middle = 0.0;
        atr = 0.0;
    }
};

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Advanced Signal Processor Class              |
//+------------------------------------------------------------------+
class CAdvancedSignalProcessor
{
private:
    // JAILBREAK SIGNALS: Configuration
    bool m_isInitialized;
    bool m_mlEnabled;
    double m_confidenceThreshold;
    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    
    // JAILBREAK SIGNALS: Technical indicators handles
    int m_maFastHandle;
    int m_maSlowHandle;
    int m_rsiHandle;
    int m_macdHandle;
    int m_bbHandle;
    int m_atrHandle;
    
    // JAILBREAK SIGNALS: Signal history
    CSignalResult m_signalHistory[MAX_SIGNAL_HISTORY];
    int m_historyIndex;
    int m_totalSignals;
    
    // JAILBREAK SIGNALS: Performance metrics
    ulong m_processingTimeNs;
    ulong m_totalProcessedTicks;
    double m_signalAccuracy;
    int m_correctSignals;
    int m_totalValidatedSignals;
    
    // JAILBREAK SIGNALS: Market data cache
    CMarketData m_currentMarketData;
    CMarketData m_previousMarketData;
    datetime m_lastUpdate;
    
    // JAILBREAK SIGNALS: Internal methods
    bool UpdateMarketData();
    bool UpdateTechnicalIndicators();
    CSignalResult AnalyzeTechnicalSignals();
    CSignalResult AnalyzePatternSignals();
    CSignalResult AnalyzeVolumeSignals();
    CSignalResult CombineSignals(const CSignalResult& signals[], int count);
    bool ValidateSignal(const CSignalResult& signal);
    double CalculateSignalStrength(const CSignalResult& signal);
    void AddToHistory(const CSignalResult& signal);
    
public:
    // JAILBREAK SIGNALS: Constructor/Destructor
    CAdvancedSignalProcessor();
    ~CAdvancedSignalProcessor();
    
    // JAILBREAK SIGNALS: Initialization
    bool Initialize(bool mlEnabled = false, double confidenceThreshold = SIGNAL_CONFIDENCE_THRESHOLD);
    void Cleanup();
    
    // JAILBREAK SIGNALS: Core processing methods
    bool ProcessTickAdvanced(CSignalResult& result);
    bool GetCurrentSignal(CSignalResult& result);
    bool IsSignalValid(const CSignalResult& signal);
    
    // JAILBREAK SIGNALS: Signal analysis methods
    double GetSignalConfidence(ENUM_SIGNAL_TYPE type);
    int GetActiveSignalSources();
    datetime GetLastSignalTime();
    
    // JAILBREAK SIGNALS: Performance metrics
    ulong GetProcessingTime() const { return m_processingTimeNs; }
    double GetSignalAccuracy() const { return m_signalAccuracy; }
    int GetTotalSignals() const { return m_totalSignals; }
    
    // JAILBREAK SIGNALS: Market data access
    CMarketData GetCurrentMarketData() const { return m_currentMarketData; }
    bool IsMarketDataValid() const;
};

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Constructor                                   |
//+------------------------------------------------------------------+
CAdvancedSignalProcessor::CAdvancedSignalProcessor()
{
    m_isInitialized = false;
    m_mlEnabled = false;
    m_confidenceThreshold = SIGNAL_CONFIDENCE_THRESHOLD;
    m_symbol = Symbol();
    m_timeframe = PERIOD_CURRENT;
    
    // Initialize indicator handles
    m_maFastHandle = INVALID_HANDLE;
    m_maSlowHandle = INVALID_HANDLE;
    m_rsiHandle = INVALID_HANDLE;
    m_macdHandle = INVALID_HANDLE;
    m_bbHandle = INVALID_HANDLE;
    m_atrHandle = INVALID_HANDLE;
    
    // Initialize history
    m_historyIndex = 0;
    m_totalSignals = 0;
    
    // Initialize performance metrics
    m_processingTimeNs = 0;
    m_totalProcessedTicks = 0;
    m_signalAccuracy = 0.0;
    m_correctSignals = 0;
    m_totalValidatedSignals = 0;
    
    m_lastUpdate = 0;
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Destructor                                   |
//+------------------------------------------------------------------+
CAdvancedSignalProcessor::~CAdvancedSignalProcessor()
{
    Cleanup();
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Initialize Signal Processor                  |
//+------------------------------------------------------------------+
bool CAdvancedSignalProcessor::Initialize(bool mlEnabled = false, double confidenceThreshold = SIGNAL_CONFIDENCE_THRESHOLD)
{
    m_mlEnabled = mlEnabled;
    m_confidenceThreshold = confidenceThreshold;
    
    // JAILBREAK SIGNALS: Initialize technical indicators
    m_maFastHandle = iMA(m_symbol, m_timeframe, 10, 0, MODE_EMA, PRICE_CLOSE);
    if(m_maFastHandle == INVALID_HANDLE)
    {
        Print("JAILBREAK SIGNALS ERROR: Failed to create fast MA indicator");
        return false;
    }
    
    m_maSlowHandle = iMA(m_symbol, m_timeframe, 21, 0, MODE_EMA, PRICE_CLOSE);
    if(m_maSlowHandle == INVALID_HANDLE)
    {
        Print("JAILBREAK SIGNALS ERROR: Failed to create slow MA indicator");
        return false;
    }
    
    m_rsiHandle = iRSI(m_symbol, m_timeframe, 14, PRICE_CLOSE);
    if(m_rsiHandle == INVALID_HANDLE)
    {
        Print("JAILBREAK SIGNALS ERROR: Failed to create RSI indicator");
        return false;
    }
    
    m_macdHandle = iMACD(m_symbol, m_timeframe, 12, 26, 9, PRICE_CLOSE);
    if(m_macdHandle == INVALID_HANDLE)
    {
        Print("JAILBREAK SIGNALS ERROR: Failed to create MACD indicator");
        return false;
    }
    
    m_bbHandle = iBands(m_symbol, m_timeframe, 20, 0, 2.0, PRICE_CLOSE);
    if(m_bbHandle == INVALID_HANDLE)
    {
        Print("JAILBREAK SIGNALS ERROR: Failed to create Bollinger Bands indicator");
        return false;
    }
    
    m_atrHandle = iATR(m_symbol, m_timeframe, 14);
    if(m_atrHandle == INVALID_HANDLE)
    {
        Print("JAILBREAK SIGNALS ERROR: Failed to create ATR indicator");
        return false;
    }
    
    // JAILBREAK SIGNALS: Initialize signal history
    for(int i = 0; i < MAX_SIGNAL_HISTORY; i++)
    {
        m_signalHistory[i] = CSignalResult();
    }
    
    m_isInitialized = true;
    
    Print("JAILBREAK SIGNALS: Advanced signal processor initialized - ML: ", 
          m_mlEnabled ? "ENABLED" : "DISABLED", ", Confidence: ", m_confidenceThreshold);
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Cleanup Signal Processor                     |
//+------------------------------------------------------------------+
void CAdvancedSignalProcessor::Cleanup()
{
    if(m_isInitialized)
    {
        // JAILBREAK SIGNALS: Release indicator handles
        if(m_maFastHandle != INVALID_HANDLE) IndicatorRelease(m_maFastHandle);
        if(m_maSlowHandle != INVALID_HANDLE) IndicatorRelease(m_maSlowHandle);
        if(m_rsiHandle != INVALID_HANDLE) IndicatorRelease(m_rsiHandle);
        if(m_macdHandle != INVALID_HANDLE) IndicatorRelease(m_macdHandle);
        if(m_bbHandle != INVALID_HANDLE) IndicatorRelease(m_bbHandle);
        if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
        
        m_isInitialized = false;
        Print("JAILBREAK SIGNALS: Signal processor cleanup complete");
    }
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Process Tick Advanced                        |
//+------------------------------------------------------------------+
bool CAdvancedSignalProcessor::ProcessTickAdvanced(CSignalResult& result)
{
    if(!m_isInitialized)
    {
        result = CSignalResult();
        return false;
    }
    
    ulong startTime = GetMicrosecondCount();
    m_totalProcessedTicks++;
    
    // JAILBREAK SIGNALS: Update market data
    if(!UpdateMarketData())
    {
        result = CSignalResult();
        m_processingTimeNs = GetMicrosecondCount() - startTime;
        return false;
    }
    
    // JAILBREAK SIGNALS: Update technical indicators
    if(!UpdateTechnicalIndicators())
    {
        result = CSignalResult();
        m_processingTimeNs = GetMicrosecondCount() - startTime;
        return false;
    }
    
    // JAILBREAK SIGNALS: Analyze multiple signal sources
    CSignalResult signals[6];
    int signalCount = 0;
    
    // Technical analysis
    signals[signalCount] = AnalyzeTechnicalSignals();
    if(signals[signalCount].isValid) signalCount++;
    
    // Pattern analysis
    signals[signalCount] = AnalyzePatternSignals();
    if(signals[signalCount].isValid) signalCount++;
    
    // Volume analysis
    signals[signalCount] = AnalyzeVolumeSignals();
    if(signals[signalCount].isValid) signalCount++;
    
    // JAILBREAK SIGNALS: Combine signals
    if(signalCount > 0)
    {
        result = CombineSignals(signals, signalCount);
        
        // JAILBREAK SIGNALS: Validate combined signal
        if(ValidateSignal(result))
        {
            result.strength = CalculateSignalStrength(result);
            AddToHistory(result);
            m_totalSignals++;
        }
        else
        {
            result.isValid = false;
        }
    }
    else
    {
        result = CSignalResult();
    }
    
    m_processingTimeNs = GetMicrosecondCount() - startTime;
    return result.isValid;
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Update Market Data                           |
//+------------------------------------------------------------------+
bool CAdvancedSignalProcessor::UpdateMarketData()
{
    // JAILBREAK SIGNALS: Store previous data
    m_previousMarketData = m_currentMarketData;
    
    // JAILBREAK SIGNALS: Get current market data
    m_currentMarketData.bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    m_currentMarketData.ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    m_currentMarketData.spread = m_currentMarketData.ask - m_currentMarketData.bid;
    m_currentMarketData.volume = SymbolInfoInteger(m_symbol, SYMBOL_VOLUME);
    m_currentMarketData.timestamp = TimeCurrent();
    
    // JAILBREAK SIGNALS: Validate market data
    if(m_currentMarketData.bid <= 0 || m_currentMarketData.ask <= 0)
    {
        Print("JAILBREAK SIGNALS ERROR: Invalid market data");
        return false;
    }
    
    m_lastUpdate = m_currentMarketData.timestamp;
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Update Technical Indicators                  |
//+------------------------------------------------------------------+
bool CAdvancedSignalProcessor::UpdateTechnicalIndicators()
{
    double buffer[1];
    
    // JAILBREAK SIGNALS: Fast MA
    if(CopyBuffer(m_maFastHandle, 0, 0, 1, buffer) <= 0)
    {
        Print("JAILBREAK SIGNALS ERROR: Failed to get fast MA data");
        return false;
    }
    m_currentMarketData.ma_fast = buffer[0];
    
    // JAILBREAK SIGNALS: Slow MA
    if(CopyBuffer(m_maSlowHandle, 0, 0, 1, buffer) <= 0)
    {
        Print("JAILBREAK SIGNALS ERROR: Failed to get slow MA data");
        return false;
    }
    m_currentMarketData.ma_slow = buffer[0];
    
    // JAILBREAK SIGNALS: RSI
    if(CopyBuffer(m_rsiHandle, 0, 0, 1, buffer) <= 0)
    {
        Print("JAILBREAK SIGNALS ERROR: Failed to get RSI data");
        return false;
    }
    m_currentMarketData.rsi = buffer[0];
    
    // JAILBREAK SIGNALS: MACD
    if(CopyBuffer(m_macdHandle, 0, 0, 1, buffer) <= 0)
    {
        Print("JAILBREAK SIGNALS ERROR: Failed to get MACD main data");
        return false;
    }
    m_currentMarketData.macd_main = buffer[0];
    
    if(CopyBuffer(m_macdHandle, 1, 0, 1, buffer) <= 0)
    {
        Print("JAILBREAK SIGNALS ERROR: Failed to get MACD signal data");
        return false;
    }
    m_currentMarketData.macd_signal = buffer[0];
    
    // JAILBREAK SIGNALS: Bollinger Bands
    if(CopyBuffer(m_bbHandle, 0, 0, 1, buffer) <= 0)
    {
        Print("JAILBREAK SIGNALS ERROR: Failed to get BB middle data");
        return false;
    }
    m_currentMarketData.bb_middle = buffer[0];
    
    if(CopyBuffer(m_bbHandle, 1, 0, 1, buffer) <= 0)
    {
        Print("JAILBREAK SIGNALS ERROR: Failed to get BB upper data");
        return false;
    }
    m_currentMarketData.bb_upper = buffer[0];
    
    if(CopyBuffer(m_bbHandle, 2, 0, 1, buffer) <= 0)
    {
        Print("JAILBREAK SIGNALS ERROR: Failed to get BB lower data");
        return false;
    }
    m_currentMarketData.bb_lower = buffer[0];
    
    // JAILBREAK SIGNALS: ATR
    if(CopyBuffer(m_atrHandle, 0, 0, 1, buffer) <= 0)
    {
        Print("JAILBREAK SIGNALS ERROR: Failed to get ATR data");
        return false;
    }
    m_currentMarketData.atr = buffer[0];
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Analyze Technical Signals                    |
//+------------------------------------------------------------------+
CSignalResult CAdvancedSignalProcessor::AnalyzeTechnicalSignals()
{
    CSignalResult signal;
    signal.sources = SOURCE_TECHNICAL;
    signal.timestamp = m_currentMarketData.timestamp;
    
    double currentPrice = m_currentMarketData.bid;
    int signalScore = 0;
    int totalIndicators = 0;
    
    // JAILBREAK SIGNALS: Moving Average Crossover
    if(m_currentMarketData.ma_fast > m_currentMarketData.ma_slow && 
       m_previousMarketData.ma_fast <= m_previousMarketData.ma_slow)
    {
        signalScore += 2;  // Strong bullish signal
        signal.reason += "MA Bullish Crossover; ";
    }
    else if(m_currentMarketData.ma_fast < m_currentMarketData.ma_slow && 
            m_previousMarketData.ma_fast >= m_previousMarketData.ma_slow)
    {
        signalScore -= 2;  // Strong bearish signal
        signal.reason += "MA Bearish Crossover; ";
    }
    else if(m_currentMarketData.ma_fast > m_currentMarketData.ma_slow)
    {
        signalScore += 1;  // Bullish trend
    }
    else
    {
        signalScore -= 1;  // Bearish trend
    }
    totalIndicators++;
    
    // JAILBREAK SIGNALS: RSI Analysis
    if(m_currentMarketData.rsi < 30)
    {
        signalScore += 1;  // Oversold - bullish
        signal.reason += "RSI Oversold; ";
    }
    else if(m_currentMarketData.rsi > 70)
    {
        signalScore -= 1;  // Overbought - bearish
        signal.reason += "RSI Overbought; ";
    }
    totalIndicators++;
    
    // JAILBREAK SIGNALS: MACD Analysis
    if(m_currentMarketData.macd_main > m_currentMarketData.macd_signal && 
       m_previousMarketData.macd_main <= m_previousMarketData.macd_signal)
    {
        signalScore += 2;  // MACD bullish crossover
        signal.reason += "MACD Bullish Cross; ";
    }
    else if(m_currentMarketData.macd_main < m_currentMarketData.macd_signal && 
            m_previousMarketData.macd_main >= m_previousMarketData.macd_signal)
    {
        signalScore -= 2;  // MACD bearish crossover
        signal.reason += "MACD Bearish Cross; ";
    }
    totalIndicators++;
    
    // JAILBREAK SIGNALS: Bollinger Bands Analysis
    if(currentPrice <= m_currentMarketData.bb_lower)
    {
        signalScore += 1;  // Price at lower band - bullish
        signal.reason += "BB Lower Touch; ";
    }
    else if(currentPrice >= m_currentMarketData.bb_upper)
    {
        signalScore -= 1;  // Price at upper band - bearish
        signal.reason += "BB Upper Touch; ";
    }
    totalIndicators++;
    
    // JAILBREAK SIGNALS: Determine signal type and confidence
    if(signalScore >= 3)
    {
        signal.type = SIGNAL_BUY;
        signal.confidence = MathMin(1.0, (double)signalScore / (totalIndicators * 2));
        signal.entryPrice = m_currentMarketData.ask;
        signal.stopLoss = signal.entryPrice - m_currentMarketData.atr * 2;
        signal.takeProfit = signal.entryPrice + m_currentMarketData.atr * 3;
    }
    else if(signalScore <= -3)
    {
        signal.type = SIGNAL_SELL;
        signal.confidence = MathMin(1.0, (double)MathAbs(signalScore) / (totalIndicators * 2));
        signal.entryPrice = m_currentMarketData.bid;
        signal.stopLoss = signal.entryPrice + m_currentMarketData.atr * 2;
        signal.takeProfit = signal.entryPrice - m_currentMarketData.atr * 3;
    }
    else
    {
        signal.type = SIGNAL_NONE;
        signal.confidence = 0.0;
    }
    
    signal.isValid = (signal.type != SIGNAL_NONE && signal.confidence >= m_confidenceThreshold);
    
    return signal;
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Analyze Pattern Signals                      |
//+------------------------------------------------------------------+
CSignalResult CAdvancedSignalProcessor::AnalyzePatternSignals()
{
    CSignalResult signal;
    signal.sources = SOURCE_PATTERN;
    signal.timestamp = m_currentMarketData.timestamp;
    signal.type = SIGNAL_NONE;
    signal.confidence = 0.0;
    signal.isValid = false;
    
    // JAILBREAK SIGNALS: Placeholder for pattern analysis
    // In production, implement candlestick patterns, chart patterns, etc.
    
    return signal;
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Analyze Volume Signals                       |
//+------------------------------------------------------------------+
CSignalResult CAdvancedSignalProcessor::AnalyzeVolumeSignals()
{
    CSignalResult signal;
    signal.sources = SOURCE_VOLUME;
    signal.timestamp = m_currentMarketData.timestamp;
    signal.type = SIGNAL_NONE;
    signal.confidence = 0.0;
    signal.isValid = false;
    
    // JAILBREAK SIGNALS: Placeholder for volume analysis
    // In production, implement volume-based signals
    
    return signal;
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Combine Signals                              |
//+------------------------------------------------------------------+
CSignalResult CAdvancedSignalProcessor::CombineSignals(const CSignalResult& signals[], int count)
{
    CSignalResult combinedSignal;
    
    if(count == 0) return combinedSignal;
    
    // JAILBREAK SIGNALS: Weighted signal combination
    double totalWeight = 0.0;
    double weightedBuyScore = 0.0;
    double weightedSellScore = 0.0;
    int sources = 0;
    
    for(int i = 0; i < count; i++)
    {
        if(!signals[i].isValid) continue;
        
        double weight = signals[i].confidence;
        totalWeight += weight;
        sources |= signals[i].sources;
        
        if(signals[i].type == SIGNAL_BUY)
        {
            weightedBuyScore += weight;
        }
        else if(signals[i].type == SIGNAL_SELL)
        {
            weightedSellScore += weight;
        }
        
        combinedSignal.reason += signals[i].reason;
    }
    
    if(totalWeight == 0.0) return combinedSignal;
    
    // JAILBREAK SIGNALS: Determine combined signal
    combinedSignal.sources = sources;
    combinedSignal.timestamp = TimeCurrent();
    
    if(weightedBuyScore > weightedSellScore)
    {
        combinedSignal.type = SIGNAL_BUY;
        combinedSignal.confidence = weightedBuyScore / totalWeight;
        combinedSignal.entryPrice = m_currentMarketData.ask;
        combinedSignal.stopLoss = combinedSignal.entryPrice - m_currentMarketData.atr * 2;
        combinedSignal.takeProfit = combinedSignal.entryPrice + m_currentMarketData.atr * 3;
    }
    else if(weightedSellScore > weightedBuyScore)
    {
        combinedSignal.type = SIGNAL_SELL;
        combinedSignal.confidence = weightedSellScore / totalWeight;
        combinedSignal.entryPrice = m_currentMarketData.bid;
        combinedSignal.stopLoss = combinedSignal.entryPrice + m_currentMarketData.atr * 2;
        combinedSignal.takeProfit = combinedSignal.entryPrice - m_currentMarketData.atr * 3;
    }
    else
    {
        combinedSignal.type = SIGNAL_NONE;
        combinedSignal.confidence = 0.0;
    }
    
    combinedSignal.isValid = (combinedSignal.type != SIGNAL_NONE && 
                             combinedSignal.confidence >= m_confidenceThreshold);
    
    return combinedSignal;
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Validate Signal                              |
//+------------------------------------------------------------------+
bool CAdvancedSignalProcessor::ValidateSignal(const CSignalResult& signal)
{
    // JAILBREAK SIGNALS: Basic validation
    if(signal.type == SIGNAL_NONE) return false;
    if(signal.confidence < m_confidenceThreshold) return false;
    if(signal.timestamp == 0) return false;
    
    // JAILBREAK SIGNALS: Price validation
    if(signal.entryPrice <= 0) return false;
    if(signal.stopLoss <= 0) return false;
    if(signal.takeProfit <= 0) return false;
    
    // JAILBREAK SIGNALS: Risk-reward validation
    double risk = MathAbs(signal.entryPrice - signal.stopLoss);
    double reward = MathAbs(signal.takeProfit - signal.entryPrice);
    
    if(risk <= 0 || reward / risk < 1.5) return false;  // Minimum 1.5:1 RR
    
    return true;
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Calculate Signal Strength                    |
//+------------------------------------------------------------------+
double CAdvancedSignalProcessor::CalculateSignalStrength(const CSignalResult& signal)
{
    double strength = signal.confidence;
    
    // JAILBREAK SIGNALS: Adjust strength based on multiple factors
    int sourceCount = 0;
    int temp = signal.sources;
    while(temp > 0)
    {
        if(temp & 1) sourceCount++;
        temp >>= 1;
    }
    
    // JAILBREAK SIGNALS: Bonus for multiple sources
    strength *= (1.0 + sourceCount * 0.1);
    
    return MathMin(1.0, strength);
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Add To History                               |
//+------------------------------------------------------------------+
void CAdvancedSignalProcessor::AddToHistory(const CSignalResult& signal)
{
    m_signalHistory[m_historyIndex] = signal;
    m_historyIndex = (m_historyIndex + 1) % MAX_SIGNAL_HISTORY;
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Get Current Signal                           |
//+------------------------------------------------------------------+
bool CAdvancedSignalProcessor::GetCurrentSignal(CSignalResult& result)
{
    return ProcessTickAdvanced(result);
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Is Signal Valid                              |
//+------------------------------------------------------------------+
bool CAdvancedSignalProcessor::IsSignalValid(const CSignalResult& signal)
{
    return ValidateSignal(signal);
}

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Is Market Data Valid                         |
//+------------------------------------------------------------------+
bool CAdvancedSignalProcessor::IsMarketDataValid() const
{
    return (m_currentMarketData.bid > 0 && 
            m_currentMarketData.ask > 0 && 
            m_currentMarketData.timestamp > 0 &&
            (TimeCurrent() - m_currentMarketData.timestamp) < MAX_SIGNAL_AGE_SECONDS);
}