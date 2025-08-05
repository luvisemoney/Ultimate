//+------------------------------------------------------------------+
//|                                                  EAState.mqh      |
//|                        Copyright 2025, Your Company Name          |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

#include "EALogger.mqh"

//+------------------------------------------------------------------+
//| Market data state                                                |
//+------------------------------------------------------------------+
struct SMarketData
{
   MqlTick     lastTick;       // Last tick data
   datetime    lastUpdate;     // Last update time
   double      bid, ask;       // Current prices
   double      spread;         // Current spread
   
   // Initialize structure
   void Init()
   {
      ZeroMemory(lastTick);
      lastUpdate = 0;
      bid = ask = spread = 0.0;
   }
};

//+------------------------------------------------------------------+
//| Trade state                                                      |
//+------------------------------------------------------------------+
struct STradeState
{
   int         totalPositions;     // Total open positions
   double      totalProfit;        // Total profit/loss
   double      maxDrawdown;        // Maximum drawdown
   datetime    lastTradeTime;      // Time of last trade
   
   // Initialize structure
   void Init()
   {
      totalPositions = 0;
      totalProfit = 0.0;
      maxDrawdown = 0.0;
      lastTradeTime = 0;
   }
};

//+------------------------------------------------------------------+
//| EA State Manager                                                 |
//+------------------------------------------------------------------+
class CEAState
{
private:
   CEALogger*  m_logger;           // Logger instance
   SMarketData m_marketData;       // Market data state
   STradeState m_tradeState;       // Trade state
   
   // Indicators
   int         m_maHandle;         // Moving average handle
   double      m_maBuffer[];       // MA buffer
   
   // Locks
   bool        m_isUpdating;       // Update flag
   
   // Internal methods
   void UpdateIndicators();
   
public:
   CEAState() : m_logger(NULL), m_maHandle(INVALID_HANDLE), m_isUpdating(false)
   {
      m_marketData.Init();
      m_tradeState.Init();
   }
   
   ~CEAState() { Deinitialize(); }
   
   // Initialization
   bool Initialize(CEALogger* logger);
   void Deinitialize();
   
   // State updates
   void UpdateMarketData(const string symbol, ENUM_TIMEFRAMES timeframe);
   void UpdateLastTick(const CTickEvent* tick);
   void UpdateTradeState();
   
   // Getters
   const SMarketData& GetMarketData() const { return m_marketData; }
   const STradeState& GetTradeState() const { return m_tradeState; }
   
   // Indicator access
   double GetMA(int shift = 0) const;
   
   // State validation
   bool IsMarketOpen() const;
   bool IsTradingAllowed() const;
};

//+------------------------------------------------------------------+
//| Initialize state manager                                         |
//+------------------------------------------------------------------+
bool CEAState::Initialize(CEALogger* logger)
{
   if (logger == NULL)
      return false;
      
   m_logger = logger;
   
   // Initialize indicators
   m_maHandle = iMA(NULL, 0, 14, 0, MODE_SMA, PRICE_CLOSE);
   if (m_maHandle == INVALID_HANDLE)
   {
      m_logger.LogError("Failed to initialize MA indicator");
      return false;
   }
   
   // Set indicator buffers
   ArraySetAsSeries(m_maBuffer, true);
   
   m_logger.LogInfo("State manager initialized");
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialize state manager                                       |
//+------------------------------------------------------------------+
void CEAState::Deinitialize()
{
   // Release indicators
   if (m_maHandle != INVALID_HANDLE)
   {
      IndicatorRelease(m_maHandle);
      m_maHandle = INVALID_HANDLE;
   }
   
   // Clear buffers
   ArrayFree(m_maBuffer);
   
   m_logger = NULL;
}

//+------------------------------------------------------------------+
//| Update market data                                               |
//+------------------------------------------------------------------+
void CEAState::UpdateMarketData(const string symbol, ENUM_TIMEFRAMES timeframe)
{
   if (m_isUpdating)
      return;
      
   m_isUpdating = true;
   
   // Update tick data
   MqlTick lastTick;
   if (SymbolInfoTick(symbol, lastTick))
   {
      m_marketData.lastTick = lastTick;
      m_marketData.bid = lastTick.bid;
      m_marketData.ask = lastTick.ask;
      m_marketData.spread = lastTick.ask - lastTick.bid;
      m_marketData.lastUpdate = TimeCurrent();
   }
   
   // Update indicators
   UpdateIndicators();
   
   m_isUpdating = false;
}

//+------------------------------------------------------------------+
//| Update last tick                                                 |
//+------------------------------------------------------------------+
void CEAState::UpdateLastTick(const CTickEvent* tick)
{
   if (tick == NULL)
      return;
      
   // Update tick data from event
   // Implementation depends on CTickEvent structure
}

//+------------------------------------------------------------------+
//| Update trade state                                               |
//+------------------------------------------------------------------+
void CEAState::UpdateTradeState()
{
   // Update positions count
   m_tradeState.totalPositions = PositionsTotal();
   
   // Update total profit
   double totalProfit = 0;
   for (int i = 0; i < m_tradeState.totalPositions; i++)
   {
      if (m_position.SelectByIndex(i))
         totalProfit += m_position.Profit() + m_position.Swap() + m_position.Commission();
   }
   m_tradeState.totalProfit = totalProfit;
   
   // Update max drawdown
   if (totalProfit < m_tradeState.maxDrawdown)
      m_tradeState.maxDrawdown = totalProfit;
   
   // Update last trade time
   if (m_tradeState.totalPositions > 0)
      m_tradeState.lastTradeTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Update indicators                                                |
//+------------------------------------------------------------------+
void CEAState::UpdateIndicators()
{
   if (m_maHandle == INVALID_HANDLE)
      return;
      
   // Copy MA values
   if (CopyBuffer(m_maHandle, 0, 0, 1, m_maBuffer) != 1)
   {
      if (m_logger != NULL)
         m_logger.LogError("Failed to copy MA buffer");
      return;
   }
}

//+------------------------------------------------------------------+
//| Get moving average value                                         |
//+------------------------------------------------------------------+
double CEAState::GetMA(int shift = 0) const
{
   if (shift < 0 || shift >= ArraySize(m_maBuffer))
      return 0.0;
      
   return m_maBuffer[shift];
}

//+------------------------------------------------------------------+
//| Check if market is open                                          |
//+------------------------------------------------------------------+
bool CEAState::IsMarketOpen() const
{
   // Check if current time is within trading hours
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Example: Check if it's a weekday and within trading hours
   if (dt.day_of_week == 0 || dt.day_of_week == 6) // Weekend
      return false;
      
   // Example: Check trading hours (9:30 AM - 4:00 PM)
   int currentMinute = dt.hour * 60 + dt.min;
   if (currentMinute < 570 || currentMinute >= 960) // Before 9:30 AM or after 4:00 PM
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool CEAState::IsTradingAllowed() const
{
   // Check if market is open
   if (!IsMarketOpen())
      return false;
      
   // Check if max positions reached
   if (m_tradeState.totalPositions >= 10) // Example limit
      return false;
      
   // Check if max drawdown reached
   if (m_tradeState.maxDrawdown <= -1000.0) // Example limit
      return false;
      
   return true;
}
