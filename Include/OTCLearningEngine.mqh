//+------------------------------------------------------------------+
//|                                              OTCLearningEngine.mqh |
//|                                  Copyright 2025, Your Company Name |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property strict

// Include necessary standard libraries
#include <Object.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Files\File.mqh>

// Include our custom types and market analysis
#include "OTCTypes.mqh"

// Forward declarations
class CMarketAnalysis;

//--- Constants for learning parameters
#define MAX_TRADES_TO_ANALYZE  1000  // Maximum number of trades to analyze
#define MIN_TRADES_FOR_ANALYSIS 10   // Minimum trades before making adjustments
#define MAX_ADJUSTMENT_PCT     10.0  // Maximum percentage to adjust parameters

//+------------------------------------------------------------------+
//| Learning Engine Class                                            |
//+------------------------------------------------------------------+
class CLearningEngine
{
private:
   CArrayObj    *m_trade_history;  // History of all trades
   string       m_data_path;       // Path to store learning data
   double       m_win_rate;        // Current win rate
   double       m_avg_win;         // Average win amount
   double       m_avg_loss;        // Average loss amount
   double       m_profit_factor;   // Profit factor
   double       m_max_drawdown;    // Maximum drawdown
   int          m_total_trades;    // Total number of trades
   int          m_winning_trades;  // Number of winning trades
   int          m_losing_trades;   // Number of losing trades
   
   //--- Learning parameters
   double       m_learning_rate;   // How quickly to adapt to new information
   
   //--- Market condition parameters
   struct SMetricStats
   {
      double     avg_volatility;
      double     avg_spread;
      double     avg_trend_strength;
      int        sample_count;
   } m_win_metrics, m_loss_metrics;
   
   //--- Parameter optimization
   struct SParamStats
   {
      double     best_tp;
      double     best_sl;
      double     best_ma_fast;
      double     best_ma_slow;
   } m_param_stats;
   
public:
   //--- Constructor
   CLearningEngine()
   {
      // Initialize member variables
      m_trade_history = new CArrayObj();
      m_win_rate = 0.0;
      m_avg_win = 0.0;
      m_avg_loss = 0.0;
      m_profit_factor = 1.0;
      m_max_drawdown = 0.0;
      m_total_trades = 0;
      m_winning_trades = 0;
      m_losing_trades = 0;
      m_learning_rate = 0.1;  // Default learning rate
      
      // Set up data path
      m_data_path = "OTCEscape\\";
      if(!FolderCreate(m_data_path, FILE_COMMON))
      {
         Print("Warning: Failed to create data directory: ", m_data_path, ". Error: ", GetLastError());
      }
      
      // Load any existing trade history
      LoadTradeHistory();
   }
   
   //--- Destructor
   ~CLearningEngine()
   {
      // Save trade history before destruction
      SaveTradeHistory();
      
      // Clean up trade history
      if(CheckPointer(m_trade_history) == POINTER_DYNAMIC)
      {
         // Delete all trade objects in the array
         for(int i = m_trade_history.Total() - 1; i >= 0; i--)
         {
            CObject* obj = m_trade_history.At(i);
            if(CheckPointer(obj) == POINTER_DYNAMIC)
            {
               STradeRecord* trade = dynamic_cast<STradeRecord*>(obj);
               if(CheckPointer(trade) == POINTER_DYNAMIC)
                  delete trade;
            }
         }
         
         m_trade_history.Clear();
         delete m_trade_history;
      }
   }
   
   //--- Calculate performance metrics
   void CalculateMetrics()
   {
      int total = m_trade_history.Total();
      if(total == 0)
      {
         ResetMetrics();
         return;
      }
      
      double total_profit = 0.0;
      double total_loss = 0.0;
      double max_drawdown = 0.0;
      double peak = 0.0;
      double current_equity = 0.0;
      
      m_winning_trades = 0;
      m_losing_trades = 0;
      
      // Calculate metrics from trade history
      for(int i = 0; i < total; i++)
      {
         CObject* obj = m_trade_history.At(i);
         if(CheckPointer(obj) != POINTER_DYNAMIC)
            continue;
            
         STradeRecord* trade = dynamic_cast<STradeRecord*>(obj);
         if(CheckPointer(trade) != POINTER_DYNAMIC)
            continue;
            
         if(trade.is_winner)
         {
            m_winning_trades++;
            total_profit += trade.profit;
         }
         else
         {
            m_losing_trades++;
            total_loss += MathAbs(trade.profit);
         }
         
         // Update drawdown
         current_equity += trade.profit;
         if(current_equity > peak)
            peak = current_equity;
            
         double drawdown = peak - current_equity;
         if(drawdown > max_drawdown)
            max_drawdown = drawdown;
      }
      
      // Calculate final metrics
      m_total_trades = total;
      m_win_rate = (total > 0) ? (double)m_winning_trades / total : 0.0;
      m_avg_win = (m_winning_trades > 0) ? total_profit / m_winning_trades : 0.0;
      m_avg_loss = (m_losing_trades > 0) ? total_loss / m_losing_trades : 0.0;
      m_profit_factor = (total_loss > 0) ? total_profit / total_loss : (total_profit > 0) ? 100.0 : 1.0;
      m_max_drawdown = max_drawdown;
   }
   
   //--- Reset all metrics
   void ResetMetrics()
   {
      m_win_rate = 0.0;
      m_avg_win = 0.0;
      m_avg_loss = 0.0;
      m_profit_factor = 0.0;
      m_total_trades = 0;
      m_winning_trades = 0;
      m_losing_trades = 0;
      m_max_drawdown = 0.0;
      
      // Reset market condition metrics
      ZeroMemory(m_win_metrics);
      ZeroMemory(m_loss_metrics);
      
      // Reset parameter stats
      m_param_stats.best_tp = 40.0;
      m_param_stats.best_sl = 30.0;
      m_param_stats.best_ma_fast = 5.0;
      m_param_stats.best_ma_slow = 10.0;
   }
   
   //--- Add a new trade to history
   void AddTrade(const STradeRecord &trade)
   {
      // Create a new trade object on the heap
      STradeRecord *new_trade = new STradeRecord();
      if(CheckPointer(new_trade) != POINTER_DYNAMIC)
      {
         Print("Failed to allocate memory for new trade record");
         return;
      }
      
      // Cast to CObject pointer for storage in CArrayObj
      CObject *obj = dynamic_cast<CObject*>(new_trade);
      if(CheckPointer(obj) != POINTER_DYNAMIC)
      {
         delete new_trade;
         Print("Failed to cast trade record to CObject");
         return;
      }
      
      // Copy all fields manually
      new_trade.entry_time = trade.entry_time;
      new_trade.exit_time = trade.exit_time;
      new_trade.entry_price = trade.entry_price;
      new_trade.exit_price = trade.exit_price;
      new_trade.profit = trade.profit;
      new_trade.lot_size = trade.lot_size;
      new_trade.hold_time = trade.hold_time;
      new_trade.spread = trade.spread;
      new_trade.volatility = trade.volatility;
      new_trade.trend_strength = trade.trend_strength;
      new_trade.is_winner = trade.is_winner;
      
      // Add the pointer to the array (CArrayObj takes ownership of the pointer)
      if(!m_trade_history.Add(obj))
      {
         delete new_trade;
         Print("Failed to add trade to history");
         return;
      }
      
      // Recalculate metrics
      CalculateMetrics();
   }
   
   //--- Update performance metrics
   void UpdateMetrics(STradeRecord *trade)
   {
      if(CheckPointer(trade) != POINTER_DYNAMIC)
      {
         Print("Invalid trade pointer in UpdateMetrics");
         return;
      }
      
      // Update basic metrics
      m_total_trades++;
      
      // Update win/loss metrics
      if(trade.is_winner)
      {
         m_avg_win = (m_avg_win * (m_total_trades - 1) + trade.profit) / m_total_trades;
         
         // Update winning market condition metrics
         UpdateMarketConditionMetrics(trade, m_win_metrics);
      }
      else
      {
         m_avg_loss = (m_avg_loss * (m_total_trades - 1) + MathAbs(trade.profit)) / m_total_trades;
         
         // Update losing market condition metrics
         UpdateMarketConditionMetrics(trade, m_loss_metrics);
      }
      
      // Update win rate and profit factor
      m_win_rate = (double)CountWinningTrades() / m_total_trades;
      if(m_avg_loss > 0)
         m_profit_factor = m_avg_win / m_avg_loss;
      
      // Update parameter optimization
      UpdateParameterOptimization(trade);
   }
   
   //--- Update market condition metrics
   void UpdateMarketConditionMetrics(STradeRecord *trade, SMetricStats &metrics)
   {
      if(CheckPointer(trade) != POINTER_DYNAMIC)
      {
         Print("Invalid trade pointer in UpdateMarketConditionMetrics");
         return;
      }
      
      metrics.avg_volatility = (metrics.avg_volatility * metrics.sample_count + trade.volatility) / 
                              (metrics.sample_count + 1);
      metrics.avg_spread = (metrics.avg_spread * metrics.sample_count + trade.spread) / 
                          (metrics.sample_count + 1);
      metrics.avg_trend_strength = (metrics.avg_trend_strength * metrics.sample_count + 
                                   trade.trend_strength) / (metrics.sample_count + 1);
      metrics.sample_count++;
   }
   
   //--- Update parameter optimization based on trade results
   void UpdateParameterOptimization(STradeRecord *trade)
   {
      // Simple moving average of parameters based on trade success
      // In a real implementation, you might use more sophisticated methods
      // like reinforcement learning or genetic algorithms
      
      double learning_effect = m_learning_rate * (trade.is_winner ? 1.0 : -0.5);
      
      // Adjust parameters based on trade success
      // This is a simplified example - real implementation would be more sophisticated
      m_param_stats.best_tp *= (1.0 + learning_effect * 0.05);
      m_param_stats.best_sl *= (1.0 + learning_effect * 0.05);
      
      // Ensure parameters stay within reasonable bounds
      m_param_stats.best_tp = MathMax(10, MathMin(200, m_param_stats.best_tp));
      m_param_stats.best_sl = MathMax(5, MathMin(100, m_param_stats.best_sl));
   }
   
   //--- Get optimized parameters
   void GetOptimizedParameters(double &tp, double &sl, double &ma_fast, double &ma_slow)
   {
      tp = m_param_stats.best_tp;
      sl = m_param_stats.best_sl;
      ma_fast = m_param_stats.best_ma_fast;
      ma_slow = m_param_stats.best_ma_slow;
   }
   
   //--- Get trade at specific index
   STradeRecord* GetTradeAt(int index) const
   {
      if(index < 0 || index >= m_trade_history.Total())
         return NULL;
         
      CObject* obj = m_trade_history.At(index);
      if(CheckPointer(obj) != POINTER_DYNAMIC)
         return NULL;
         
      return dynamic_cast<STradeRecord*>(obj);
   }
   
   //--- Get current win rate (0.0 to 1.0)
   double GetWinRate() const
   {
      if(m_total_trades == 0) return 0.0;
      return (double)m_winning_trades / (double)m_total_trades;
   }
   
   //--- Get current profit factor (gross profit / gross loss)
   double GetProfitFactor() const
   {
      if(m_avg_loss == 0.0) return 0.0; // Avoid division by zero
      return (m_avg_win * m_winning_trades) / (m_avg_loss * m_losing_trades);
   }
   
   //--- Get average win amount
   double GetAverageWin() const
   {
      return m_avg_win;
   }
   
   //--- Get average loss amount
   double GetAverageLoss() const
   {
      return m_avg_loss;
   }
   
   //--- Get total number of trades
   int GetTotalTrades() const
   {
      return m_total_trades;
   }
   
   //--- Count winning trades in history
   int CountWinningTrades() const
   {
      int count = 0;
      int total = m_trade_history.Total();
      
      for(int i = 0; i < total; i++)
      {
         // Get the object from the array
         CObject* obj = m_trade_history.At(i);
         if(CheckPointer(obj) != POINTER_DYNAMIC)
            continue;
            
         // Cast to STradeRecord
         STradeRecord* trade = dynamic_cast<STradeRecord*>(obj);
         if(CheckPointer(trade) != POINTER_DYNAMIC)
            continue;
            
         // Check if this was a winning trade
         if(trade.is_winner)
            count++;
      }
      
      return count;
   }
   
   //--- Save trade history to file
   bool SaveTradeHistory()
   {
      string filename = m_data_path + "trade_history.bin";
      int handle = FileOpen(filename, FILE_WRITE|FILE_BIN|FILE_COMMON);
      
      if(handle == INVALID_HANDLE)
      {
         Print("Failed to open file for writing: ", filename, ", error: ", GetLastError());
         return false;
      }
      
      // Write number of trades
      int count = m_trade_history.Total();
      FileWriteInteger(handle, count);
      
      // Write each trade
      for(int i = 0; i < count; i++)
      {
         CObject* obj = m_trade_history.At(i);
         if(CheckPointer(obj) != POINTER_DYNAMIC)
            continue;
            
         STradeRecord* trade = dynamic_cast<STradeRecord*>(obj);
         if(CheckPointer(trade) != POINTER_DYNAMIC)
            continue;
            
         // Write each field individually
         FileWriteLong(handle, trade.entry_time);
         FileWriteLong(handle, trade.exit_time);
         FileWriteDouble(handle, trade.entry_price);
         FileWriteDouble(handle, trade.exit_price);
         FileWriteDouble(handle, trade.profit);
         FileWriteDouble(handle, trade.lot_size);
         FileWriteInteger(handle, trade.hold_time);
         FileWriteDouble(handle, trade.spread);
         FileWriteDouble(handle, trade.volatility);
         FileWriteDouble(handle, trade.trend_strength);
         FileWriteInteger(handle, (int)trade.is_winner);
      }
      
      FileClose(handle);
      return true;
   }
   
   //--- Load trade history from file
   bool LoadTradeHistory()
   {
      string filename = m_data_path + "trade_history.bin";
      int handle = FileOpen(filename, FILE_READ|FILE_BIN|FILE_COMMON);
      
      if(handle == INVALID_HANDLE)
      {
         Print("No trade history file found: ", filename, ", error: ", GetLastError());
         return false;
      }
      
      // Clear existing history
      m_trade_history.Clear();
      
      // Read number of trades
      int count = FileReadInteger(handle);
      
      // Read each trade
      for(int i = 0; i < count; i++)
      {
         // Create a new trade object on the heap
         STradeRecord *trade = new STradeRecord();
         if(CheckPointer(trade) != POINTER_DYNAMIC)
         {
            Print("Failed to allocate memory for trade record");
            FileClose(handle);
            return false;
         }
         
         // Read each field individually
         trade.entry_time = (datetime)FileReadLong(handle);
         trade.exit_time = (datetime)FileReadLong(handle);
         trade.entry_price = FileReadDouble(handle);
         trade.exit_price = FileReadDouble(handle);
         trade.profit = FileReadDouble(handle);
         trade.lot_size = FileReadDouble(handle);
         trade.hold_time = (int)FileReadInteger(handle);
         trade.spread = FileReadDouble(handle);
         trade.volatility = FileReadDouble(handle);
         trade.trend_strength = FileReadDouble(handle);
         trade.is_winner = (bool)FileReadInteger(handle);
         
         // Add the trade to the history (CArrayObj takes ownership of the pointer)
         if(!m_trade_history.Add(trade))
         {
            delete trade;
            FileClose(handle);
            Print("Failed to add trade to history");
            return false;
         }
      }
      
      FileClose(handle);
      
      // Recalculate metrics after loading
      CalculateMetrics();
      
      return true;
   }
   
   //--- Analyze market conditions and suggest action
   ENUM_POSITION_TYPE AnalyzeMarket(double current_volatility, double current_spread, 
                                   double current_trend_strength)
   {
      // Simple decision making based on learned patterns
      // In a real implementation, this would be more sophisticated
      
      // Calculate similarity to winning conditions
      double win_similarity = 0.0, loss_similarity = 0.0;
      
      if(m_win_metrics.sample_count > 0)
      {
         win_similarity = CalculateConditionSimilarity(
            current_volatility, current_spread, current_trend_strength, m_win_metrics);
      }
      
      if(m_loss_metrics.sample_count > 0)
      {
         loss_similarity = CalculateConditionSimilarity(
            current_volatility, current_spread, current_trend_strength, m_loss_metrics);
      }
      
      // Make decision based on similarity and historical performance
      if(win_similarity > loss_similarity && win_similarity > 0.7)
      {
         // Check if we have a strong enough trend to determine direction
         if(current_trend_strength > 10)
         {
            // In a real implementation, you would have more sophisticated logic here
            // to determine the direction based on learned patterns
            if(current_trend_strength > m_win_metrics.avg_trend_strength * 0.8)
               return POSITION_TYPE_BUY;
            else if(current_trend_strength < -m_win_metrics.avg_trend_strength * 0.8)
               return POSITION_TYPE_SELL;
         }
      }
      
      return WRONG_VALUE; // No clear signal
   }
   
   //--- Calculate similarity of current conditions to historical conditions
   double CalculateConditionSimilarity(double volatility, double spread, double trend_strength, 
                                     const SMetricStats &metrics)
   {
      if(metrics.sample_count == 0)
         return 0.0;
         
      // Simple weighted average of normalized differences
      double vol_diff = 1.0 - MathAbs(volatility - metrics.avg_volatility) / 
                       MathMax(volatility, metrics.avg_volatility);
      double spread_diff = 1.0 - MathAbs(spread - metrics.avg_spread) / 
                          MathMax(spread, metrics.avg_spread);
      double trend_diff = 1.0 - MathAbs(trend_strength - metrics.avg_trend_strength) / 
                         MathMax(MathAbs(trend_strength), MathAbs(metrics.avg_trend_strength));
      
      // Weighted average (adjust weights based on importance)
      return (vol_diff * 0.4 + spread_diff * 0.3 + trend_diff * 0.3);
   }
   
   //--- Get performance statistics
   void GetPerformanceStats(double &win_rate, double &profit_factor, double &avg_win, double &avg_loss)
   {
      win_rate = m_win_rate;
      profit_factor = m_profit_factor;
      avg_win = m_avg_win;
      avg_loss = m_avg_loss;
   }
   
   //--- Get number of trades in history
   int GetTotalTrades()
   {
      return m_trade_history.Total();
   }
};
//+------------------------------------------------------------------+
