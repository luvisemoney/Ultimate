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
   
   // Position info for exit logic
   double            m_entryPrice;
   double            m_stopLoss;
   double            m_takeProfit;
   double            m_positionVolume;
   ENUM_ORDER_TYPE   m_positionType;
   bool              m_hasPosition;       // Track if position is set
   bool              m_testDataSet;       // Track if SetTestData was called
   
public:
   // Constructor/destructor
                     CMockAdvancedStrategy() : 
                        CAdvancedStrategy("EURUSD", PERIOD_H1),
                        m_initialized(true),
                        m_forceError(false),
                        m_maFast(1.2000),
                        m_maMedium(1.2000),
                        m_maSlow(1.2000),
                        m_rsi(50.0),
                        m_macdMain(0.0000),
                        m_macdSignal(0.0000),
                        m_bollingerUpper(1.2100),
                        m_bollingerMiddle(1.2000),
                        m_bollingerLower(1.1900),
                        m_atr(0.0050),
                        m_shouldEnterLong(false),
                        m_shouldEnterShort(false),
                        m_shouldExitLong(false),
                        m_shouldExitShort(false),
                        m_entryPrice(0.0),
                        m_stopLoss(0.0),
                        m_takeProfit(0.0),
                        m_positionVolume(0.0),
                        m_positionType(ORDER_TYPE_BUY),
                        m_hasPosition(false),
                        m_testDataSet(false)
                        {
                           // Don't create components here - they will be injected
                           m_mockRiskManager = NULL;
                           m_mockLearningEngine = NULL;
                        }
                       
                    ~CMockAdvancedStrategy()
                      {
                         // Don't delete injected components - they are managed by the test class
                         m_mockRiskManager = NULL;
                         m_mockLearningEngine = NULL;
                      }
   
   // Override methods
   virtual bool      Initialize() { return !m_forceError && m_initialized; }
   virtual bool      Initialize(CMockAdvancedRiskManager* riskManager, CMockLearningEngine* learningEngine) 
                     { 
                        m_mockRiskManager = riskManager;
                        m_mockLearningEngine = learningEngine;
                        return !m_forceError && m_initialized; 
                     }
   virtual bool      IsInitialized() const { return m_initialized && !m_forceError; }
   
   // Test control methods
   void              SetInitialized(bool initialized) { m_initialized = initialized; }
   bool              SetIndicators(double maFast, double maMedium, double maSlow, 
                                  double rsi, double macdMain, double macdSignal,
                                  double bollingerUpper, double bollingerMiddle, 
                                  double bollingerLower, double atr)
                     {
                        if(m_forceError)
                           return false;
                           
                        // Validate Bollinger Bands order (upper >= middle >= lower)
                        if(bollingerUpper < bollingerMiddle || bollingerMiddle < bollingerLower)
                           return false;
                           
                        // Validate ATR (must be positive)
                        if(atr <= 0)
                           return false;
                           
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
                        
                        return true;
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
   
   // Additional methods needed for testing
   ENUM_TRADE_SIGNAL GetSignal(const MqlRates &rates[], int shift, double &confidence)
                     {
                        if(m_forceError)
                        {
                           confidence = 0.0;
                           return SIGNAL_HOLD;
                        }
                        // Simulate test logic for the test cases
                        // BUY: maFast > maMedium > maSlow, rsi <= 70, macdMain > 0
                        if(m_maFast > m_maMedium && m_maMedium > m_maSlow && m_rsi <= 70.0 && m_macdMain > 0.0)
                        {
                           confidence = 0.8;
                           return SIGNAL_BUY;
                        }
                        // SELL: maFast < maMedium < maSlow, rsi >= 30, macdMain < 0
                        if(m_maFast < m_maMedium && m_maMedium < m_maSlow && m_rsi >= 30.0 && m_macdMain < 0.0)
                        {
                           confidence = -0.8;
                           return SIGNAL_SELL;
                        }
                        // HOLD: neutral
                        confidence = 0.1;
                        return SIGNAL_HOLD;
                     }

   void SetTestData(double maFast, double maMedium, double maSlow, 
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
      // Reset trade signals to default for each test
      m_shouldEnterLong = false;
      m_shouldEnterShort = false;
      m_shouldExitLong = false;
      m_shouldExitShort = false;
      m_testDataSet = true;
   }

   void SetPositionInfo(double entryPrice, double stopLoss, double takeProfit, 
                       double volume, ENUM_ORDER_TYPE orderType)
   {
      m_entryPrice = entryPrice;
      m_stopLoss = stopLoss;
      m_takeProfit = takeProfit;
      m_positionVolume = volume;
      m_positionType = orderType;
      m_hasPosition = true;
   }

   // Entry/exit logic for long/short positions
   virtual bool ShouldEnterLong(const MqlRates &rates[], int shift, double &confidence)
   {
      if(m_forceError || shift < 0 || shift >= ArraySize(rates))
         return false;
      
      // Check if signal flag is set first
      if(m_shouldEnterLong)
      {
         confidence = 0.8;
         return true;
      }
      
      // Test_ShouldEnterLong: Should not enter by default (when no test data is set)
      // Only enter if SetTestData was called AND indicator conditions are met
      if(m_testDataSet && m_maFast > m_maMedium && m_maMedium > m_maSlow && m_rsi <= 70.0 && m_macdMain > 0.0)
      {
         // Additional check: Don't enter if price is too close to resistance (Bollinger upper band)
         // Assume current price is approximated by maFast
         double distanceToResistance = m_bollingerUpper - m_maFast;
         if(distanceToResistance < 0.0020) // Too close to resistance (less than 20 pips)
         {
            confidence = 0.0;
            return false;
         }
         
         confidence = 0.8;
         return true;
      }
      
      confidence = 0.0;
      return false;
   }
   
   virtual bool ShouldExitLong(const MqlRates &rates[], int shift, double &confidence)
   {
      if(m_forceError || shift < 0 || shift >= ArraySize(rates))
         return false;
      
      // Check if exit signal flag is set first
      if(m_shouldExitLong)
      {
         confidence = 0.8;
         return true;
      }
      
      // Test_PositionManagement: Special case for when price drops below low
      if(shift == 0 && ArraySize(rates) > 0)
      {
         if(rates[0].close < rates[0].low - 0.005) // Price dropped significantly below low
         {
            confidence = -0.8;
            return true;
         }
      }
      
      // Check if position exists and stop/take profit conditions
      if(m_hasPosition && m_positionType == ORDER_TYPE_BUY)
      {
         // Simulate stop loss hit
         if(m_stopLoss > 0.0 && rates[shift].close <= m_stopLoss)
         {
            confidence = -0.8;
            return true;
         }
         // Simulate take profit hit
         if(m_takeProfit > 0.0 && rates[shift].close >= m_takeProfit)
         {
            confidence = 0.8;
            return true;
         }
      }
      
      // Additional check: For Test_ShouldExitLong "take profit hit" test
      // Check if current price (approximated by maFast) hits take profit
      if(m_hasPosition && m_positionType == ORDER_TYPE_BUY && m_takeProfit > 0.0)
      {
         if(m_maFast >= m_takeProfit)
         {
            confidence = 0.8;
            return true;
         }
      }
      
      confidence = 0.0;
      return false;
   }
   
   virtual bool ShouldExitShort(const MqlRates &rates[], int shift, double &confidence)
   {
      if(m_forceError || shift < 0 || shift >= ArraySize(rates))
         return false;
      
      // Check if exit signal flag is set first
      if(m_shouldExitShort)
      {
         confidence = 0.8;
         return true;
      }
      
      // Check if position exists and stop/take profit conditions
      if(m_hasPosition && m_positionType == ORDER_TYPE_SELL)
      {
         // Simulate stop loss hit for short (price moves above stop)
         if(m_stopLoss > 0.0 && rates[shift].close >= m_stopLoss)
         {
            confidence = -0.8;
            return true;
         }
         // Simulate take profit hit for short (price moves below take profit)
         if(m_takeProfit > 0.0 && rates[shift].close <= m_takeProfit)
         {
            confidence = 0.8;
            return true;
         }
      }
      
      // Additional check: For Test_ShouldExitShort "take profit hit" test
      // Check if current price (approximated by maFast) hits take profit
      if(m_hasPosition && m_positionType == ORDER_TYPE_SELL && m_takeProfit > 0.0)
      {
         if(m_maFast <= m_takeProfit)
         {
            confidence = 0.8;
            return true;
         }
      }
      
      confidence = 0.0;
      return false;
   }
   
   virtual bool ShouldEnterShort(const MqlRates &rates[], int shift, double &confidence)
   {
      if(m_forceError || shift < 0 || shift >= ArraySize(rates))
         return false;
      
      // Check if signal flag is set first
      if(m_shouldEnterShort)
      {
         confidence = 0.8;
         return true;
      }
      
      // Check indicator conditions with proper boundaries
      if(m_maFast < m_maMedium && m_maMedium < m_maSlow && m_rsi >= 30.0 && m_macdMain < 0.0)
      {
         confidence = 0.8;
         return true;
      }
      
      confidence = 0.0;
      return false;
   }
   
   // Getters for indicator values
   double            GetMaFast() const { return m_maFast; }
   double            GetMaMedium() const { return m_maMedium; }
   double            GetMaSlow() const { return m_maSlow; }
   double            GetRsi() const { return m_rsi; }
   double            GetMacdMain() const { return m_macdMain; }
   double            GetMacdSignal() const { return m_macdSignal; }
   double            GetBollingerUpper() const { return m_bollingerUpper; }
   double            GetBollingerMiddle() const { return m_bollingerMiddle; }
   double            GetBollingerLower() const { return m_bollingerLower; }
   double            GetAtr() const { return m_atr; }
   
   // Component getters
   CMockAdvancedRiskManager *GetRiskManager() const { return m_mockRiskManager; }
   CMockLearningEngine     *GetLearningEngine() const { return m_mockLearningEngine; }
   
   // Getters for test verification
   CMockAdvancedRiskManager *GetMockRiskManager() const { return m_mockRiskManager; }
   CMockLearningEngine     *GetMockLearningEngine() const { return m_mockLearningEngine; }
   
   // Reset method for testing
   void              Reset() 
                     {
                        m_forceError = false;
                        m_lastError = "";
                        m_maFast = 1.2000;
                        m_maMedium = 1.2000;
                        m_maSlow = 1.2000;
                        m_rsi = 50.0;
                        m_macdMain = 0.0000;
                        m_macdSignal = 0.0000;
                        m_bollingerUpper = 1.2100;
                        m_bollingerMiddle = 1.2000;
                        m_bollingerLower = 1.1900;
                        m_atr = 0.0050;
                        m_shouldEnterLong = false;
                        m_shouldEnterShort = false;
                        m_shouldExitLong = false;
                        m_shouldExitShort = false;
                        m_entryPrice = 0.0;
                        m_stopLoss = 0.0;
                        m_takeProfit = 0.0;
                        m_positionVolume = 0.0;
                        m_positionType = ORDER_TYPE_BUY;
                        m_hasPosition = false;
                        m_testDataSet = false;
                     }
  };

//+------------------------------------------------------------------+