//+------------------------------------------------------------------+
//| AdvancedSignalProcessor.mqh                                      |
//| JAILBREAK LEVEL 5 - INSTITUTIONAL SIGNAL PROCESSING             |
//| High-Frequency Multi-Dimensional Signal Analysis                |
//+------------------------------------------------------------------+
#property copyright "EscapeEA - Jailbreak Level 5 Signal Processing"
#property version   "1.00"
#property strict

#include <Object.mqh>
#include <Arrays\Array.mqh>
#include <Arrays\ArrayObj.mqh>
#include "..\Utils\JailbreakLogger.mqh"

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
class CSignalResult : public CObject
{
public:
    ENUM_SIGNAL_TYPE type;
    double confidence;
    double strength;
    datetime timestamp;
    int sources;  // Bitfield of ENUM_SIGNAL_SOURCE
    bool validated;
    string validationErrors;
    int validationLevel;
    bool hasStateConflict;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    string reason;
    
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
    }
    
    CSignalResult(const CSignalResult& other)
    {
        type = other.type;
        confidence = other.confidence;
        strength = other.strength;
        timestamp = other.timestamp;
        sources = other.sources;
        entryPrice = other.entryPrice;
        stopLoss = other.stopLoss;
        takeProfit = other.takeProfit;
        reason = other.reason;
    }
};

//+------------------------------------------------------------------+
//| JAILBREAK SIGNALS: Advanced Signal Processor Class              |
//+------------------------------------------------------------------+
class CAdvancedSignalProcessor
{
private:
    // Configuration
    bool m_enableML;
    double m_confidenceThreshold;
    CJailbreakLogger* m_logger;
    
    // Signal history
    CArrayObj m_signalHistory;
    
    // Performance tracking
    ulong m_totalSignals;
    ulong m_validSignals;
    ulong m_averageProcessingTime;
    
public:
    CAdvancedSignalProcessor();
    ~CAdvancedSignalProcessor();
    
    // Initialization
    bool Initialize(const bool enableML, const double confidenceThreshold);
    void SetLogger(CJailbreakLogger* logger) { m_logger = logger; }
    
    // Signal processing
    bool ProcessTickAdvanced(CSignalResult &result);
    bool ValidateSignal(CSignalResult &signal);
    void AddSignalSource(CSignalResult &signal, ENUM_SIGNAL_SOURCE source);
    
    // History management
    void AddToHistory(const CSignalResult &signal);
    void CleanupHistory();
    
    // Statistics
    double GetSignalSuccessRate() const;
    ulong GetAverageProcessingTime() const { return m_averageProcessingTime; }
    ulong GetTotalSignals() const { return m_totalSignals; }
    ulong GetValidSignals() const { return m_validSignals; }
    
private:
    bool ProcessTechnicalSignals(CSignalResult &signal);
    bool ProcessFundamentalSignals(CSignalResult &signal);
    bool ProcessSentimentSignals(CSignalResult &signal);
    bool ProcessMLSignals(CSignalResult &signal);
    bool ProcessPatternSignals(CSignalResult &signal);
    bool ProcessVolumeSignals(CSignalResult &signal);
    
    void UpdatePerformanceMetrics(const ulong processingTime);
    bool IsSignalValid(const CSignalResult &signal) const;
    void LogSignalMetrics(const CSignalResult &signal, const bool validated);
};
