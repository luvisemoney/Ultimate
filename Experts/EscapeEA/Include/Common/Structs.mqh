//+------------------------------------------------------------------+
//| Structs.mqh - Common structures for EscapeEA                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "Enums.mqh"
#include "Constants.mqh"

//+------------------------------------------------------------------+
//| Trade record structure                                           |
//+------------------------------------------------------------------+
struct STradeRecord
  {
   ulong               ticket;           // Trade ticket
   datetime            openTime;         // Open time
   datetime            closeTime;        // Close time (0 for open positions)
   string              symbol;           // Symbol
   double              openPrice;        // Open price
   double              closePrice;       // Close price
   double              stopLoss;         // Stop loss level
   double              takeProfit;       // Take profit level
   double              lots;             // Trade volume
   double              profit;           // Profit/loss
   double              swap;             // Swap value
   double              commission;       // Commission
   ENUM_TRADE_SIGNAL   signal;           // Trade signal
   ENUM_TRADE_TYPE     type;             // Trade type
   bool                isLive;           // True for live trades
   double              confidence;       // Signal confidence (0-1)
   string              comment;          // Trade comment
   
   // Default constructor
   STradeRecord() : ticket(0), openTime(0), closeTime(0), openPrice(0.0), closePrice(0.0),
                    stopLoss(0.0), takeProfit(0.0), lots(0.0), profit(0.0), swap(0.0),
                    commission(0.0), signal(SIGNAL_HOLD), type(TRADE_TYPE_BUY), isLive(false),
                    confidence(0.0) {}
  };

//+------------------------------------------------------------------+
//| Trading statistics structure                                     |
//+------------------------------------------------------------------+
struct STradingStats
  {
   int               totalTrades;        // Total number of trades
   int               winningTrades;      // Number of winning trades
   int               losingTrades;       // Number of losing trades
   double            totalProfit;        // Total profit
   double            totalLoss;          // Total loss
   double            winRate;            // Win rate percentage
   double            profitFactor;       // Profit factor
   double            maxDrawdown;        // Maximum drawdown percentage
   double            maxProfit;          // Maximum profit achieved
   double            averageWin;         // Average win amount
   double            averageLoss;        // Average loss amount
   double            recoveryFactor;     // Recovery factor
   int               consecutiveWins;    // Current consecutive wins
   int               consecutiveLosses;  // Current consecutive losses
   
   // Default constructor
   STradingStats() : totalTrades(0), winningTrades(0), losingTrades(0), totalProfit(0.0),
                    totalLoss(0.0), winRate(0.0), profitFactor(0.0), maxDrawdown(0.0),
                    maxProfit(0.0), averageWin(0.0), averageLoss(0.0), recoveryFactor(0.0),
                    consecutiveWins(0), consecutiveLosses(0) {}
   
   // Calculate statistics from trade history
   void Calculate(const STradeRecord &trades[])
     {
      // Implementation will be added in the next step
     }
  };

//+------------------------------------------------------------------+
//| Market condition structure                                       |
//+------------------------------------------------------------------+
struct SMarketCondition
  {
   ENUM_MARKET_CONDITION condition;  // Current market condition
   double                confidence; // Confidence level (0-1)
   string                symbol;     // Symbol
   ENUM_TIMEFRAMES       timeframe;  // Timeframe
   datetime              timestamp;  // Time of analysis
   
   // Default constructor
   SMarketCondition() : condition(MARKET_NORMAL), confidence(0.0), symbol(""), 
                       timeframe(PERIOD_CURRENT), timestamp(0) {}
  };

//+------------------------------------------------------------------+
//| Market state structure                                          |
//+------------------------------------------------------------------+
struct SMarketState
  {
   datetime         timestamp;    // Timestamp of the market state
   double           spread;       // Current spread in points
   double           volume;       // Current tick volume
   double           bid;          // Current bid price
   double           ask;          // Current ask price
   
   // Default constructor
   SMarketState() : timestamp(0), spread(0.0), volume(0.0), bid(0.0), ask(0.0) {}
  };

//+------------------------------------------------------------------+
//| Volatility data structure                                       |
//+------------------------------------------------------------------+
struct SVolatilityData
  {
   datetime         timestamp;    // Timestamp of the volatility data
   double           atr;          // Average True Range value
   double           stdDev;       // Standard deviation
   double           range;        // Price range (high - low)
   
   // Default constructor
   SVolatilityData() : timestamp(0), atr(0.0), stdDev(0.0), range(0.0) {}
  };

//+------------------------------------------------------------------+
//| Signal structure                                                 |
//+------------------------------------------------------------------+
struct STradeSignal
  {
   int                 version;      // Signal protocol version
   ENUM_TRADE_SIGNAL   signal;       // Trade signal
   double              confidence;   // Signal confidence (0-1)
   string              symbol;       // Symbol
   ENUM_TIMEFRAMES     timeframe;    // Timeframe
   datetime            timestamp;    // Signal generation time
   double              entry;        // Suggested entry price
   double              stopLoss;     // Suggested stop loss
   double              takeProfit;   // Suggested take profit
   double              riskReward;   // Risk/reward ratio
   string              comment;      // Signal comment
   
   // Default constructor
   STradeSignal() : 
      version(SIGNAL_PROTOCOL_VERSION),
      signal(SIGNAL_HOLD), 
      confidence(0.0), 
      symbol(""), 
      timeframe(PERIOD_CURRENT), 
      timestamp(0), 
      entry(0.0),
      stopLoss(0.0), 
      takeProfit(0.0), 
      riskReward(0.0) {}
   
   // Copy constructor
   STradeSignal(const STradeSignal &other) :
      version(other.version),
      signal(other.signal),
      confidence(other.confidence),
      symbol(other.symbol),
      timeframe(other.timeframe),
      timestamp(other.timestamp),
      entry(other.entry),
      stopLoss(other.stopLoss),
      takeProfit(other.takeProfit),
      riskReward(other.riskReward),
      comment(other.comment) {}
  };

//+------------------------------------------------------------------+
//| Learning parameters structure                                    |
//+------------------------------------------------------------------+
struct SLearningParams
  {
   int               windowSize;     // Learning window size
   double            minConfidence;  // Minimum confidence threshold
   double            learningRate;   // Learning rate
   int               maxIterations;  // Maximum iterations
   bool              enabled;        // Learning enabled
   
   // Default constructor
   SLearningParams() : windowSize(20), minConfidence(0.7), 
                      learningRate(0.01), maxIterations(1000), enabled(true) {}
  };

//+------------------------------------------------------------------+
//| Position information structure                                   |
//+------------------------------------------------------------------+
struct SPositionInfo
  {
   ulong             ticket;         // Position ticket
   string            symbol;         // Position symbol
   double            volume;         // Position volume
   double            priceOpen;      // Position open price
   double            stopLoss;       // Stop loss level
   double            takeProfit;     // Take profit level
   datetime          time;           // Position open time
   ENUM_POSITION_TYPE type;          // Position type
   double            profit;         // Current profit
   string            comment;        // Position comment
   
   // Default constructor
   SPositionInfo() : ticket(0), symbol(""), volume(0.0), priceOpen(0.0),
                    stopLoss(0.0), takeProfit(0.0), time(0), 
                    type(POSITION_TYPE_BUY), profit(0.0) {}
  };
