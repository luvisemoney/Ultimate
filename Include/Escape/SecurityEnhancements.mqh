//+------------------------------------------------------------------+
//|                                             SecurityEnhancements.mqh |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>

// Forward declaration to avoid circular dependency
class CRiskManager;

//+------------------------------------------------------------------+
//| CSecurityEnhancements class                                      |
//+------------------------------------------------------------------+
class CSecurityEnhancements
{
private:
   CRiskManager*     m_riskManager;           // Risk manager pointer
   CTrade           m_trade;                  // Trade object
   CPositionInfo    m_position;               // Position info
   CDealInfo        m_deal;                   // Deal info
   
   // Rate limiting
   datetime         m_lastTradeTime;          // Last trade time
   int              m_tradeCount;             // Trade counter
   
   // Anomaly detection
   double           m_avgTradeTime;           // Average trade time
   int              m_anomalyCount;           // Anomaly counter
   
   // Price validation
   MqlTick          m_lastTick;               // Last tick data
   int              m_maxSlippage;            // Maximum allowed slippage in points
   
   // Error tracking
   string           m_lastError;              // Last error message
   
   // News filtering
   bool             m_newsFilterEnabled;      // Whether news filtering is enabled
   datetime         m_newsStartTime;          // News start time
   datetime         m_newsEndTime;            // News end time
   string           m_affectedSymbols;        // Comma-separated list of affected symbols
   
public:
   // Constructor/Destructor
   CSecurityEnhancements(void);
   ~CSecurityEnhancements(void);
   
   // Initialization
   bool             Initialize(void);
   void             Deinitialize(void);
   
   // Configuration
   void             SetNewsFilter(bool enabled, datetime startTime = 0, datetime endTime = 0, string affectedSymbols = "") {
      m_newsFilterEnabled = enabled;
      m_newsStartTime = startTime;
      m_newsEndTime = endTime;
      m_affectedSymbols = affectedSymbols;
   }
   
   // Trade validation
   bool             ValidateTradeRequest(MqlTradeRequest &request);
   bool             CheckPriceDeviation(const string symbol, const double price);
   bool             CheckRateLimit(void);
   
   // Order execution with enhanced security
   bool             ExecuteTrade(MqlTradeRequest &request, MqlTradeResult &result);
   bool             VerifyOrderFill(const ulong ticket);
   
   // Anomaly detection
   bool             DetectAnomalies(const MqlTradeRequest &request);
   
   // Error handling
   string           GetLastError(void) const { return m_lastError; }
   
   // Getters
   double           GetAvgTradeTime(void) const { return m_avgTradeTime; }
   int              GetAnomalyCount(void) const { return m_anomalyCount; }
   
   // News checking
   bool             IsNewsEvent(const string symbol) {
      // Check if news filtering is enabled
      if(!m_newsFilterEnabled) {
         return false;
      }
      
      // Get the current time
      datetime currentTime = TimeCurrent();
      
      // Check if we're in a news blackout period
      if(currentTime >= m_newsStartTime && currentTime <= m_newsEndTime) {
         // If no specific symbols are listed, all symbols are affected
         if(StringLen(m_affectedSymbols) == 0) {
            return true;
         }
         
         // Check if this symbol is in the affected symbols list
         string symbols[];
         int count = StringSplit(m_affectedSymbols, ',', symbols);
         
         for(int i = 0; i < count; i++) {
            string current = symbols[i];
            StringTrimLeft(current);
            StringTrimRight(current);
            if(current == symbol) {
               return true;
            }
         }
      }
      
      return false;
   }
};

// Implementation is included in the main EA file
