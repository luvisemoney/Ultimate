//+------------------------------------------------------------------+
//| MockAdvancedStrategy.mqh - Mock implementation of CAdvancedStrategy |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include <Object.mqh>
#include "..\\..\\Include\\Strategies\\AdvancedStrategy.mqh"
#include "MockLearningEngine.mqh"
#include "MockAdvancedRiskManager.mqh"

//+------------------------------------------------------------------+
//| Mock implementation of CAdvancedStrategy for testing             |
//+------------------------------------------------------------------+
class CMockAdvancedStrategy : public CAdvancedStrategy
  {
private:
   bool              m_initialized;       // Whether the strategy is initialized
   bool              m_forceError;        // Whether to force an error
   string            m_lastError;         // Last error message
   
   // Test data
   double            m_maFast;            // Fast MA value
   double            m_maMedium;          // Medium MA value
   double            m_maSlow;            // Slow MA value
   double            m_rsi;               // RSI value
   double            m_macdMain;          // MACD main line
   double            m_macdSignal;        // MACD signal line
   double            m_bollingerUpper;    // Bollinger upper band
   double            m_bollingerMiddle;   // Bollinger middle band
   double            m_bollingerLower;    // Bollinger lower band
   double            m_atr;               // ATR value
   
   // Trade signals
   bool              m_shouldEnterLong;   // Whether to enter long
   bool              m_shouldEnterShort;  // Whether to enter short
   bool              m_shouldExitLong;    // Whether to exit long
   bool              m_shouldExitShort;   // Whether to exit short
   
   // Components
   CMockAdvancedRiskManager *m_mockRiskManager;  // Mock risk manager
   CMockLearningEngine     *m_mockLearningEngine; // Mock learning engine
   
public:
   // Constructor/destructor
                     CMockAdvancedStrategy() : 
                        CAdvancedStrategy("EURUSD", PERIOD_H1),
                        m_initialized(true),
                        m_forceError(false),
                        m_maFast(1.2000),
                        m_maMedium(1.1950),
                        m_maSlow(1.1900),
                        m_rsi(60.0),
                        m_macdMain(0.0010),
                        m_macdSignal(0.0005),
                        m_bollingerUpper(1.2100),
                        m_bollingerMiddle(1.2000),
                        m_bollingerLower(1.1900),
                        m_atr(0.0050),
                        m_shouldEnterLong(true),
                        m_shouldEnterShort(false),
                        m_shouldExitLong(false),
                        m_shouldExitShort(false)
                        {
                           // Initialize mock components
                           m_mockRiskManager = new CMockAdvancedRiskManager();
                           m_mockLearningEngine = new CMockLearningEngine();
                        }
                       
                    ~CMockAdvancedStrategy()
                      {
                         if(CheckPointer(m_mockRiskManager) == POINTER_DYNAMIC)
                            delete m_mockRiskManager;
                         if(CheckPointer(m_mockLearningEngine) == POINTER_DYNAMIC)
                            delete m_mockLearningEngine;
                      }
   
   // Override methods
   virtual bool      Initialize() { return !m_forceError && m_initialized; }
   
   virtual bool      ShouldEnterLong(const MqlRates &rates[], int shift, double &confidence)
                     {
                        if(m_forceError)
                           return false;
                            
                        confidence = 0.8;
                        return m_shouldEnterLong;
                     }
   
   virtual bool      ShouldEnterShort(const MqlRates &rates[], int shift, double &confidence)
                     {
                        if(m_forceError)
                           return false;
                            
                        confidence = 0.8;
                        return m_shouldEnterShort;
                     }
   
   virtual bool      ShouldExitLong(const MqlRates &rates[], int shift, double &confidence)
                     {
                        if(m_forceError)
                           return false;
                            
                        confidence = 0.8;
                        return m_shouldExitLong;
                     }
   
   virtual bool      ShouldExitShort(const MqlRates &rates[], int shift, double &confidence)
                     {
                        if(m_forceError)
                           return false;
                            
                        confidence = 0.8;
                        return m_shouldExitShort;
                     }
   
   // Test control methods
   void              SetInitialized(bool initialized) { m_initialized = initialized; }
   void              SetIndicators(double maFast, double maMedium, double maSlow, 
                                  double rsi, double macdMain, double macdSignal,
                                  double bollingerUpper, double bollingerMiddle, 
                                  double bollingerLower, double atr)
                     {
                        m_maFast = maFast;
                        m_maMedium = maMedium;
                        m_maSlow = maSlow;
                        m_rsi = rsi;
                        m_macdMain = macdMain;
                        m_macdSignal = macdSignal;
                        m_bollingerUpper = bollingerUpper;
                        m_bollingerMiddle = bollingerMiddle;
                        m_bollingerLower = bollingerLower;
                        m_atr = atr;
                     }
   
   void              SetTradeSignals(bool enterLong, bool enterShort, 
                                   bool exitLong, bool exitShort)
                     {
                        m_shouldEnterLong = enterLong;
                        m_shouldEnterShort = enterShort;
                        m_shouldExitLong = exitLong;
                        m_shouldExitShort = exitShort;
                     }
   
   void              ForceError(bool force, string error = "") 
                     { 
                        m_forceError = force; 
                        if(force) 
                           m_lastError = (error == "") ? "Forced error for testing" : error;
                     }
   
   string            GetLastError() const { return m_forceError ? m_lastError : ""; }
   
   // Getters for test verification
   CMockAdvancedRiskManager *GetMockRiskManager() const { return m_mockRiskManager; }
   CMockLearningEngine     *GetMockLearningEngine() const { return m_mockLearningEngine; }
  };

//+------------------------------------------------------------------+
