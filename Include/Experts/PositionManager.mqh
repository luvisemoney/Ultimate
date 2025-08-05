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
#include "Escape/InputValidation.mqh"

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
   
   // Time-based exit
   bool           m_useTimeExit;           // Enable time-based exit
   datetime       m_expiryTime;            // Position expiry time
   int            m_maxHoldBars;           // Maximum bars to hold position
   
   // Volatility-based position sizing
   bool           m_useVolatilitySizing;   // Enable volatility-based sizing
   int            m_volatilityPeriod;      // Period for volatility calculation
   double         m_volatilityMultiplier;  // Multiplier for position size
   double         m_maxPositionRisk;       // Maximum risk per position (%)
   
   // Correlation management
   string         m_correlationSymbols[];  // Array of correlated symbols
   double         m_maxCorrelation;        // Maximum allowed correlation
   
   // Grid trading
   bool           m_gridTrading;           // Enable grid trading
   double         m_gridStep;              // Grid step in pips
   int            m_maxGridLevels;         // Maximum grid levels
   double         m_gridVolumeMultiplier;  // Volume multiplier for grid levels
   
   // News event handling
   bool           m_newsFilter;            // Enable news filtering
   int            m_newsImpact;            // Minimum news impact level (1-3)
   int            m_minutesBeforeNews;     // Minutes before news to avoid trading
   int            m_minutesAfterNews;      // Minutes after news to avoid trading
   
   // Advanced risk management
   bool           m_useDynamicRisk;        // Enable dynamic risk adjustment
   double         m_maxDailyDrawdown;      // Maximum daily drawdown percentage
   double         m_maxPortfolioRisk;      // Maximum portfolio risk (%)
   double         m_riskDecayFactor;       // Risk reduction factor after losses
   
   // Adaptive position sizing
   bool           m_useAdaptiveSizing;     // Enable adaptive position sizing
   double         m_winRate;               // Tracked win rate (0-1)
   double         m_profitFactor;          // Tracked profit factor
   int            m_tradeCount;            // Number of trades in current session
   double         m_equityPeak;            // Peak equity in current session
   
   // Advanced exit strategies
   bool           m_useTrailingDrawdown;   // Enable trailing drawdown exit
   double         m_trailingDrawdown;      // Trailing drawdown percentage
   bool           m_useVolatilityExit;     // Enable volatility-based exit
   double         m_volatilityExitLevel;   // Volatility level for exit
   
   // Position clustering
   bool           m_usePositionClustering; // Enable position clustering
   double         m_clusterDistance;       // Distance between position clusters
   int            m_maxClusters;           // Maximum number of clusters
   
   // Machine learning integration
   bool           m_useMLPredictions;      // Enable ML-based predictions
   double         m_mlConfidenceThreshold; // Minimum confidence threshold
   
   // Market regime detection
   bool           m_useRegimeFilter;       // Enable market regime filtering
   int            m_regimePeriod;          // Period for regime detection
   double         m_trendThreshold;        // Threshold for trend detection
   double         m_rangeThreshold;        // Threshold for range detection
   
   // Private methods
   bool           ValidatePositionParams(const string symbol, double volume, double price, 
                                      double sl, double tp, const string comment);
   
public:
   // Constructor/Destructor
                     CPositionManager();
                    ~CPositionManager();
   
   // Initialization
   bool              Initialize(CTrade *trade, CSymbolInfo *symbol, double slPoints = 0, 
                              double tpPoints = 0, double trailingStop = 0, double breakEven = 0);
   
   // Position management
   bool              OpenPosition(const string symbol, ENUM_ORDER_TYPE type, double volume, 
                                double price, double sl, double tp, const string comment = "");
   bool              ClosePosition(ulong ticket, const string comment = "");
   bool              CloseAllPositions(const string symbol = "", int magic = -1);
   bool              ModifyPosition(ulong ticket, double sl, double tp);
   
   // Trailing stop
   void              CheckTrailingStop();
   
   // Advanced position management
   bool              SetBreakEven(double pips, double lockInPips = 0);
   bool              SetScaling(bool scaleIn, bool scaleOut, double scaleInAt = 0, 
                              double scaleOutAt = 0, double scaleInFactor = 0.5, 
                              double scaleOutFactor = 0.5);
   bool              SetTimeExit(bool enable, datetime expiry = 0, int maxBars = 0);
   bool              ScaleInPosition(ulong ticket, double volume);
   bool              ScaleOutPosition(ulong ticket, double volume);
   bool              PartialClose(ulong ticket, double percent);
   bool              CloseAtTime(ulong ticket, datetime closeTime);
   bool              CloseAtProfit(ulong ticket, double targetProfit, bool closePartial = false);
   bool              CloseAtLoss(ulong ticket, double maxLoss, bool closePartial = false);
   bool              MoveToBreakEven(ulong ticket);
   
   // Position analysis
   double            GetPositionRisk(ulong ticket);
   double            GetPositionRiskPercent(ulong ticket, double accountBalance = 0);
   double            GetPositionRiskReward(ulong ticket);
   datetime          GetPositionAge(ulong ticket, ENUM_TIME_UNITS unit = PERIOD_M1);
   
   // Getters
   bool              IsInitialized() const { return m_initialized; }
   int               TotalPositions(const string symbol = "", int magic = -1);
   double            GetPositionProfit(const string symbol = "", int magic = -1);
   double            GetPositionVolume(const string symbol = "", int magic = -1);
   bool              HasOpenPosition(const string symbol = "", int magic = -1);
   ENUM_POSITION_TYPE GetPositionType(ulong ticket);
   double            GetPositionOpenPrice(ulong ticket);
   double            GetPositionCurrentPrice(ulong ticket);
   double            GetPositionStopLoss(ulong ticket);
   double            GetPositionTakeProfit(ulong ticket);
   
   // Advanced position management
   bool              SetVolatilitySizing(bool enable, int period = 14, double multiplier = 1.0, double maxRisk = 2.0);
   double            CalculateVolatilityAdjustedVolume(double riskPercent, double slPips);
   bool              SetCorrelationFilter(string &symbols[], double maxCorrelation = 0.7);
   double            GetCorrelationWith(const string symbol, int period = 100);
   bool              IsCorrelationSafe();
   bool              SetGridTrading(bool enable, double gridStep = 20, int maxLevels = 5, double volumeMultiplier = 1.5);
   bool              ManageGridLevels(const string symbol, double currentPrice, ENUM_POSITION_TYPE type);
   bool              SetNewsFilter(bool enable, int minImpact = 2, int minutesBefore = 60, int minutesAfter = 30);
   bool              IsNewsEventImminent();
   bool              IsHighImpactNewsPending();
   
   // Advanced position scaling
   bool              SetScalingProfile(ENUM_SCALING_PROFILE profile);
   double            CalculateOptimalScaleInVolume(double baseVolume, int scaleLevel, double drawdownPct);
   bool              CheckScalingOpportunity(ulong ticket, double &volume);
   bool              ScaleInPosition(ulong ticket, double volume);
   bool              ScaleOutPosition(ulong ticket, double volume);
   
   // Advanced exit strategies
   bool              SetExitProfile(ENUM_EXIT_PROFILE profile);
   bool              CheckExitConditions(ulong ticket, double &closePrice, string &reason);
   bool              UsePyramidingExit(ulong ticket, double &closeVolume);
   bool              UseTimeExit(ulong ticket, datetime openTime);
   bool              UseVolatilityExit(ulong ticket, double currentVolatility);
   
   // Correlation-based position sizing
   double            CalculateCorrelationAdjustedVolume(const string symbol, double baseVolume);
   double            GetPortfolioCorrelation(const string symbol);
   double            GetMarketCorrelation(const string symbol1, const string symbol2, int period = 100);
   
   // Machine learning integration
   bool              LoadMLModel(const string modelFile);
   double            GetMLPositionScore(const string symbol, ENUM_POSITION_TYPE type);
   bool              UpdateMLModel(const MqlRates &rates[], const double &features[]);
   
   // Advanced position monitoring
   bool              MonitorPosition(ulong ticket);
   void              UpdatePositionStats(ulong ticket);
   bool              NeedsAdjustment(ulong ticket);
   
   // Advanced order management
   bool              PlaceBracketOrder(const string symbol, ENUM_ORDER_TYPE type, double volume, 
                                    double entryPrice, double sl, double tp, 
                                    double breakEvenAt = 0, double trailingStop = 0, 
                                    datetime expiration = 0, const string comment = "");
   bool              PlaceOCOOrders(const string symbol, ENUM_ORDER_TYPE type, double volume, 
                                 double price1, double price2, double sl, double tp, 
                                 const string comment = "");
   
   // Advanced risk controls
   bool              CheckVolatilitySpike();
   bool              CheckLiquidity(const string symbol);
   bool              CheckMarketHours();
   
   // Position clustering
   bool              SetPositionClustering(bool enable, double clusterDistance = 20.0, int maxClusters = 3);
   bool              IsInExistingCluster(const string symbol, double price, ENUM_POSITION_TYPE type);
   
   // Market regime detection
   bool              SetRegimeFilter(bool enable, int period = 50, double trendThreshold = 0.3, double rangeThreshold = 0.2);
   ENUM_MARKET_REGIME DetectMarketRegime();
   bool              IsFavorableRegime(ENUM_POSITION_TYPE type, ENUM_MARKET_REGIME regime);
   
   // Advanced risk management
   bool              SetDynamicRisk(bool enable, double maxDailyDrawdown = 5.0, double maxPositionRisk = 2.0, 
                                  double maxPortfolioRisk = 20.0, double riskDecay = 0.9);
   double            CalculateDynamicRisk(double baseRisk);
   bool              CheckDrawdownLimits();
   double            GetCurrentDrawdown();
   
   // Adaptive position sizing
   bool              SetAdaptiveSizing(bool enable, double initialWinRate = 0.5, double initialProfitFactor = 1.5);
   void              UpdateTradeStats(bool isWin, double profit);
   double            CalculateAdaptiveVolume(double baseVolume, double confidence = 1.0);
   
   // Advanced exit strategies
   bool              SetTrailingDrawdown(bool enable, double drawdownPercent = 10.0);
   bool              SetVolatilityExit(bool enable, double volatilityThreshold = 2.0);
   bool              CheckAdvancedExitConditions(ulong ticket);
   
   // Position clustering
   bool              SetPositionClustering(bool enable, double clusterDistance = 20.0, int maxClusters = 3);
   bool              IsInExistingCluster(const string symbol, double price, ENUM_POSITION_TYPE type);
   
   // Machine learning integration
   bool              SetMLIntegration(bool enable, double confidenceThreshold = 0.7);
   double            GetMLPrediction(const string symbol, ENUM_TIMEFRAMES timeframe);
   
   // Market regime detection
   bool              SetRegimeFilter(bool enable, int period = 50, double trendThreshold = 0.3, double rangeThreshold = 0.2);
   ENUM_MARKET_REGIME DetectMarketRegime();
   bool              IsFavorableRegime(ENUM_POSITION_TYPE type, ENUM_MARKET_REGIME regime);
   
   // Advanced position analysis
   double            CalculateOptimalF(double winRate, double winLossRatio);
   double            CalculateKellyCriterion(double winRate, double winLossRatio);
   double            CalculatePositionScore(const string symbol, ENUM_POSITION_TYPE type);
   
   // Advanced order types
   bool              PlaceBracketOrder(const string symbol, ENUM_ORDER_TYPE type, double volume, double entryPrice,
                                    double sl, double tp, double breakEvenAt = 0, double trailingStop = 0, 
                                    datetime expiration = 0, const string comment = "");
   bool              PlaceOCOOrders(const string symbol, ENUM_ORDER_TYPE type, double volume, double price1,
                                 double price2, double sl, double tp, const string comment = "");
   
   // Advanced position monitoring
   bool              MonitorPosition(ulong ticket);
   void              UpdatePositionStats(ulong ticket);
   bool              NeedsAdjustment(ulong ticket);
   
   // Advanced risk controls
   bool              CheckVolatilitySpike();
   bool              CheckLiquidity(const string symbol);
   bool              CheckMarketHours();
   
   // State management
   void              Update();
   
   // Advanced position analysis
   double            CalculatePositionScore(const string symbol, ENUM_POSITION_TYPE type);
   double            CalculateOptimalF(double winRate, double winLossRatio);
   double            CalculateKellyCriterion(double winRate, double winLossRatio);
   
   // Risk management
   bool              SetDynamicRisk(bool enable, double maxDailyDrawdown = 5.0, double maxPositionRisk = 2.0, 
                                  double maxPortfolioRisk = 20.0, double riskDecay = 0.9);
   double            CalculateDynamicRisk(double baseRisk);
   bool              CheckDrawdownLimits();
   double            GetCurrentDrawdown();
   
   // Adaptive position sizing
   bool              SetAdaptiveSizing(bool enable, double initialWinRate = 0.5, double initialProfitFactor = 1.5);
   void              UpdateTradeStats(bool isWin, double profit);
   double            CalculateAdaptiveVolume(double baseVolume, double confidence = 1.0);
   
   // Advanced exit strategies
   bool              SetTrailingDrawdown(bool enable, double drawdownPercent = 10.0);
   bool              SetVolatilityExit(bool enable, double volatilityThreshold = 2.0);
   bool              CheckAdvancedExitConditions(ulong ticket);
   
   // Machine learning integration
   bool              SetMLIntegration(bool enable, double confidenceThreshold = 0.7);
   double            GetMLPrediction(const string symbol, ENUM_TIMEFRAMES timeframe);
   
   // Position clustering
   bool              SetPositionClustering(bool enable, double clusterDistance = 20.0, int maxClusters = 3);
   
   // Market regime detection
   bool              SetRegimeFilter(bool enable, int period = 50, double trendThreshold = 0.3, double rangeThreshold = 0.2);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPositionManager::CPositionManager() : 
   m_trade(NULL),
   m_symbol(NULL),
   m_slPoints(0),
   m_tpPoints(0),
   m_trailingStop(0),
   m_breakEven(0),
   m_initialized(false),
   m_autoBreakEven(false),
   m_scaleIn(false),
   m_scaleOut(false),
   m_breakEvenAt(0),
   m_scaleInAt(0),
   m_scaleOutAt(0),
   m_scaleInFactor(0.5),
   m_scaleOutFactor(0.5),
   m_useTimeExit(false),
   m_expiryTime(0),
   m_maxHoldBars(0),
   m_useVolatilitySizing(false),
   m_volatilityPeriod(14),
   m_volatilityMultiplier(1.0),
   m_maxPositionRisk(2.0),
   m_maxCorrelation(0.7),
   m_gridTrading(false),
   m_gridStep(20.0),
   m_maxGridLevels(5),
   m_gridVolumeMultiplier(1.5),
   m_newsFilter(false),
   m_newsImpact(2),
   m_minutesBeforeNews(60),
   m_minutesAfterNews(30),
   m_useDynamicRisk(false),
   m_maxDailyDrawdown(5.0),
   m_maxPortfolioRisk(20.0),
   m_riskDecayFactor(0.9),
   m_useAdaptiveSizing(false),
   m_winRate(0.5),
   m_profitFactor(1.5),
   m_tradeCount(0),
   m_equityPeak(0),
   m_useTrailingDrawdown(false),
   m_trailingDrawdown(10.0),
   m_useVolatilityExit(false),
   m_volatilityExitLevel(2.0),
   m_usePositionClustering(false),
   m_clusterDistance(20.0),
   m_maxClusters(3),
   m_useMLPredictions(false),
   m_mlConfidenceThreshold(0.7),
   m_useRegimeFilter(false),
   m_regimePeriod(50),
   m_trendThreshold(0.3),
   m_rangeThreshold(0.2)
{
   // Initialize position info
   m_position = CPositionInfo();
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPositionManager::~CPositionManager() {
   // Clean up
   m_trade = NULL;
   m_symbol = NULL;
}

//+------------------------------------------------------------------+
//| Initialize position manager                                      |
//+------------------------------------------------------------------+
bool CPositionManager::Initialize(CTrade *trade, CSymbolInfo *symbol, double slPoints, 
                               double tpPoints, double trailingStop, double breakEven) {
   // Validate inputs
   if(trade == NULL || symbol == NULL) {
      Print("Error: Invalid trade or symbol object");
      return false;
   }
   
   // Store references and settings
   m_trade = trade;
   m_symbol = symbol;
   m_slPoints = slPoints;
   m_tpPoints = tpPoints;
   m_trailingStop = trailingStop;
   m_breakEven = breakEven;
   
   m_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Validate position parameters                                     |
//+------------------------------------------------------------------+
bool CPositionManager::ValidatePositionParams(const string symbol, double volume, double price, 
                                           double sl, double tp, const string comment) {
   // Validate symbol
   if(symbol == "" || !SymbolSelect(symbol, true)) {
      Print("Error: Invalid symbol ", symbol);
      return false;
   }
   
   // Validate volume
   double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double volumeStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   if(volume < minVolume || volume > maxVolume) {
      PrintFormat("Error: Volume %.2f is outside allowed range [%.2f, %.2f]", 
                 volume, minVolume, maxVolume);
      return false;
   }
   
   // Normalize volume to the nearest step
   volume = MathFloor(volume / volumeStep) * volumeStep;
   
   // Validate price levels
   if(price <= 0) {
      Print("Error: Invalid price ", price);
      return false;
   }
   
   // Validate stop loss and take profit levels
   if((sl > 0 && sl >= price) || (sl < 0 && sl <= -price)) {
      Print("Error: Invalid stop loss level ", sl);
      return false;
   }
   
   if((tp > 0 && tp <= price) || (tp < 0 && tp >= -price)) {
      Print("Error: Invalid take profit level ", tp);
      return false;
   }
   
   // Validate comment length
   if(StringLen(comment) > 31) {
      Print("Error: Comment is too long (max 31 characters)");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Open a new position                                              |
//+------------------------------------------------------------------+
bool CPositionManager::OpenPosition(const string symbol, ENUM_ORDER_TYPE type, double volume, 
                                  double price, double sl, double tp, const string comment) {
   if(!m_initialized) {
      Print("Error: Position manager not initialized");
      return false;
   }
   
   // Validate parameters
   if(!ValidatePositionParams(symbol, volume, price, sl, tp, comment)) {
      return false;
   }
   
   // Open position based on order type
   if(type == ORDER_TYPE_BUY) {
      if(!m_trade.Buy(volume, symbol, price, sl, tp, comment)) {
         Print("Error opening buy position: ", GetLastError());
         return false;
      }
   }
   else if(type == ORDER_TYPE_SELL) {
      if(!m_trade.Sell(volume, symbol, price, sl, tp, comment)) {
         Print("Error opening sell position: ", GetLastError());
         return false;
      }
   }
   else {
      Print("Error: Unsupported order type");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Close a position by ticket                                       |
//+------------------------------------------------------------------+
bool CPositionManager::ClosePosition(ulong ticket, const string comment) {
   if(!m_initialized) {
      Print("Error: Position manager not initialized");
      return false;
   }
   
   // Select position by ticket
   if(!m_position.SelectByTicket(ticket)) {
      Print("Error selecting position ", ticket, ": ", GetLastError());
      return false;
   }
   
   // Close the position
   if(!m_trade.PositionClose(ticket, m_position.Deviation())) {
      Print("Error closing position ", ticket, ": ", GetLastError());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
bool CPositionManager::CloseAllPositions(const string symbol = "", int magic = -1) {
   bool result = true;
   
   // Loop through all open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         // Check symbol filter
         if(symbol != "" && m_position.Symbol() != symbol) {
            continue;
         }
         
         // Check magic number filter
         if(magic >= 0 && (int)m_position.Magic() != magic) {
            continue;
         }
         
         // Close the position
         if(!ClosePosition(m_position.Ticket())) {
            result = false;
         }
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Modify position's stop loss and take profit                      |
//+------------------------------------------------------------------+
bool CPositionManager::ModifyPosition(ulong ticket, double sl, double tp) {
   if(!m_initialized) {
      Print("Error: Position manager not initialized");
      return false;
   }
   
   // Select position by ticket
   if(!m_position.SelectByTicket(ticket)) {
      Print("Error selecting position ", ticket, ": ", GetLastError());
      return false;
   }
   
   // Get current position details
   double openPrice = m_position.PriceOpen();
   double currentSl = m_position.StopLoss();
   double currentTp = m_position.TakeProfit();
   
   // Only modify if values have changed
   if(currentSl != sl || currentTp != tp) {
      if(!m_trade.PositionModify(ticket, sl, tp)) {
         Print("Error modifying position ", ticket, ": ", GetLastError());
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check and update trailing stops                                   |
//+------------------------------------------------------------------+
void CPositionManager::CheckTrailingStop() {
   if(!m_initialized || m_trailingStop <= 0) {
      return;
   }
   
   // Update symbol rates
   m_symbol.RefreshRates();
   
   // Loop through all open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         // Skip if not our symbol
         if(m_position.Symbol() != m_symbol.Name()) {
            continue;
         }
         
         double positionSl = m_position.StopLoss();
         double newSl = 0;
         
         if(m_position.PositionType() == POSITION_TYPE_BUY) {
            // For long positions, trail below the current price
            newSl = m_symbol.Bid() - m_trailingStop * m_symbol.Point();
            
            // Only move the stop loss up
            if(newSl > positionSl || positionSl == 0) {
               ModifyPosition(m_position.Ticket(), newSl, m_position.TakeProfit());
            }
         }
         else if(m_position.PositionType() == POSITION_TYPE_SELL) {
            // For short positions, trail above the current price
            newSl = m_symbol.Ask() + m_trailingStop * m_symbol.Point();
            
            // Only move the stop loss down
            if((newSl < positionSl || positionSl == 0) && newSl > 0) {
               ModifyPosition(m_position.Ticket(), newSl, m_position.TakeProfit());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get total number of positions                                    |
//+------------------------------------------------------------------+
int CPositionManager::TotalPositions(const string symbol = "", int magic = -1) {
   int count = 0;
   
   for(int i = 0; i < PositionsTotal(); i++) {
      if(m_position.SelectByIndex(i)) {
         // Check symbol filter
         if(symbol != "" && m_position.Symbol() != symbol) {
            continue;
         }
         
         // Check magic number filter
         if(magic >= 0 && (int)m_position.Magic() != magic) {
            continue;
         }
         
         count++;
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Get total profit/loss for positions                              |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionProfit(const string symbol = "", int magic = -1) {
   double profit = 0;
   
   for(int i = 0; i < PositionsTotal(); i++) {
      if(m_position.SelectByIndex(i)) {
         // Check symbol filter
         if(symbol != "" && m_position.Symbol() != symbol) {
            continue;
         }
         
         // Check magic number filter
         if(magic >= 0 && (int)m_position.Magic() != magic) {
            continue;
         }
         
         profit += m_position.Profit() + m_position.Swap() + m_position.Commission();
      }
   }
   
   return profit;
}

//+------------------------------------------------------------------+
//| Set break-even parameters                                        |
//+------------------------------------------------------------------+
bool CPositionManager::SetBreakEven(double pips, double lockInPips = 0) {
   if(pips <= 0) {
      m_autoBreakEven = false;
      return true;
   }
   
   m_autoBreakEven = true;
   m_breakEvenAt = pips * m_symbol.Point() * 10; // Convert pips to points
   return true;
}

//+------------------------------------------------------------------+
//| Set position scaling parameters                                  |
//+------------------------------------------------------------------+
bool CPositionManager::SetScaling(bool scaleIn, bool scaleOut, double scaleInAt, 
                               double scaleOutAt, double scaleInFactor, double scaleOutFactor) {
   m_scaleIn = scaleIn;
   m_scaleOut = scaleOut;
   
   if(scaleIn) {
      m_scaleInAt = scaleInAt * m_symbol.Point() * 10;
      m_scaleInFactor = MathMin(MathMax(scaleInFactor, 0.1), 1.0);
   }
   
   if(scaleOut) {
      m_scaleOutAt = scaleOutAt * m_symbol.Point() * 10;
      m_scaleOutFactor = MathMin(MathMax(scaleOutFactor, 0.1), 1.0);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Set time-based exit parameters                                   |
//+------------------------------------------------------------------+
bool CPositionManager::SetTimeExit(bool enable, datetime expiry, int maxBars) {
   m_useTimeExit = enable;
   if(enable) {
      if(expiry > 0) m_expiryTime = expiry;
      if(maxBars > 0) m_maxHoldBars = maxBars;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Scale out of an existing position                                |
//+------------------------------------------------------------------+
bool CPositionManager::ScaleOutPosition(ulong ticket, double volume) {
   if(!m_position.SelectByTicket(ticket)) {
      Print("Error selecting position ", ticket);
      return false;
   }
   
   // Calculate volume to close if not specified
   if(volume <= 0) {
      volume = m_position.Volume() * m_scaleOutFactor;
   }
   
   // Close a portion of the position
   return PartialClose(ticket, volume / m_position.Volume() * 100);
}

//+------------------------------------------------------------------+
//| Partially close a position                                      |
//+------------------------------------------------------------------+
bool CPositionManager::PartialClose(ulong ticket, double percent) {
   if(percent <= 0 || percent > 100) {
      Print("Error: Invalid percentage ", percent);
      return false;
   }
   
   if(!m_position.SelectByTicket(ticket)) {
      Print("Error selecting position ", ticket);
      return false;
   }
   
   // Calculate volume to close
   double volume = NormalizeDouble(m_position.Volume() * percent / 100, 2);
   if(volume < m_symbol.LotsMin()) {
      Print("Error: Volume too small for partial close");
      return false;
   }
   
   // Close part of the position
   return m_trade.PositionClosePartial(ticket, volume);
}

//+------------------------------------------------------------------+
//| Close position at specific time                                  |
//+------------------------------------------------------------------+
bool CPositionManager::CloseAtTime(ulong ticket, datetime closeTime) {
   if(TimeCurrent() >= closeTime) {
      return ClosePosition(ticket, "Time-based exit");
   }
   return false;
}

//+------------------------------------------------------------------+
//| Close position when target profit is reached                     |
//+------------------------------------------------------------------+
bool CPositionManager::CloseAtProfit(ulong ticket, double targetProfit, bool closePartial = false) {
   if(!m_position.SelectByTicket(ticket)) {
      return false;
   }
   
   double currentProfit = m_position.Profit() + m_position.Swap() + m_position.Commission();
   
   if(currentProfit >= targetProfit) {
      if(closePartial) {
         // Close a portion based on how much we're in profit
         double profitRatio = MathMin(1.0, currentProfit / targetProfit);
         return PartialClose(ticket, profitRatio * 100);
      } else {
         return ClosePosition(ticket, "Target profit reached");
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Close position when max loss is reached                          |
//+------------------------------------------------------------------+
bool CPositionManager::CloseAtLoss(ulong ticket, double maxLoss, bool closePartial = false) {
   if(!m_position.SelectByTicket(ticket)) {
      return false;
   }
   
   double currentLoss = MathAbs(m_position.Profit() + m_position.Swap() + m_position.Commission());
   
   if(currentLoss >= maxLoss) {
      if(closePartial) {
         // Close a portion based on how much we're in loss
         double lossRatio = MathMin(1.0, currentLoss / maxLoss);
         return PartialClose(ticket, lossRatio * 100);
      } else {
         return ClosePosition(ticket, "Max loss reached");
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Move position to break-even                                      |
//+------------------------------------------------------------------+
bool CPositionManager::MoveToBreakEven(ulong ticket) {
   if(!m_position.SelectByTicket(ticket)) {
      return false;
   }
   
   double openPrice = m_position.PriceOpen();
   double currentSl = m_position.StopLoss();
   double newSl = 0;
   
   if(m_position.PositionType() == POSITION_TYPE_BUY) {
      newSl = openPrice + m_symbol.Spread() * m_symbol.Point();
      if(newSl > currentSl || currentSl == 0) {
         return ModifyPosition(ticket, newSl, m_position.TakeProfit());
      }
   } else if(m_position.PositionType() == POSITION_TYPE_SELL) {
      newSl = openPrice - m_symbol.Spread() * m_symbol.Point();
      if((newSl < currentSl || currentSl == 0) && newSl > 0) {
         return ModifyPosition(ticket, newSl, m_position.TakeProfit());
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get position risk in account currency                            |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionRisk(ulong ticket) {
   if(!m_position.SelectByTicket(ticket)) {
      return 0;
   }
   
   double openPrice = m_position.PriceOpen();
   double sl = m_position.StopLoss();
   double volume = m_position.Volume();
   
   if(sl == 0) return 0;
   
   double tickValue = m_symbol.TickValue();
   double tickSize = m_symbol.TickSize();
   double pointValue = tickValue / tickSize * m_symbol.Point();
   
   if(m_position.PositionType() == POSITION_TYPE_BUY) {
      return (openPrice - sl) * volume * pointValue;
   } else {
      return (sl - openPrice) * volume * pointValue;
   }
}

//+------------------------------------------------------------------+
//| Get position risk as percentage of account balance               |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionRiskPercent(ulong ticket, double accountBalance = 0) {
   if(accountBalance <= 0) {
      accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   }
   
   double risk = GetPositionRisk(ticket);
   return (risk / accountBalance) * 100;
}

//+------------------------------------------------------------------+
//| Get position risk/reward ratio                                   |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionRiskReward(ulong ticket) {
   if(!m_position.SelectByTicket(ticket)) {
      return 0;
   }
   
   double openPrice = m_position.PriceOpen();
   double sl = m_position.StopLoss();
   double tp = m_position.TakeProfit();
   
   if(sl == 0 || tp == 0) return 0;
   
   if(m_position.PositionType() == POSITION_TYPE_BUY) {
      return (tp - openPrice) / (openPrice - sl);
   } else {
      return (openPrice - tp) / (sl - openPrice);
   }
}

//+------------------------------------------------------------------+
//| Get position age in specified time units                         |
//+------------------------------------------------------------------+
datetime CPositionManager::GetPositionAge(ulong ticket, ENUM_TIME_UNITS unit = PERIOD_M1) {
   if(!m_position.SelectByTicket(ticket)) {
      return 0;
   }
   
   datetime age = TimeCurrent() - m_position.Time();
   
   switch(unit) {
      case PERIOD_M1:  return age / 60;
      case PERIOD_M5:  return age / (60 * 5);
      case PERIOD_M15: return age / (60 * 15);
      case PERIOD_M30: return age / (60 * 30);
      case PERIOD_H1:  return age / (60 * 60);
      case PERIOD_H4:  return age / (60 * 60 * 4);
      case PERIOD_D1:  return age / (60 * 60 * 24);
      default:         return age;
   }
}

//+------------------------------------------------------------------+
//| Get total position volume                                        |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionVolume(const string symbol = "", int magic = -1) {
   double volume = 0;
   
   for(int i = 0; i < PositionsTotal(); i++) {
      if(m_position.SelectByIndex(i)) {
         if((symbol == "" || m_position.Symbol() == symbol) && 
            (magic < 0 || (int)m_position.Magic() == magic)) {
            volume += m_position.Volume();
         }
      }
   }
   
   return volume;
}

//+------------------------------------------------------------------+
//| Check if there are any open positions                           |
//+------------------------------------------------------------------+
bool CPositionManager::HasOpenPosition(const string symbol = "", int magic = -1) {
   return (TotalPositions(symbol, magic) > 0);
}

//+------------------------------------------------------------------+
//| Get position type                                                |
//+------------------------------------------------------------------+
ENUM_POSITION_TYPE CPositionManager::GetPositionType(ulong ticket) {
   if(m_position.SelectByTicket(ticket)) {
      return m_position.PositionType();
   }
   return WRONG_VALUE;
}

//+------------------------------------------------------------------+
//| Get position open price                                          |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionOpenPrice(ulong ticket) {
   if(m_position.SelectByTicket(ticket)) {
      return m_position.PriceOpen();
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Get position current price                                       |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionCurrentPrice(ulong ticket) {
   if(!m_position.SelectByTicket(ticket)) {
      return 0;
   }
   
   if(m_position.PositionType() == POSITION_TYPE_BUY) {
      return m_symbol.Bid();
   } else {
      return m_symbol.Ask();
   }
}

//+------------------------------------------------------------------+
//| Get position stop loss level                                     |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionStopLoss(ulong ticket) {
   if(m_position.SelectByTicket(ticket)) {
      return m_position.StopLoss();
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Get position take profit level                                   |
//+------------------------------------------------------------------+
double CPositionManager::GetPositionTakeProfit(ulong ticket) {
   if(m_position.SelectByTicket(ticket)) {
      return m_position.TakeProfit();
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Set volatility-based position sizing                             |
//+------------------------------------------------------------------+
bool CPositionManager::SetVolatilitySizing(bool enable, int period, double multiplier, double maxRisk) {
   m_useVolatilitySizing = enable;
   if(enable) {
      m_volatilityPeriod = MathMax(period, 5);
      m_volatilityMultiplier = MathMax(multiplier, 0.1);
      m_maxPositionRisk = MathMin(MathMax(maxRisk, 0.1), 10.0);
   }
   return true;
}

//+------------------------------------------------------------------+
//| Calculate position size based on volatility                      |
//+------------------------------------------------------------------+
double CPositionManager::CalculateVolatilityAdjustedVolume(double riskPercent, double slPips) {
   if(!m_initialized || !m_useVolatilitySizing) {
      return 0.0;
   }
   
   // Calculate ATR for volatility
   double atr = iATR(m_symbol.Name(), PERIOD_CURRENT, m_volatilityPeriod, 0);
   double atrPips = atr / (m_symbol.Point() * 10);
   
   // Get account balance and calculate risk amount
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (riskPercent / 100.0);
   
   // Calculate position size based on ATR
   double tickValue = m_symbol.TickValue();
   double tickSize = m_symbol.TickSize();
   double pointValue = tickValue / tickSize * m_symbol.Point();
   
   // Adjust position size based on volatility
   double volume = riskAmount / (slPips * 10 * pointValue);
   double volatilityAdjustment = m_volatilityMultiplier * (50.0 / atrPips);
   volume *= volatilityAdjustment;
   
   // Apply position limits
   double minVolume = m_symbol.LotsMin();
   double maxVolume = m_symbol.LotsMax();
   double stepVolume = m_symbol.LotsStep();
   
   volume = MathFloor(volume / stepVolume) * stepVolume;
   volume = MathMin(MathMax(volume, minVolume), maxVolume);
   
   return volume;
}

//+------------------------------------------------------------------+
//| Set correlation filter for position management                   |
//+------------------------------------------------------------------+
bool CPositionManager::SetCorrelationFilter(string &symbols[], double maxCorrelation) {
   ArrayFree(m_correlationSymbols);
   int count = ArraySize(symbols);
   if(count == 0) return false;
   
   ArrayResize(m_correlationSymbols, count);
   for(int i = 0; i < count; i++) {
      m_correlationSymbols[i] = symbols[i];
   }
   
   m_maxCorrelation = MathMin(MathMax(maxCorrelation, 0.1), 1.0);
   return true;
}

//+------------------------------------------------------------------+
//| Get correlation with another symbol                              |
//+------------------------------------------------------------------+
double CPositionManager::GetCorrelationWith(const string symbol, int period = 100) {
   if(!m_initialized || symbol == m_symbol.Name()) return 1.0;
   
   // Get close prices for both symbols
   double basePrices[], targetPrices[];
   ArraySetAsSeries(basePrices, true);
   ArraySetAsSeries(targetPrices, true);
   
   if(CopyClose(m_symbol.Name(), PERIOD_CURRENT, 0, period, basePrices) != period ||
      CopyClose(symbol, PERIOD_CURRENT, 0, period, targetPrices) != period) {
      Print("Error getting price data for correlation");
      return 0.0;
   }
   
   // Calculate correlation coefficient
   return MathCorrelation(basePrices, targetPrices, period);
}

//+------------------------------------------------------------------+
//| Check if correlation is within safe limits                      |
//+------------------------------------------------------------------+
bool CPositionManager::IsCorrelationSafe() {
   int count = ArraySize(m_correlationSymbols);
   if(count == 0) return true;
   
   for(int i = 0; i < count; i++) {
      double correlation = GetCorrelationWith(m_correlationSymbols[i]);
      if(MathAbs(correlation) > m_maxCorrelation) {
         PrintFormat("High correlation (%.2f) with %s", correlation, m_correlationSymbols[i]);
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Configure grid trading parameters                               |
//+------------------------------------------------------------------+
bool CPositionManager::SetGridTrading(bool enable, double gridStep, int maxLevels, double volumeMultiplier) {
   m_gridTrading = enable;
   if(enable) {
      m_gridStep = MathMax(gridStep, 1.0) * m_symbol.Point() * 10; // Convert pips to points
      m_maxGridLevels = MathMax(maxLevels, 1);
      m_gridVolumeMultiplier = MathMax(volumeMultiplier, 1.0);
   }
   return true;
}

//+------------------------------------------------------------------+
//| Manage grid trading levels                                      |
//+------------------------------------------------------------------+
bool CPositionManager::ManageGridLevels(const string symbol, double currentPrice, ENUM_POSITION_TYPE type) {
   if(!m_gridTrading || !m_initialized) return false;
   
   // Count existing grid levels
   int gridLevels = 0;
   for(int i = 0; i < PositionsTotal(); i++) {
      if(m_position.SelectByIndex(i) && m_position.Symbol() == symbol) {
         gridLevels++;
      }
   }
   
   // Check if we can add a new grid level
   if(gridLevels >= m_maxGridLevels) return false;
   
   // Get the last position in the grid
   double lastPrice = (type == POSITION_TYPE_BUY) ? 0 : DBL_MAX;
   double totalVolume = 0;
   
   for(int i = 0; i < PositionsTotal(); i++) {
      if(m_position.SelectByIndex(i) && m_position.Symbol() == symbol && 
         m_position.PositionType() == type) {
         if((type == POSITION_TYPE_BUY && m_position.PriceOpen() > lastPrice) ||
            (type == POSITION_TYPE_SELL && m_position.PriceOpen() < lastPrice)) {
            lastPrice = m_position.PriceOpen();
         }
         totalVolume += m_position.Volume();
      }
   }
   
   // Calculate next grid level
   double nextLevel = 0;
   double volume = 0;
   
   if(type == POSITION_TYPE_BUY) {
      nextLevel = (lastPrice == 0) ? currentPrice : lastPrice - m_gridStep;
      if(currentPrice <= nextLevel) {
         volume = totalVolume * m_gridVolumeMultiplier;
         return OpenPosition(symbol, type, volume, 0, 0, 0, "Grid Level " + IntegerToString(gridLevels + 1));
      }
   } else {
      nextLevel = (lastPrice == DBL_MAX) ? currentPrice : lastPrice + m_gridStep;
      if(currentPrice >= nextLevel) {
         volume = totalVolume * m_gridVolumeMultiplier;
         return OpenPosition(symbol, type, volume, 0, 0, 0, "Grid Level " + IntegerToString(gridLevels + 1));
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Configure news filter parameters                                |
//+------------------------------------------------------------------+
bool CPositionManager::SetNewsFilter(bool enable, int minImpact, int minutesBefore, int minutesAfter) {
   m_newsFilter = enable;
   if(enable) {
      m_newsImpact = MathMin(MathMax(minImpact, 1), 3);
      m_minutesBeforeNews = MathMax(minutesBefore, 1);
      m_minutesAfterNews = MathMax(minutesAfter, 1);
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check if a high-impact news event is imminent                   |
//+------------------------------------------------------------------+
bool CPositionManager::IsNewsEventImminent() {
   if(!m_newsFilter) return false;
   
   // This is a placeholder - implement actual news checking logic
   // using your preferred news feed or calendar
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if high-impact news is pending                            |
//+------------------------------------------------------------------+
bool CPositionManager::IsHighImpactNewsPending() {
   if(!m_newsFilter) return false;
   
   // This is a placeholder - implement actual news checking logic
   // using your preferred news feed or calendar
   
   return false;
}

//+------------------------------------------------------------------+
//| Set dynamic risk parameters                                      |
//+------------------------------------------------------------------+
bool CPositionManager::SetDynamicRisk(bool enable, double maxDailyDrawdown, double maxPositionRisk, 
                                    double maxPortfolioRisk, double riskDecay) {
   m_useDynamicRisk = enable;
   if(enable) {
      m_maxDailyDrawdown = MathMin(MathMax(maxDailyDrawdown, 1.0), 50.0);
      m_maxPositionRisk = MathMin(MathMax(maxPositionRisk, 0.1), 10.0);
      m_maxPortfolioRisk = MathMin(MathMax(maxPortfolioRisk, 1.0), 50.0);
      m_riskDecayFactor = MathMin(MathMax(riskDecay, 0.5), 0.99);
      
      // Initialize equity peak
      if(m_equityPeak == 0) {
         m_equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
      }
   }
   return true;
}

//+------------------------------------------------------------------+
//| Calculate dynamic risk based on performance                      |
//+------------------------------------------------------------------+
double CPositionManager::CalculateDynamicRisk(double baseRisk) {
   if(!m_useDynamicRisk) return baseRisk;
   
   // Check drawdown limits
   if(!CheckDrawdownLimits()) {
      return 0.0; // Stop trading if drawdown limit reached
   }
   
   // Calculate risk based on performance
   double riskMultiplier = 1.0;
   
   // Reduce risk after losses
   double currentDrawdown = GetCurrentDrawdown();
   if(currentDrawdown > 0) {
      riskMultiplier *= MathPow(m_riskDecayFactor, currentDrawdown / (m_maxDailyDrawdown / 2.0));
   }
   
   // Adjust based on win rate
   if(m_tradeCount > 10) {
      if(m_winRate < 0.4) {
         riskMultiplier *= 0.5; // Reduce risk if win rate is low
      } else if(m_winRate > 0.6) {
         riskMultiplier *= 1.2; // Slightly increase risk if win rate is high
      }
   }
   
   // Apply position and portfolio limits
   double maxRisk = MathMin(m_maxPositionRisk, m_maxPortfolioRisk / (PositionsTotal() + 1));
   return MathMin(baseRisk * riskMultiplier, maxRisk);
}

//+------------------------------------------------------------------+
//| Check if drawdown limits are exceeded                            |
//+------------------------------------------------------------------+
bool CPositionManager::CheckDrawdownLimits() {
   if(!m_useDynamicRisk) return true;
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   m_equityPeak = MathMax(m_equityPeak, currentEquity);
   
   double drawdown = 1.0 - (currentEquity / m_equityPeak);
   return (drawdown * 100.0) < m_maxDailyDrawdown;
}

//+------------------------------------------------------------------+
//| Get current drawdown percentage                                  |
//+------------------------------------------------------------------+
double CPositionManager::GetCurrentDrawdown() {
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   m_equityPeak = MathMax(m_equityPeak, currentEquity);
   return (1.0 - (currentEquity / m_equityPeak)) * 100.0;
}

//+------------------------------------------------------------------+
//| Set adaptive sizing parameters                                   |
//+------------------------------------------------------------------+
bool CPositionManager::SetAdaptiveSizing(bool enable, double initialWinRate, double initialProfitFactor) {
   m_useAdaptiveSizing = enable;
   if(enable) {
      m_winRate = MathMin(MathMax(initialWinRate, 0.01), 0.99);
      m_profitFactor = MathMax(initialProfitFactor, 0.1);
      m_tradeCount = 0;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Update trade statistics                                         |
//+------------------------------------------------------------------+
void CPositionManager::UpdateTradeStats(bool isWin, double profit) {
   if(!m_useAdaptiveSizing) return;
   
   m_tradeCount++;
   
   // Update win rate
   double winIncrement = (isWin ? 1.0 : 0.0 - m_winRate) / MathMin(m_tradeCount, 100);
   m_winRate = MathMin(MathMax(m_winRate + winIncrement, 0.01), 0.99);
   
   // Update profit factor (simplified)
   static double totalProfit = 0, totalLoss = 0.01; // Avoid division by zero
   if(profit > 0) totalProfit += profit;
   else totalLoss += MathAbs(profit);
   
   m_profitFactor = totalProfit / totalLoss;
}

//+------------------------------------------------------------------+
//| Calculate adaptive position size                                 |
//+------------------------------------------------------------------+
double CPositionManager::CalculateAdaptiveVolume(double baseVolume, double confidence = 1.0) {
   if(!m_useAdaptiveSizing || m_tradeCount < 5) return baseVolume;
   
   // Kelly criterion for position sizing
   double kelly = CalculateKellyCriterion(m_winRate, m_profitFactor);
   
   // Adjust based on confidence
   double adjustedVolume = baseVolume * kelly * confidence;
   
   // Apply limits
   double minVolume = m_symbol.LotsMin();
   double maxVolume = m_symbol.LotsMax();
   
   return MathMin(MathMax(adjustedVolume, minVolume), maxVolume);
}

//+------------------------------------------------------------------+
//| Calculate optimal fraction using Kelly Criterion                 |
//+------------------------------------------------------------------+
double CPositionManager::CalculateKellyCriterion(double winRate, double winLossRatio) {
   // Kelly % = W - [(1 - W) / R]
   // Where: W = Win probability, R = Win/loss ratio
   return winRate - ((1.0 - winRate) / winLossRatio);
}

//+------------------------------------------------------------------+
//| Set trailing drawdown exit                                      |
//+------------------------------------------------------------------+
bool CPositionManager::SetTrailingDrawdown(bool enable, double drawdownPercent) {
   m_useTrailingDrawdown = enable;
   if(enable) {
      m_trailingDrawdown = MathMin(MathMax(drawdownPercent, 1.0), 50.0);
   }
   return true;
}

//+------------------------------------------------------------------+
//| Set volatility-based exit                                       |
//+------------------------------------------------------------------+
bool CPositionManager::SetVolatilityExit(bool enable, double volatilityThreshold) {
   m_useVolatilityExit = enable;
   if(enable) {
      m_volatilityExitLevel = MathMax(volatilityThreshold, 0.5);
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check advanced exit conditions                                  |
//+------------------------------------------------------------------+
bool CPositionManager::CheckAdvancedExitConditions(ulong ticket) {
   if(!m_position.SelectByTicket(ticket)) return false;
   
   // Check trailing drawdown
   if(m_useTrailingDrawdown) {
      double openPrice = m_position.PriceOpen();
      double currentPrice = (m_position.PositionType() == POSITION_TYPE_BUY) ? m_symbol.Bid() : m_symbol.Ask();
      double profit = m_position.Profit() + m_position.Swap() + m_position.Commission();
      
      if(profit > 0) {
         double maxProfit = MathMax(m_position.Profit() + m_position.Swap() + m_position.Commission(), 0.01);
         double currentDrawdown = (maxProfit - profit) / maxProfit * 100.0;
         
         if(currentDrawdown >= m_trailingDrawdown) {
            return ClosePosition(ticket, "Trailing drawdown hit");
         }
      }
   }
   
   // Check volatility exit
   if(m_useVolatilityExit) {
      double atr = iATR(m_symbol.Name(), PERIOD_CURRENT, m_volatilityPeriod, 0);
      double atrPct = (atr / m_symbol.Ask()) * 100.0;
      
      if(atrPct >= m_volatilityExitLevel) {
         return ClosePosition(ticket, "High volatility exit");
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Set position clustering                                         |
//+------------------------------------------------------------------+
bool CPositionManager::SetPositionClustering(bool enable, double clusterDistance, int maxClusters) {
   m_usePositionClustering = enable;
   if(enable) {
      m_clusterDistance = MathMax(clusterDistance, 1.0) * m_symbol.Point() * 10; // Convert pips to points
      m_maxClusters = MathMax(maxClusters, 1);
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check if price is in existing cluster                           |
//+------------------------------------------------------------------+
bool CPositionManager::IsInExistingCluster(const string symbol, double price, ENUM_POSITION_TYPE type) {
   if(!m_usePositionClustering) return false;
   
   // This is a simplified implementation
   // In a real system, you'd track clusters more precisely
   
   for(int i = 0; i < PositionsTotal(); i++) {
      if(m_position.SelectByIndex(i) && m_position.Symbol() == symbol && 
         m_position.PositionType() == type) {
         double distance = MathAbs(m_position.PriceOpen() - price) / (m_symbol.Point() * 10);
         if(distance <= m_clusterDistance) {
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Set machine learning integration                                |
//+------------------------------------------------------------------+
bool CPositionManager::SetMLIntegration(bool enable, double confidenceThreshold) {
   m_useMLPredictions = enable;
   if(enable) {
      m_mlConfidenceThreshold = MathMin(MathMax(confidenceThreshold, 0.5), 0.95);
   }
   return true;
}

//+------------------------------------------------------------------+
//| Get ML prediction for symbol/timeframe                          |
//+------------------------------------------------------------------+
double CPositionManager::GetMLPrediction(const string symbol, ENUM_TIMEFRAMES timeframe) {
   if(!m_useMLPredictions) return 0.0;
   
   // This is a placeholder - implement actual ML prediction
   // Return values: >0 for buy, <0 for sell, magnitude = confidence
   
   return 0.0; // No prediction available
}

//+------------------------------------------------------------------+
//| Set market regime filter                                        |
//+------------------------------------------------------------------+
bool CPositionManager::SetRegimeFilter(bool enable, int period, double trendThreshold, double rangeThreshold) {
   m_useRegimeFilter = enable;
   if(enable) {
      m_regimePeriod = MathMax(period, 10);
      m_trendThreshold = MathMin(MathMax(trendThreshold, 0.1), 0.5);
      m_rangeThreshold = MathMin(MathMax(rangeThreshold, 0.05), 0.3);
   }
   return true;
}

//+------------------------------------------------------------------+
//| Detect current market regime                                    |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME CPositionManager::DetectMarketRegime() {
   if(!m_useRegimeFilter) return REGIME_TRENDING;
   
   // Calculate ADX for trend strength
   double adx = iADX(m_symbol.Name(), PERIOD_CURRENT, m_regimePeriod, PRICE_CLOSE, MODE_MAIN, 0);
   
   // Calculate ATR for volatility
   double atr = iATR(m_symbol.Name(), PERIOD_CURRENT, m_regimePeriod, 0);
   double atrPct = (atr / m_symbol.Ask()) * 100.0;
   
   // Determine regime
   if(adx > 25) {
      return REGIME_TRENDING;
   } else if(atrPct > m_rangeThreshold * 2) {
      return REGIME_VOLATILE;
   } else {
      return REGIME_RANGING;
   }
}

//+------------------------------------------------------------------+
//| Check if position type is favorable for current regime          |
//+------------------------------------------------------------------+
bool CPositionManager::IsFavorableRegime(ENUM_POSITION_TYPE type, ENUM_MARKET_REGIME regime) {
   if(!m_useRegimeFilter) return true;
   
   // This is a simplified implementation
   switch(regime) {
      case REGIME_TRENDING:
         return true; // All positions okay in trends
      case REGIME_RANGING:
         return false; // Avoid new positions in ranging markets
      case REGIME_VOLATILE:
         return (type == POSITION_TYPE_BUY); // Prefer long in high volatility
      default:
         return true;
   }
}

//+------------------------------------------------------------------+
//| Calculate position score based on multiple factors              |
//+------------------------------------------------------------------+
double CPositionManager::CalculatePositionScore(const string symbol, ENUM_POSITION_TYPE type) {
   double score = 0.0;
   
   // 1. Trend strength (higher is better)
   double adx = iADX(symbol, PERIOD_CURRENT, 14, PRICE_CLOSE, MODE_MAIN, 0);
   score += NormalizeDouble(adx / 50.0, 2); // Normalize to 0-1 range
   
   // 2. Volatility (moderate is best)
   double atr = iATR(symbol, PERIOD_CURRENT, 14, 0);
   double atrPct = (atr / SymbolInfoDouble(symbol, SYMBOL_ASK)) * 100.0;
   score += 1.0 - MathAbs(0.5 - MathMin(atrPct, 1.0)); // Best at 0.5% ATR
   
   // 3. Volume (higher is better)
   double volume[];
   if(CopyTickVolume(symbol, PERIOD_CURRENT, 0, 5, volume) == 5) {
      double avgVolume = (volume[0] + volume[1] + volume[2] + volume[3] + volume[4]) / 5.0;
      score += MathMin(avgVolume / 1000.0, 1.0); // Normalize
   }
   
   // 4. ML prediction (if available)
   if(m_useMLPredictions) {
      double mlSignal = GetMLPrediction(symbol, PERIOD_CURRENT);
      if((type == POSITION_TYPE_BUY && mlSignal > 0) || 
         (type == POSITION_TYPE_SELL && mlSignal < 0)) {
         score += MathAbs(mlSignal);
      }
   }
   
   // 5. Market regime
   ENUM_MARKET_REGIME regime = DetectMarketRegime();
   if(IsFavorableRegime(type, regime)) {
      score += 0.5;
   }
   
   return NormalizeDouble(score, 2);
}

//+------------------------------------------------------------------+
//| Place bracket order with advanced features                      |
//+------------------------------------------------------------------+
bool CPositionManager::PlaceBracketOrder(const string symbol, ENUM_ORDER_TYPE type, double volume, 
                                       double entryPrice, double sl, double tp, double breakEvenAt, 
                                       double trailingStop, datetime expiration, const string comment) {
   // Implement bracket order logic
   // This would include entry order, stop loss, take profit, and optional break-even/trailing
   
   // Placeholder implementation
   return OpenPosition(symbol, (type == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL, 
                      volume, entryPrice, sl, tp, comment);
}

//+------------------------------------------------------------------+
//| Place OCO (One-Cancels-Other) orders                            |
//+------------------------------------------------------------------+
bool CPositionManager::PlaceOCOOrders(const string symbol, ENUM_ORDER_TYPE type, double volume, 
                                    double price1, double price2, double sl, double tp, const string comment) {
   // Implement OCO order logic
   // This would place two orders where if one is filled, the other is cancelled
   
   // Placeholder implementation
   return OpenPosition(symbol, (type == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL, 
                      volume, (type == ORDER_TYPE_BUY) ? price1 : price2, sl, tp, comment + " OCO");
}

//+------------------------------------------------------------------+
//| Monitor position and apply advanced management                  |
//+------------------------------------------------------------------+
bool CPositionManager::MonitorPosition(ulong ticket) {
   if(!m_position.SelectByTicket(ticket)) return false;
   
   // Update position statistics
   UpdatePositionStats(ticket);
   
   // Check if position needs adjustment
   if(NeedsAdjustment(ticket)) {
      // Apply adjustments (trailing stop, take profit, etc.)
      return true;
   }
   
   // Check advanced exit conditions
   return CheckAdvancedExitConditions(ticket);
}

//+------------------------------------------------------------------+
//| Update position statistics                                      |
//+------------------------------------------------------------------+
void CPositionManager::UpdatePositionStats(ulong ticket) {
   // Update statistics like time in trade, drawdown, etc.
   // This would be called periodically for each open position
}

//+------------------------------------------------------------------+
//| Check if position needs adjustment                              |
//+------------------------------------------------------------------+
bool CPositionManager::NeedsAdjustment(ulong ticket) {
   // Check if position needs any adjustments
   // (e.g., moving stop to break-even, trailing stop, etc.)
   return false;
}

//+------------------------------------------------------------------+
//| Check for volatility spikes                                     |
//+------------------------------------------------------------------+
bool CPositionManager::CheckVolatilitySpike() {
   // Check if current volatility is significantly higher than average
   double currentAtr = iATR(m_symbol.Name(), PERIOD_CURRENT, 14, 0);
   double avgAtr = iATR(m_symbol.Name(), PERIOD_CURRENT, 100, 0);
   
   return (currentAtr > avgAtr * 2.0); // 2x average volatility
}

//+------------------------------------------------------------------+
//| Check market liquidity                                          |
//+------------------------------------------------------------------+
bool CPositionManager::CheckLiquidity(const string symbol) {
   // Check if there's sufficient liquidity for the trade
   // This is a simplified check
   
   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * m_symbol.Point();
   double avgSpread = iATR(symbol, PERIOD_CURRENT, 100, 0) / 10.0; // Simplified
   
   return (spread <= avgSpread * 2.0); // Allow up to 2x average spread
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                   |
//+------------------------------------------------------------------+
bool CPositionManager::CheckMarketHours() {
   // Check if current time is within allowed trading hours
   // This is a placeholder - implement based on your trading strategy
   
   MqlDateTime time;
   TimeToStruct(TimeCurrent(), time);
   
   // Example: Only trade during main session hours (8 AM to 4 PM server time)
   return (time.hour >= 8 && time.hour < 16);
}

//+------------------------------------------------------------------+
//| Set scaling profile                                             |
//+------------------------------------------------------------------+
bool CPositionManager::SetScalingProfile(ENUM_SCALING_PROFILE profile) {
   switch(profile) {
      case SCALING_AGGRESSIVE:
         m_scaleInFactor = 1.5;
         m_scaleOutFactor = 0.5;
         m_scaleInAt = 0.5;  // Scale in at 0.5R drawdown
         m_scaleOutAt = 1.5; // Scale out at 1.5R profit
         break;
         
      case SCALING_MODERATE:
         m_scaleInFactor = 1.2;
         m_scaleOutFactor = 0.7;
         m_scaleInAt = 0.7;
         m_scaleOutAt = 2.0;
         break;
         
      case SCALING_CONSERVATIVE:
         m_scaleInFactor = 1.0;
         m_scaleOutFactor = 1.0;
         m_scaleInAt = 1.0;
         m_scaleOutAt = 3.0;
         break;
         
      default:
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate optimal scale-in volume                                |
//+------------------------------------------------------------------+
double CPositionManager::CalculateOptimalScaleInVolume(double baseVolume, int scaleLevel, double drawdownPct) {
   if(scaleLevel <= 0) return 0.0;
   
   // Reduce volume as drawdown increases
   double drawdownFactor = 1.0 - (drawdownPct / 100.0);
   drawdownFactor = MathMax(drawdownFactor, 0.1); // Minimum 10% of base volume
   
   // Scale volume based on level and drawdown
   double scaleFactor = MathPow(m_scaleInFactor, scaleLevel) * drawdownFactor;
   
   // Apply position limits
   double minVolume = m_symbol.LotsMin();
   double maxVolume = m_symbol.LotsMax();
   double stepVolume = m_symbol.LotsStep();
   
   double volume = baseVolume * scaleFactor;
   volume = MathFloor(volume / stepVolume) * stepVolume;
   
   return MathMin(MathMax(volume, minVolume), maxVolume);
}

//+------------------------------------------------------------------+
//| Check for scaling opportunities                                 |
//+------------------------------------------------------------------+
bool CPositionManager::CheckScalingOpportunity(ulong ticket, double &volume) {
   if(!m_position.SelectByTicket(ticket)) return false;
   
   double currentPrice = (m_position.PositionType() == POSITION_TYPE_BUY) ? m_symbol.Bid() : m_symbol.Ask();
   double openPrice = m_position.PriceOpen();
   double sl = m_position.StopLoss();
   double tp = m_position.TakeProfit();
   
   if(sl == 0.0 || tp == 0.0) return false; // No scaling without proper stops
   
   // Calculate price movement in pips
   double priceDiff = (currentPrice - openPrice) / m_symbol.Point();
   if(m_position.PositionType() == POSITION_TYPE_SELL) priceDiff = -priceDiff;
   
   // Check if we should scale in
   if(priceDiff <= -m_scaleInAt * 10) { // Convert to pips
      int scaleLevel = (int)(-priceDiff / (m_scaleInAt * 10));
      double drawdownPct = MathAbs(priceDiff / ((openPrice - sl) / m_symbol.Point())) * 100.0;
      
      volume = CalculateOptimalScaleInVolume(m_position.Volume(), scaleLevel, drawdownPct);
      return (volume > 0);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Scale into a position                                           |
//+------------------------------------------------------------------+
bool CPositionManager::ScaleInPosition(ulong ticket, double volume) {
   if(!m_position.SelectByTicket(ticket)) return false;
   
   string symbol = m_position.Symbol();
   ENUM_POSITION_TYPE type = m_position.PositionType();
   double openPrice = (type == POSITION_TYPE_BUY) ? m_symbol.Ask() : m_symbol.Bid();
   
   // Calculate new average price and position size
   double currentVolume = m_position.Volume();
   double currentPrice = m_position.PriceOpen();
   double newVolume = currentVolume + volume;
   double newPrice = (currentPrice * currentVolume + openPrice * volume) / newVolume;
   
   // Close existing position
   if(!ClosePosition(ticket, "Scaling in")) return false;
   
   // Open new position with updated size and price
   return OpenPosition(symbol, type, newVolume, newPrice, m_position.StopLoss(), 
                      m_position.TakeProfit(), m_position.Comment() + " Scaled In");
}

//+------------------------------------------------------------------+
//| Scale out of a position                                         |
//+------------------------------------------------------------------+
bool CPositionManager::ScaleOutPosition(ulong ticket, double volume) {
   if(!m_position.SelectByTicket(ticket)) return false;
   
   double currentVolume = m_position.Volume();
   if(volume >= currentVolume) return ClosePosition(ticket, "Full close");
   
   // Close partial position
   if(!ClosePartial(ticket, volume, "Scale out")) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Set exit profile                                                |
//+------------------------------------------------------------------+
bool CPositionManager::SetExitProfile(ENUM_EXIT_PROFILE profile) {
   switch(profile) {
      case EXIT_AGGRESSIVE:
         m_trailingStop = 20;  // 20 pips trailing stop
         m_breakEvenAt = 15;   // Move to breakeven at 15 pips
         m_useTimeExit = true;
         m_maxHoldBars = 50;   // Close after 50 bars
         break;
         
      case EXIT_MODERATE:
         m_trailingStop = 30;
         m_breakEvenAt = 20;
         m_useTimeExit = true;
         m_maxHoldBars = 100;
         break;
         
      case EXIT_CONSERVATIVE:
         m_trailingStop = 50;
         m_breakEvenAt = 30;
         m_useTimeExit = false;
         m_maxHoldBars = 0;    // No time-based exit
         break;
         
      default:
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check exit conditions                                           |
//+------------------------------------------------------------------+
bool CPositionManager::CheckExitConditions(ulong ticket, double &closePrice, string &reason) {
   if(!m_position.SelectByTicket(ticket)) return false;
   
   // Check standard exit conditions
   if(CheckAdvancedExitConditions(ticket)) {
      reason = "Advanced exit condition";
      return true;
   }
   
   // Check time-based exit
   if(m_useTimeExit && UseTimeExit(ticket, m_position.Time())) {
      reason = "Time-based exit";
      return true;
   }
   
   // Check volatility-based exit
   if(m_useVolatilityExit) {
      double atr = iATR(m_symbol.Name(), PERIOD_CURRENT, m_volatilityPeriod, 0);
      double atrPct = (atr / m_symbol.Ask()) * 100.0;
      
      if(atrPct >= m_volatilityExitLevel) {
         reason = "High volatility exit";
         return true;
      }
   }
   
   // Check pyramiding exit
   double closeVolume = 0.0;
   if(UsePyramidingExit(ticket, closeVolume)) {
      reason = "Pyramiding exit";
      closePrice = (m_position.PositionType() == POSITION_TYPE_BUY) ? m_symbol.Bid() : m_symbol.Ask();
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Use pyramiding exit strategy                                    |
//+------------------------------------------------------------------+
bool CPositionManager::UsePyramidingExit(ulong ticket, double &closeVolume) {
   if(!m_position.SelectByTicket(ticket)) return false;
   
   // Get all positions for this symbol
   int totalPositions = 0;
   double totalVolume = 0.0;
   double totalProfit = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i) && m_position.Symbol() == m_symbol.Name() && 
         m_position.PositionType() == m_position.PositionType()) {
         totalPositions++;
         totalVolume += m_position.Volume();
         totalProfit += m_position.Profit() + m_position.Swap() + m_position.Commission();
      }
   }
   
   // If we have multiple positions and the total profit is positive, consider closing some
   if(totalPositions > 1 && totalProfit > 0) {
      // Close 50% of the smallest positions
      closeVolume = totalVolume * 0.5;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if time-based exit is needed                              |
//+------------------------------------------------------------------+
bool CPositionManager::UseTimeExit(ulong ticket, datetime openTime) {
   if(!m_useTimeExit || m_maxHoldBars <= 0) return false;
   
   datetime currentTime = TimeCurrent();
   int barsHeld = iBarShift(m_symbol.Name(), PERIOD_CURRENT, openTime, true);
   
   return (barsHeld >= m_maxHoldBars);
}

//+------------------------------------------------------------------+
//| Check if volatility-based exit is needed                        |
//+------------------------------------------------------------------+
bool CPositionManager::UseVolatilityExit(ulong ticket, double currentVolatility) {
   if(!m_useVolatilityExit) return false;
   
   double atr = iATR(m_symbol.Name(), PERIOD_CURRENT, m_volatilityPeriod, 0);
   double atrPct = (atr / m_symbol.Ask()) * 100.0;
   
   return (atrPct >= m_volatilityExitLevel);
}

//+------------------------------------------------------------------+
//| Calculate correlation-adjusted volume                           |
//+------------------------------------------------------------------+
double CPositionManager::CalculateCorrelationAdjustedVolume(const string symbol, double baseVolume) {
   if(!m_initialized) return baseVolume;
   
   // Get correlation with existing portfolio
   double correlation = GetPortfolioCorrelation(symbol);
   
   // Reduce position size for highly correlated positions
   if(correlation > 0.7) {
      return baseVolume * (1.0 - (correlation - 0.7) * 0.5);
   }
   
   return baseVolume;
}

//+------------------------------------------------------------------+
//| Get portfolio correlation for a symbol                          |
//+------------------------------------------------------------------+
double CPositionManager::GetPortfolioCorrelation(const string symbol) {
   if(PositionsTotal() == 0) return 0.0;
   
   double totalCorrelation = 0.0;
   int count = 0;
   
   // Calculate average correlation with existing positions
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(m_position.SelectByIndex(i)) {
         string posSymbol = m_position.Symbol();
         if(posSymbol != symbol) {
            double corr = GetMarketCorrelation(symbol, posSymbol);
            totalCorrelation += MathAbs(corr);
            count++;
         }
      }
   }
   
   return (count > 0) ? (totalCorrelation / count) : 0.0;
}

//+------------------------------------------------------------------+
//| Get market correlation between two symbols                      |
//+------------------------------------------------------------------+
double CPositionManager::GetMarketCorrelation(const string symbol1, const string symbol2, int period = 100) {
   if(symbol1 == symbol2) return 1.0;
   
   // Get close prices for both symbols
   double prices1[], prices2[];
   ArraySetAsSeries(prices1, true);
   ArraySetAsSeries(prices2, true);
   
   if(CopyClose(symbol1, PERIOD_CURRENT, 0, period, prices1) != period ||
      CopyClose(symbol2, PERIOD_CURRENT, 0, period, prices2) != period) {
      Print("Error getting price data for correlation");
      return 0.0;
   }
   
   // Calculate correlation coefficient
   return MathCorrelation(prices1, prices2, period);
}

//+------------------------------------------------------------------+
//| Load machine learning model                                     |
//+------------------------------------------------------------------+
bool CPositionManager::LoadMLModel(const string modelFile) {
   // Placeholder for ML model loading
   // In a real implementation, this would load a pre-trained model
   
   Print("Loading ML model: ", modelFile);
   return true;
}

//+------------------------------------------------------------------+
//| Get ML-based position score                                     |
//+------------------------------------------------------------------+
double CPositionManager::GetMLPositionScore(const string symbol, ENUM_POSITION_TYPE type) {
   if(!m_useMLPredictions) return 0.0;
   
   // Placeholder for ML prediction
   // In a real implementation, this would use the loaded model to predict
   
   // Return a random score for demonstration
   return MathRand() / 32767.0;
}

//+------------------------------------------------------------------+
//| Update ML model with new data                                   |
//+------------------------------------------------------------------+
bool CPositionManager::UpdateMLModel(const MqlRates &rates[], const double &features[]) {
   if(!m_useMLPredictions) return false;
   
   // Placeholder for model updating
   // In a real implementation, this would update the model with new data
   
   return true;
}

//+------------------------------------------------------------------+
//| Update position manager state                                    |
//+------------------------------------------------------------------+
void CPositionManager::Update() {
   // Update trailing stops if enabled
   if(m_trailingStop > 0) {
      CheckTrailingStop();
   }
   
   // Update break-even if enabled
   if(m_autoBreakEven) {
      for(int i = 0; i < PositionsTotal(); i++) {
         if(m_position.SelectByIndex(i)) {
            double profit = m_position.Profit() + m_position.Swap() + m_position.Commission();
            double openPrice = m_position.PriceOpen();
            double currentPrice = (m_position.PositionType() == POSITION_TYPE_BUY) ? m_symbol.Bid() : m_symbol.Ask();
            
            // Check if we should move to break-even
            if((m_position.PositionType() == POSITION_TYPE_BUY && 
                currentPrice - openPrice >= m_breakEvenAt) ||
               (m_position.PositionType() == POSITION_TYPE_SELL && 
                openPrice - currentPrice >= m_breakEvenAt)) {
               MoveToBreakEven(m_position.Ticket());
            }
         }
      }
   }
   
   // Check time-based exits
   if(m_useTimeExit) {
      datetime currentTime = TimeCurrent();
      
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         if(m_position.SelectByIndex(i)) {
            // Check position age in bars if enabled
            if(m_maxHoldBars > 0) {
               int barsHeld = (int)((currentTime - m_position.Time()) / PeriodSeconds(PERIOD_CURRENT));
               if(barsHeld >= m_maxHoldBars) {
                  ClosePosition(m_position.Ticket(), "Max hold time reached");
                  continue;
               }
            }
            
            // Check expiry time if set
            if(m_expiryTime > 0 && currentTime >= m_expiryTime) {
               ClosePosition(m_position.Ticket(), "Position expired");
            }
         }
      }
   }
   
   // Check scaling opportunities
   if(m_scaleIn || m_scaleOut) {
      for(int i = 0; i < PositionsTotal(); i++) {
         if(m_position.SelectByIndex(i)) {
            double openPrice = m_position.PriceOpen();
            double currentPrice = (m_position.PositionType() == POSITION_TYPE_BUY) ? m_symbol.Bid() : m_symbol.Ask();
            double priceDiff = MathAbs(currentPrice - openPrice);
            
            // Check for scale-in opportunities
            if(m_scaleIn && priceDiff >= m_scaleInAt) {
               ScaleInPosition(m_position.Ticket());
            }
            
            // Check for scale-out opportunities
            if(m_scaleOut && priceDiff >= m_scaleOutAt) {
               ScaleOutPosition(m_position.Ticket());
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
