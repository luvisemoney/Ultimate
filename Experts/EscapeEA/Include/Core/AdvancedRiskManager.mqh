//+------------------------------------------------------------------+
//| AdvancedRiskManager.mqh - Advanced risk management for EscapeEA   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include <Trade\PositionInfo.mqh>
#include <Indicators\Volumes.mqh>
#include <Indicators\ATR.mqh>

//+------------------------------------------------------------------+
//| Advanced Risk Manager Class                                      |
//+------------------------------------------------------------------+
class CAdvancedRiskManager
  {
private:
   // Configuration
   double            m_riskPerTrade;        // Risk per trade as % of balance
   double            m_maxDailyDrawdown;     // Max daily drawdown (% of balance)
   double            m_maxPositionRisk;      // Max position risk (% of balance)
   double            m_maxCorrelation;       // Max allowed correlation between pairs
   double            m_volatilityThreshold;  // Volatility threshold for position sizing
   
   // State
   double            m_initialBalance;       // Initial balance at start of day
   double            m_dailyHigh;            // Daily high water mark
   double            m_dailyLow;             // Daily low water mark
   datetime          m_lastCheckTime;        // Last time risk was checked
   
   // Indicators
   CiATR             m_atr;                  // ATR for volatility measurement
   
   // Private methods
   double            CalculatePositionSize(const string symbol, double stopLoss, double entryPrice);
   double            CalculateVolatility(const string symbol, ENUM_TIMEFRAMES timeframe, int period);
   double            CalculateCorrelation(const string symbol1, const string symbol2, 
                                         ENUM_TIMEFRAMES timeframe, int period);
   
public:
   // Constructor/destructor
                     CAdvancedRiskManager();
                    ~CAdvancedRiskManager();
   
   // Initialization
   bool              Initialize(double riskPerTrade = 1.0, double maxDailyDrawdown = 5.0, 
                              double maxPositionRisk = 2.0, double maxCorrelation = 0.7, 
                              double volatilityThreshold = 0.02);
   
   // Risk assessment methods
   bool              IsTradeAllowed(const string symbol, double lots, double entryPrice, 
                                   double stopLoss, double takeProfit, string &reason);
   
   // Position sizing
   double            GetOptimalLots(const string symbol, double stopLoss, double entryPrice);
   
   // Risk metrics
   double            GetPortfolioRisk();
   double            GetDailyDrawdown();
   double            GetMaxPositionRisk();
   
   // Getters
   double            RiskPerTrade() const { return m_riskPerTrade; }
   double            MaxDailyDrawdown() const { return m_maxDailyDrawdown; }
   double            MaxPositionRisk() const { return m_maxPositionRisk; }
   double            MaxCorrelation() const { return m_maxCorrelation; }
   double            VolatilityThreshold() const { return m_volatilityThreshold; }
   
   // Setters
   void              SetRiskPerTrade(double risk) { m_riskPerTrade = MathMax(0.1, MathMin(risk, 5.0)); }
   void              SetMaxDailyDrawdown(double drawdown) { m_maxDailyDrawdown = MathMax(0.5, MathMin(drawdown, 10.0)); }
   void              SetMaxPositionRisk(double risk) { m_maxPositionRisk = MathMax(0.5, MathMin(risk, 5.0)); }
   void              SetMaxCorrelation(double correlation) { m_maxCorrelation = MathMax(0.1, MathMin(correlation, 0.9)); }
   void              SetVolatilityThreshold(double threshold) { m_volatilityThreshold = MathMax(0.005, MathMin(threshold, 0.05)); }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAdvancedRiskManager::CAdvancedRiskManager() :
   m_riskPerTrade(1.0),
   m_maxDailyDrawdown(5.0),
   m_maxPositionRisk(2.0),
   m_maxCorrelation(0.7),
   m_volatilityThreshold(0.02),
   m_initialBalance(AccountInfoDouble(ACCOUNT_BALANCE)),
   m_dailyHigh(m_initialBalance),
   m_dailyLow(m_initialBalance),
   m_lastCheckTime(0)
  {
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAdvancedRiskManager::~CAdvancedRiskManager()
  {
  }

//+------------------------------------------------------------------+
//| Initialize risk manager with parameters                          |
//+------------------------------------------------------------------+
bool CAdvancedRiskManager::Initialize(double riskPerTrade, double maxDailyDrawdown, 
                                    double maxPositionRisk, double maxCorrelation,
                                    double volatilityThreshold)
  {
   // Set parameters with validation
   SetRiskPerTrade(riskPerTrade);
   SetMaxDailyDrawdown(maxDailyDrawdown);
   SetMaxPositionRisk(maxPositionRisk);
   SetMaxCorrelation(maxCorrelation);
   SetVolatilityThreshold(volatilityThreshold);
   
   // Initialize ATR for volatility measurement
   if(!m_atr.Create(Symbol(), PERIOD_D1, 14))
     {
      Print("Failed to create ATR indicator");
      return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Check if a trade is allowed based on risk parameters             |
//+------------------------------------------------------------------+
bool CAdvancedRiskManager::IsTradeAllowed(const string symbol, double lots, double entryPrice, 
                                        double stopLoss, double takeProfit, string &reason)
  {
   reason = "";
   
   // Check if market is open
   if(!SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL)
     {
      reason = "Trading is not allowed for " + symbol;
      return false;
     }
   
   // Check daily drawdown
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyDrawdown = (m_dailyHigh - currentBalance) / m_dailyHigh * 100.0;
   
   if(dailyDrawdown > m_maxDailyDrawdown)
     {
      reason = StringFormat("Daily drawdown %.2f%% exceeds maximum %.2f%%", 
                           dailyDrawdown, m_maxDailyDrawdown);
      return false;
     }
   
   // Update daily high/low
   if(currentBalance > m_dailyHigh)
      m_dailyHigh = currentBalance;
   if(currentBalance < m_dailyLow)
      m_dailyLow = currentBalance;
   
   // Calculate position risk
   double positionRisk = 0.0;
   double pointValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE) / 
                      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE) * 
                      SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(stopLoss > 0)
      positionRisk = MathAbs(entryPrice - stopLoss) * lots * pointValue / currentBalance * 100.0;
   
   if(positionRisk > m_maxPositionRisk)
     {
      reason = StringFormat("Position risk %.2f%% exceeds maximum %.2f%%", 
                           positionRisk, m_maxPositionRisk);
      return false;
     }
   
   // Check volatility
   double volatility = CalculateVolatility(symbol, PERIOD_D1, 14);
   if(volatility > m_volatilityThreshold)
     {
      reason = StringFormat("Volatility %.2f%% exceeds threshold %.2f%%", 
                           volatility * 100, m_volatilityThreshold * 100);
      return false;
     }
   
   // Check correlation with other open positions
   CPositionInfo position;
   int total = PositionsTotal();
   
   for(int i = 0; i < total; i++)
     {
      if(position.SelectByIndex(i))
        {
         string otherSymbol = position.Symbol();
         if(otherSymbol != symbol)
           {
            double correlation = CalculateCorrelation(symbol, otherSymbol, PERIOD_D1, 100);
            if(correlation > m_maxCorrelation)
              {
               reason = StringFormat("Correlation %.2f with %s exceeds maximum %.2f", 
                                    correlation, otherSymbol, m_maxCorrelation);
               return false;
              }
           }
        }
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Calculate optimal position size based on risk parameters         |
//+------------------------------------------------------------------+
double CAdvancedRiskManager::GetOptimalLots(const string symbol, double stopLoss, double entryPrice)
  {
   if(stopLoss <= 0 || entryPrice <= 0)
      return 0.0;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (m_riskPerTrade / 100.0);
   
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   double riskInMoney = riskAmount;
   double riskInPoints = MathAbs(entryPrice - stopLoss) / point;
   
   if(riskInPoints == 0)
      return 0.0;
   
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   
   double lots = NormalizeDouble(riskInMoney / (riskInPoints * tickValue * (point / tickSize)) / 
                               SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE), 2);
   
   // Apply volatility adjustment
   double volatility = CalculateVolatility(symbol, PERIOD_D1, 14);
   if(volatility > m_volatilityThreshold)
      lots *= (1.0 - (volatility - m_volatilityThreshold) / m_volatilityThreshold * 0.5);
   
   // Ensure lot size is within allowed range and step
   lots = MathMax(minLot, MathMin(maxLot, lots));
   lots = MathFloor(lots / lotStep) * lotStep;
   
   return lots;
  }

//+------------------------------------------------------------------+
//| Calculate volatility using ATR                                   |
//+------------------------------------------------------------------+
double CAdvancedRiskManager::CalculateVolatility(const string symbol, ENUM_TIMEFRAMES timeframe, int period)
  {
   if(m_atr.Symbol() != symbol || m_atr.Period() != timeframe)
     {
      m_atr.Release();
      if(!m_atr.Create(symbol, timeframe, 14))
         return 0.0;
     }
   
   int copied = m_atr.GetData(0, 1, period, m_atr.GetDataBuffer(0));
   if(copied <= 0)
      return 0.0;
   
   double sum = 0.0;
   for(int i = 0; i < copied; i++)
      sum += m_atr.GetDataBuffer(0)[i];
   
   double avgATR = sum / copied;
   double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   return price > 0 ? avgATR / price : 0.0;
  }

//+------------------------------------------------------------------+
//| Calculate correlation between two symbols                        |
//+------------------------------------------------------------------+
double CAdvancedRiskManager::CalculateCorrelation(const string symbol1, const string symbol2, 
                                                ENUM_TIMEFRAMES timeframe, int period)
  {
   double close1[];
   double close2[];
   
   // Get close prices for both symbols
   int copied1 = CopyClose(symbol1, timeframe, 0, period, close1);
   int copied2 = CopyClose(symbol2, timeframe, 0, period, close2);
   
   if(copied1 != copied2 || copied1 < 2)
      return 0.0;
   
   // Calculate returns
   double returns1[];
   double returns2[];
   ArrayResize(returns1, copied1 - 1);
   ArrayResize(returns2, copied1 - 1);
   
   for(int i = 1; i < copied1; i++)
     {
      returns1[i-1] = (close1[i] - close1[i-1]) / close1[i-1];
      returns2[i-1] = (close2[i] - close2[i-1]) / close2[i-1];
     }
   
   // Calculate means
   double mean1 = 0, mean2 = 0;
   for(int i = 0; i < ArraySize(returns1); i++)
     {
      mean1 += returns1[i];
      mean2 += returns2[i];
     }
   mean1 /= ArraySize(returns1);
   mean2 /= ArraySize(returns2);
   
   // Calculate covariance and variances
   double cov = 0, var1 = 0, var2 = 0;
   for(int i = 0; i < ArraySize(returns1); i++)
     {
      double diff1 = returns1[i] - mean1;
      double diff2 = returns2[i] - mean2;
      cov += diff1 * diff2;
      var1 += diff1 * diff1;
      var2 += diff2 * diff2;
     }
   
   // Calculate correlation coefficient
   if(var1 == 0 || var2 == 0)
      return 0.0;
   
   return cov / MathSqrt(var1 * var2);
  }

//+------------------------------------------------------------------+
//| Get current portfolio risk as % of balance                       |
//+------------------------------------------------------------------+
double CAdvancedRiskManager::GetPortfolioRisk()
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0)
      return 0.0;
   
   double totalRisk = 0.0;
   CPositionInfo position;
   
   for(int i = 0; i < PositionsTotal(); i++)
     {
      if(position.SelectByIndex(i))
        {
         double pointValue = SymbolInfoDouble(position.Symbol(), SYMBOL_TRADE_TICK_VALUE) / 
                            SymbolInfoDouble(position.Symbol(), SYMBOL_TRADE_TICK_SIZE) * 
                            SymbolInfoDouble(position.Symbol(), SYMBOL_POINT);
         
         double positionRisk = 0.0;
         if(position.StopLoss() > 0)
            positionRisk = MathAbs(position.PriceOpen() - position.StopLoss()) * 
                          position.Volume() * pointValue;
         
         totalRisk += positionRisk;
        }
     }
   
   return (totalRisk / balance) * 100.0;
  }

//+------------------------------------------------------------------+
//| Get current daily drawdown as % of balance                      |
//+------------------------------------------------------------------+
double CAdvancedRiskManager::GetDailyDrawdown()
  {
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   return (m_dailyHigh - currentBalance) / m_dailyHigh * 100.0;
  }

//+------------------------------------------------------------------+
//| Get maximum position risk as % of balance                        |
//+------------------------------------------------------------------+
double CAdvancedRiskManager::GetMaxPositionRisk()
  {
   return m_maxPositionRisk;
  }
