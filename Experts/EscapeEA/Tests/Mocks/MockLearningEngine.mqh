//+------------------------------------------------------------------+
//| MockLearningEngine.mqh - Mock implementation of CLearningEngine  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include <Object.mqh>
#include "..\..\Include\Learning\LearningEngine.mqh"

//+------------------------------------------------------------------+
//| Mock implementation of CLearningEngine for testing               |
//+------------------------------------------------------------------+
class CMockLearningEngine : public CLearningEngine
  {
private:
   bool              m_initialized;     // Whether the engine is initialized
   bool              m_forceError;      // Whether to force an error
   string            m_lastError;       // Last error message
   
   // Test data
   double            m_winRate;         // Win rate to return
   double            m_profitFactor;    // Profit factor to return
   double            m_maxDrawdown;     // Max drawdown to return
   bool              m_shouldEnter;     // Whether to enter a trade
   
public:
   // Constructor/destructor
                     CMockLearningEngine() : 
                        CLearningEngine(100, 0.6, 0.01),
                        m_initialized(true),
                        m_forceError(false),
                        m_winRate(0.7),
                        m_profitFactor(1.5),
                        m_maxDrawdown(10.0),
                        m_shouldEnter(true)
                        {}
                    
                    ~CMockLearningEngine() {}
   
   // Override methods
   virtual bool      Initialize() { return !m_forceError && m_initialized; }
   
   virtual bool      UpdateModel(const STradeRecord &newTrade) 
                     { 
                        if(m_forceError) 
                           return false;
                        return true; 
                     }
   
   virtual bool      ShouldEnterTrade(const double &features[], double &confidence) 
                     { 
                        if(m_forceError) 
                           return false;
                        confidence = 0.8;
                        return m_shouldEnter; 
                     }
   
   // Performance metrics
   virtual double    GetWinRate(int lookback = 0) 
                     { 
                        if(m_forceError) 
                           return -1.0;
                        return m_winRate; 
                     }
   
   virtual double    GetProfitFactor(int lookback = 0) 
                     { 
                        if(m_forceError) 
                           return -1.0;
                        return m_profitFactor; 
                     }
   
   virtual double    GetMaxDrawdown(int lookback = 0) 
                     { 
                        if(m_forceError) 
                           return -1.0;
                        return m_maxDrawdown; 
                     }
   
   // Test control methods
   void              SetInitialized(bool initialized) { m_initialized = initialized; }
   void              SetWinRate(double winRate) { m_winRate = winRate; }
   void              SetProfitFactor(double profitFactor) { m_profitFactor = profitFactor; }
   void              SetMaxDrawdown(double maxDrawdown) { m_maxDrawdown = maxDrawdown; }
   void              SetShouldEnter(bool shouldEnter) { m_shouldEnter = shouldEnter; }
   
   void              ForceError(bool force, string error = "") 
                     { 
                        m_forceError = force; 
                        if(force) 
                           m_lastError = (error == "") ? "Forced error for testing" : error;
                     }
   
   string            GetLastError() const { return m_forceError ? m_lastError : ""; }
  };

//+------------------------------------------------------------------+
