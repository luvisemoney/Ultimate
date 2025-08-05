//+------------------------------------------------------------------+
//|                                                PositionManager.mqh |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property strict

#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\Trade.mqh>
#include "InputValidation.mqh"

//+------------------------------------------------------------------+
//| Position scaling profiles                                        |
//+------------------------------------------------------------------+
enum ENUM_SCALING_PROFILE {
   SCALING_NONE,         // No scaling
   SCALING_CONSERVATIVE, // Conservative scaling
   SCALING_MODERATE,     // Moderate scaling
   SCALING_AGGRESSIVE    // Aggressive scaling
};

//+------------------------------------------------------------------+
//| Exit profiles                                                    |
//+------------------------------------------------------------------+
enum ENUM_EXIT_PROFILE {
   EXIT_AGGRESSIVE,      // Aggressive exit (tighter stops)
   EXIT_BALANCED,        // Balanced exit
   EXIT_CONSERVATIVE     // Conservative exit (wider stops)
};

//+------------------------------------------------------------------+
//| Position Manager class                                           |
//+------------------------------------------------------------------+
class CPositionManager {
private:
   CTrade        *m_trade;           // Trade object
   CSymbolInfo   *m_symbol;          // Symbol info
   CPositionInfo  m_position;        // Position info
   
   // Configuration
   double         m_slPoints;        // Stop loss in points
   double         m_tpPoints;        // Take profit in points
   double         m_trailingStop;    // Trailing stop in points
   double         m_breakEven;       // Break even level in points
   
   // State
   bool           m_initialized;     // Initialization flag
   bool           m_autoBreakEven;   // Auto break-even flag
   bool           m_scaleIn;         // Scale into positions flag
   bool           m_scaleOut;        // Scale out of positions flag
   
   // Advanced position management
   double         m_breakEvenAt;           // Pips in profit to move to break-even
   double         m_scaleInAt;             // Pips in drawdown to scale in
   double         m_scaleOutAt;            // Pips in profit to scale out
   double         m_scaleInFactor;         // Scale-in volume factor
   double         m_scaleOutFactor;        // Scale-out volume factor
   
   // Private methods
   bool           CheckTrailingStop();
   bool           CheckBreakEven();
   
public:
   // Constructor/Destructor
                     CPositionManager();
                    ~CPositionManager();
   
   // Initialization
   bool              Initialize(CTrade *trade, CSymbolInfo *symbol, 
                              double slPoints, double tpPoints, 
                              double trailingStop = 0, double breakEven = 0);
   
   // Position management
   bool              OpenPosition(ENUM_ORDER_TYPE type, double volume, 
                                double price, double sl, double tp, 
                                const string comment = "");
   bool              ClosePosition(ulong ticket, const string comment = "");
   bool              CloseAllPositions(const string comment = "");
   bool              ModifyPosition(ulong ticket, double sl, double tp);
   
   // Advanced position management
   bool              SetScalingProfile(ENUM_SCALING_PROFILE profile);
   bool              SetExitProfile(ENUM_EXIT_PROFILE profile);
   
   // Getters
   bool              IsInitialized() const { return m_initialized; }
   double            GetPositionSize(ulong ticket);
   double            GetPositionProfit(ulong ticket);
   double            GetPositionStopLoss(ulong ticket);
   double            GetPositionTakeProfit(ulong ticket);
   
   // Utility
   void              Update();
   
   // Advanced methods
   bool              ScaleInPosition(ulong ticket, double volume);
   bool              ScaleOutPosition(ulong ticket, double volume);
   double            GetPositionRisk(ulong ticket);
   bool              SetDynamicRisk(bool enable, double maxDailyDrawdown = 5.0, 
                                  double maxPositionRisk = 2.0, double maxPortfolioRisk = 20.0, 
                                  double riskDecay = 0.9);
   
   // Position clustering
   bool              SetPositionClustering(bool enable, double clusterDistance = 20.0, int maxClusters = 3);
   
   // Market regime detection
   bool              SetRegimeFilter(bool enable, double trendThreshold = 0.3);
   
   // News event handling
   bool              SetNewsFilter(bool enable, int minImpact = 2, int minutesBefore = 30, int minutesAfter = 15);
   
   // Volatility-based position sizing
   bool              SetVolatilitySizing(bool enable, int period = 14, double multiplier = 1.5, double maxRisk = 2.0);
   
   // Correlation management
   bool              SetCorrelationFilter(bool enable, const string &symbols = "", double maxCorrelation = 0.7);
   
   // Grid trading
   bool              SetGridTrading(bool enable, double gridStep = 20.0, int maxLevels = 5, double volumeMultiplier = 1.5);
   
   // Machine learning integration
   bool              SetMLIntegration(bool enable, double confidenceThreshold = 0.7);
   
   // Adaptive position sizing
   bool              SetAdaptiveSizing(bool enable, double winRate = 0.5, double profitFactor = 1.5);
   
   // Advanced exit strategies
   bool              SetTrailingDrawdown(bool enable, double drawdownPercent = 30.0);
   bool              SetVolatilityExit(bool enable, double volatilityLevel = 2.0);
   
   // Time-based exit
   bool              SetTimeExit(bool enable, int maxHoldBars = 50);
   
   // Position monitoring
   bool              UpdatePositionMetrics(ulong ticket);
   
   // Risk management
   bool              CheckDailyDrawdown();
   bool              CheckPortfolioRisk();
   
   // Position analysis
   double            CalculatePositionScore(const string symbol, ENUM_ORDER_TYPE type);
   double            CalculateOptimalF(double winRate, double winLossRatio);
   double            CalculateKellyCriterion(double winRate, double winLossRatio);
   
   // Position clustering
   bool              IsInCluster(ulong ticket, double distance = 20.0);
   
   // Market regime detection
   ENUM_MARKET_REGIME GetMarketRegime();
   
   // News impact analysis
   int               GetNewsImpact();
   
   // Volatility analysis
   double            GetCurrentVolatility();
   
   // Correlation analysis
   double            GetPortfolioCorrelation(const string symbol);
   
   // Machine learning
   bool              LoadMLModel(const string modelFile);
   double            GetMLPositionScore(const string symbol, ENUM_ORDER_TYPE type);
   bool              UpdateMLModel(const MqlRates &rates[], const double &features[]);
   
   // Advanced position monitoring
   bool              CheckPositionHealth(ulong ticket);
   bool              CheckMarketConditions();
   bool              CheckPositionTiming(ulong ticket);
   
   // Advanced position adjustments
   bool              HedgePosition(ulong ticket);
   bool              AverageDown(ulong ticket, double maxDrawdown = 10.0);
   bool              ScaleOutAtProfit(ulong ticket, double profitTarget = 30.0, double scalePercent = 50.0);
   
   // Position analysis
   double            CalculatePositionValue(ulong ticket);
   double            CalculatePositionRiskReward(ulong ticket);
   double            CalculatePositionScore(ulong ticket);
   
   // Advanced order types
   bool              PlaceBracketOrder(const string symbol, ENUM_ORDER_TYPE type, double volume, 
                                     double entryPrice, double sl, double tp, 
                                     double breakEvenAt = 0, double trailingStop = 0, 
                                     datetime expiration = 0, const string comment = "");
   
   // Advanced position management
   bool              ScalePosition(ulong ticket, double newVolume);
   bool              ScalePositionByRisk(ulong ticket, double riskPercent);
   bool              ScalePositionByVolatility(ulong ticket, double volatilityMultiplier = 1.0);
   
   // Position monitoring and adjustment
   bool              CheckAndAdjustPosition(ulong ticket);
   bool              MonitorAndManagePositions();
   
   // Advanced risk management
   bool              SetRiskParameters(double maxRiskPerTrade, double maxDailyRisk, double maxDrawdown);
   bool              CheckRiskParameters();
   
   // Position analysis and optimization
   double            CalculateOptimalPositionSize(double riskAmount, double stopLoss);
   double            CalculatePositionRisk(double entryPrice, double stopLoss, double lotSize);
   double            CalculatePositionValue(double entryPrice, double lotSize);
   
   // Advanced position monitoring
   bool              CheckPositionHealth(ulong ticket, double maxDrawdown = 20.0);
   bool              CheckPositionTiming(ulong ticket, int maxBars = 50);
   
   // Advanced position adjustments
   bool              TrailingStop(ulong ticket, double trailingStop);
   bool              MoveToBreakEven(ulong ticket, double breakEvenAt);
   
   // Position analysis
   double            CalculatePositionRiskReward(ulong ticket, double entryPrice, double stopLoss, double takeProfit);
   double            CalculatePositionScore(ulong ticket, double winRate, double profitFactor);
   
   // Advanced order management
   bool              PlaceOCOOrders(ulong ticket, double stopLoss, double takeProfit);
   bool              PlaceBracketOrder(ulong ticket, double stopLoss, double takeProfit, 
                                     double breakEvenAt = 0, double trailingStop = 0);
   
   // Position monitoring and management
   bool              MonitorPosition(ulong ticket);
   bool              ManagePosition(ulong ticket);
   
   // Advanced position management
   bool              ScaleInAtDrawdown(ulong ticket, double drawdownPercent, double scaleFactor = 1.0);
   bool              ScaleOutAtProfit(ulong ticket, double profitPercent, double scaleFactor = 0.5);
   
   // Position analysis and optimization
   double            CalculateOptimalPositionSize(double accountBalance, double riskPercent, 
                                               double stopLoss, double contractSize);
   double            CalculatePositionRisk(double entryPrice, double stopLoss, 
                                        double lotSize, double contractSize);
   
   // Advanced position monitoring
   bool              CheckPositionHealth(ulong ticket, double maxDrawdownPercent, 
                                      int maxBarsHeld, double minRiskReward);
   
   // Advanced position adjustments
   bool              AdjustStopLoss(ulong ticket, double newStopLoss);
   bool              AdjustTakeProfit(ulong ticket, double newTakeProfit);
   
   // Position analysis
   double            CalculatePositionValue(double entryPrice, double lotSize, double contractSize);
   double            CalculatePositionRiskReward(ulong ticket, double currentPrice);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPositionManager::CPositionManager() :
   m_trade(NULL),
   m_symbol(NULL),
   m_initialized(false),
   m_slPoints(0.0),
   m_tpPoints(0.0),
   m_trailingStop(0.0),
   m_breakEven(0.0),
   m_autoBreakEven(false),
   m_scaleIn(false),
   m_scaleOut(false),
   m_breakEvenAt(0.0),
   m_scaleInAt(0.0),
   m_scaleOutAt(0.0),
   m_scaleInFactor(1.0),
   m_scaleOutFactor(0.5)
{
   // Initialize member variables in the initialization list
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPositionManager::~CPositionManager() {
   // Cleanup if needed
   if(m_trade != NULL) {
      delete m_trade;
      m_trade = NULL;
   }
   
   if(m_symbol != NULL) {
      delete m_symbol;
      m_symbol = NULL;
   }
}

//+------------------------------------------------------------------+
//| Initialize the position manager                                  |
//+------------------------------------------------------------------+
bool CPositionManager::Initialize(CTrade *trade, CSymbolInfo *symbol, 
                                double slPoints, double tpPoints, 
                                double trailingStop, double breakEven) {
   // Validate inputs
   if(trade == NULL || symbol == NULL) {
      Print("Error: Invalid trade or symbol pointer");
      return false;
   }
   
   if(slPoints < 0 || tpPoints < 0 || trailingStop < 0 || breakEven < 0) {
      Print("Error: Invalid parameters");
      return false;
   }
   
   // Store references
   m_trade = trade;
   m_symbol = symbol;
   
   // Store parameters
   m_slPoints = slPoints;
   m_tpPoints = tpPoints;
   m_trailingStop = trailingStop;
   m_breakEven = breakEven;
   
   m_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Open a new position                                              |
//+------------------------------------------------------------------+
bool CPositionManager::OpenPosition(ENUM_ORDER_TYPE type, double volume, 
                                  double price, double sl, double tp, 
                                  const string comment) {
   if(!m_initialized) {
      Print("Error: Position manager not initialized");
      return false;
   }
   
   // Validate inputs
   if(volume <= 0 || price <= 0) {
      Print("Error: Invalid volume or price");
      return false;
   }
   
   // Execute the trade
   if(type == ORDER_TYPE_BUY) {
      return m_trade.Buy(volume, m_symbol.Name(), price, sl, tp, comment);
   } 
   else if(type == ORDER_TYPE_SELL) {
      return m_trade.Sell(volume, m_symbol.Name(), price, sl, tp, comment);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Close a position by ticket                                       |
//+------------------------------------------------------------------+
bool CPositionManager::ClosePosition(ulong ticket, const string comment) {
   if(!m_initialized) {
      Print("Error: Position manager not initialized");
      return false;
   }
   
   // Select the position
   if(!m_position.SelectByTicket(ticket)) {
      Print("Error selecting position ", ticket);
      return false;
   }
   
   // Close the position
   return m_trade.PositionClose(ticket, m_position.Deviation(), comment);
}

//+------------------------------------------------------------------+
//| Close all open positions                                         |
//+------------------------------------------------------------------+
bool CPositionManager::CloseAllPositions(const string comment) {
   if(!m_initialized) {
      Print("Error: Position manager not initialized");
      return false;
   }
   
   bool result = true;
   int total = PositionsTotal();
   
   for(int i = total - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0) {
         if(!ClosePosition(ticket, comment)) {
            result = false;
         }
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Modify position stop loss and take profit                        |
//+------------------------------------------------------------------+
bool CPositionManager::ModifyPosition(ulong ticket, double sl, double tp) {
   if(!m_initialized) {
      Print("Error: Position manager not initialized");
      return false;
   }
   
   // Select the position
   if(!m_position.SelectByTicket(ticket)) {
      Print("Error selecting position ", ticket);
      return false;
   }
   
   // Modify the position
   return m_trade.PositionModify(ticket, sl, tp);
}

//+------------------------------------------------------------------+
//| Set position scaling profile                                     |
//+------------------------------------------------------------------+
bool CPositionManager::SetScalingProfile(ENUM_SCALING_PROFILE profile) {
   switch(profile) {
      case SCALING_AGGRESSIVE:
         m_scaleInFactor = 1.5;
         m_scaleOutFactor = 0.5;
         m_scaleInAt = 20.0;
         m_scaleOutAt = 30.0;
         break;
         
      case SCALING_MODERATE:
         m_scaleInFactor = 1.25;
         m_scaleOutFactor = 0.75;
         m_scaleInAt = 25.0;
         m_scaleOutAt = 40.0;
         break;
         
      case SCALING_CONSERVATIVE:
         m_scaleInFactor = 1.1;
         m_scaleOutFactor = 0.9;
         m_scaleInAt = 30.0;
         m_scaleOutAt = 50.0;
         break;
         
      case SCALING_NONE:
      default:
         m_scaleIn = false;
         m_scaleOut = false;
         return true;
   }
   
   m_scaleIn = true;
   m_scaleOut = true;
   return true;
}

//+------------------------------------------------------------------+
//| Set exit profile                                                 |
//+------------------------------------------------------------------+
bool CPositionManager::SetExitProfile(ENUM_EXIT_PROFILE profile) {
   switch(profile) {
      case EXIT_AGGRESSIVE:
         m_trailingStop = 20.0;
         m_breakEvenAt = 15.0;
         break;
         
      case EXIT_BALANCED:
         m_trailingStop = 30.0;
         m_breakEvenAt = 25.0;
         break;
         
      case EXIT_CONSERVATIVE:
         m_trailingStop = 50.0;
         m_breakEvenAt = 40.0;
         break;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get position size                                                |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionSize(ulong ticket) {
   if(m_position.SelectByTicket(ticket)) {
      return m_position.Volume();
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Get position profit                                              |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionProfit(ulong ticket) {
   if(m_position.SelectByTicket(ticket)) {
      return m_position.Profit();
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Get position stop loss level                                     |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionStopLoss(ulong ticket) {
   if(m_position.SelectByTicket(ticket)) {
      return m_position.StopLoss();
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Get position take profit level                                   |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionTakeProfit(ulong ticket) {
   if(m_position.SelectByTicket(ticket)) {
      return m_position.TakeProfit();
   }
   return 0.0;
}

//+------------------------------------------------------------------+
//| Update position manager (call in OnTick)                         |
//+------------------------------------------------------------------+
void CPositionManager::Update() {
   if(!m_initialized) {
      return;
   }
   
   // Update trailing stops if enabled
   if(m_trailingStop > 0) {
      CheckTrailingStop();
   }
   
   // Update break-even if enabled
   if(m_breakEven > 0) {
      CheckBreakEven();
   }
}

//+------------------------------------------------------------------+
//| Check and update trailing stop                                   |
//+------------------------------------------------------------------+
bool CPositionManager::CheckTrailingStop() {
   if(!m_initialized || m_trailingStop <= 0) {
      return false;
   }
   
   bool result = true;
   int total = PositionsTotal();
   
   for(int i = 0; i < total; i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && m_position.SelectByTicket(ticket)) {
         double currentSl = m_position.StopLoss();
         double currentPrice = (m_position.PositionType() == POSITION_TYPE_BUY) ? 
                              m_position.PriceCurrent() : m_position.PriceOpen();
         double newSl = 0.0;
         
         if(m_position.PositionType() == POSITION_TYPE_BUY) {
            newSl = m_symbol.Bid() - (m_trailingStop * m_symbol.Point());
            if(newSl > currentSl && newSl < m_symbol.Bid()) {
               if(!ModifyPosition(ticket, newSl, m_position.TakeProfit())) {
                  result = false;
               }
            }
         }
         else if(m_position.PositionType() == POSITION_TYPE_SELL) {
            newSl = m_symbol.Ask() + (m_trailingStop * m_symbol.Point());
            if((newSl < currentSl || currentSl == 0) && newSl > m_symbol.Ask()) {
               if(!ModifyPosition(ticket, newSl, m_position.TakeProfit())) {
                  result = false;
               }
            }
         }
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Check and update break-even level                                |
//+------------------------------------------------------------------+
bool CPositionManager::CheckBreakEven() {
   if(!m_initialized || m_breakEven <= 0) {
      return false;
   }
   
   bool result = true;
   int total = PositionsTotal();
   
   for(int i = 0; i < total; i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && m_position.SelectByTicket(ticket)) {
         double currentSl = m_position.StopLoss();
         double openPrice = m_position.PriceOpen();
         double currentPrice = (m_position.PositionType() == POSITION_TYPE_BUY) ? 
                              m_position.PriceCurrent() : m_position.PriceOpen();
         double pointsProfit = MathAbs(currentPrice - openPrice) / m_symbol.Point();
         
         if(pointsProfit >= m_breakEven) {
            if(m_position.PositionType() == POSITION_TYPE_BUY) {
               if(currentSl < openPrice) {
                  if(!ModifyPosition(ticket, openPrice, m_position.TakeProfit())) {
                     result = false;
                  }
               }
            }
            else if(m_position.PositionType() == POSITION_TYPE_SELL) {
               if(currentSl > openPrice || currentSl == 0) {
                  if(!ModifyPosition(ticket, openPrice, m_position.TakeProfit())) {
                     result = false;
                  }
               }
            }
         }
      }
   }
   
   return result;
}
