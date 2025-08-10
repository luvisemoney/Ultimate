//+------------------------------------------------------------------+
//|                                      OTCLearningEngine.mqh |
//|                          Copyright 2023, OTC Escape EA       |
//|                                     https://www.otc.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, OTC"
#property link      "https://www.otc.com"
#property version   "2.00"
#property strict

#include <Arrays\ArrayObj.mqh>
#include <Files\File.mqh>
#include "OTCTypes.mqh"

//+------------------------------------------------------------------+
//| Learning Engine for OTC Escape EA                                |
//+------------------------------------------------------------------+
class CLearningEngine : public CObject
{
private:
   CArrayObj           m_trade_history;          // Holds pointers to STradeRecord objects
   SMetricSet          m_overall_metrics;
   SMetricSet          m_metrics_buy[4];
   SMetricSet          m_metrics_sell[4];
   double              m_volatility_threshold;
   double              m_trend_threshold;
   int                 m_min_trades_for_analysis;
   string              m_data_path;              // Path for saving/loading data
   string              m_symbol;
   ENUM_TIMEFRAMES     m_period;

public:
   CLearningEngine(double volatility_thresh, double trend_thresh);
   ~CLearningEngine();

   void              Init(string symbol, ENUM_TIMEFRAMES period);
   void              SetMinTradesForAnalysis(int min_trades);
   void              AddTrade(STradeRecord *trade_record);
   void              CalculatePerformanceMetrics();
   int               GetTotalTrades() const;
   E_MARKET_REGIME   GetCurrentMarketRegime(double volatility, double trend_strength);
   bool              GetOptimizedParameters(SMarketState &state);

private:
   // Private helper methods for metric calculations
   void              _InitMetricSet(SMetricSet &metrics);
   void              _UpdateMetricSetWithTrade(SMetricSet &metrics, const STradeRecord *trade);
   void              _FinalizeMetricSet(SMetricSet &metrics);
   void              _AnalyzeClosedTrade(const STradeRecord *closed_trade);
   
   // Private helper methods for data persistence
   bool              SaveMetrics();
   bool              LoadMetrics();
   bool              SaveTradeHistory();
   void              _LoadTradeHistory();
   string            _GetMetricsFilePath();
   string            _GetTradeHistoryFilePath();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLearningEngine::CLearningEngine(double volatility_thresh, double trend_thresh)
{
   m_volatility_threshold = volatility_thresh;
   m_trend_threshold = trend_thresh;
   m_min_trades_for_analysis = 10; // Default value
   m_data_path = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\OTC_Escape_Data";
   if(FileIsExist(m_data_path) == false)
   {
      if(FolderCreate(m_data_path) == false)
      {
         PrintFormat("Failed to create data directory: %s, Error: %d", m_data_path, GetLastError());
      }
   }

   m_trade_history.FreeMode(true); // CArrayObj will delete the STradeRecord pointers it holds


}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLearningEngine::~CLearningEngine()
{
   SaveMetrics();
   SaveTradeHistory();
}

//+------------------------------------------------------------------+
//| Add a newly opened trade to the history                          |
//+------------------------------------------------------------------+
void CLearningEngine::SetMinTradesForAnalysis(int min_trades)
{
   m_min_trades_for_analysis = min_trades;
}

//+------------------------------------------------------------------+
//| Add a newly opened trade to the history                          |
//+------------------------------------------------------------------+
void CLearningEngine::AddTrade(STradeRecord *trade)
{
   if(CheckPointer(trade) == POINTER_INVALID) return;
   if(!m_trade_history.Add(trade))
   {
      Print("Failed to add trade to history, deleting record.");
      delete trade;
   }
}

//+------------------------------------------------------------------+
//| Analyze a closed trade and update metrics                      |
//+------------------------------------------------------------------+
void CLearningEngine::_AnalyzeClosedTrade(const STradeRecord *closed_trade)
{
   if(CheckPointer(closed_trade) == POINTER_INVALID) return;

   E_MARKET_REGIME regime = closed_trade->regime;
   if(closed_trade->trade_direction == 0) // Buy
   {
      _UpdateMetricSetWithTrade(m_metrics_buy[regime], closed_trade);
   }
   else // Sell
   {
      _UpdateMetricSetWithTrade(m_metrics_sell[regime], closed_trade);
   }

   _UpdateMetricSetWithTrade(m_overall_metrics, closed_trade);
}

//+------------------------------------------------------------------+
//| Get current market regime                                        |
//+------------------------------------------------------------------+
E_MARKET_REGIME CLearningEngine::GetCurrentMarketRegime(double volatility, double trend_strength)
{
   bool is_volatile = volatility > m_volatility_threshold;
   bool is_trending = trend_strength > m_trend_threshold;

   if(is_volatile && is_trending) return REGIME_VOLATILE_TRENDING;
   if(is_volatile && !is_trending) return REGIME_VOLATILE_RANGING;
   if(!is_volatile && is_trending) return REGIME_QUIET_TRENDING;
   // Default to quiet ranging
   return REGIME_QUIET_RANGING;
}

//+------------------------------------------------------------------+
//| Get optimized parameters for the current market state            |
//+------------------------------------------------------------------+
bool CLearningEngine::GetOptimizedParameters(SMarketState &market_state)
{
   E_MARKET_REGIME regime = market_state.regime;
   SMetricSet &metrics_buy = m_metrics_buy[regime];
   SMetricSet &metrics_sell = m_metrics_sell[regime];

   _FinalizeMetricSet(metrics_buy);
   _FinalizeMetricSet(metrics_sell);

   // Simple logic: choose the direction with better profit factor
   if(metrics_buy.profit_factor > metrics_sell.profit_factor && metrics_buy.total_trades >= m_min_trades_for_analysis)
   {
      market_state.trade_direction = ORDER_TYPE_BUY;
      market_state.optimal_sl = metrics_buy.avg_sl;
      market_state.optimal_tp = metrics_buy.avg_tp;
      return true;
   }
   else if(metrics_sell.profit_factor > metrics_buy.profit_factor && metrics_sell.total_trades >= m_min_trades_for_analysis)
   {
      market_state.trade_direction = ORDER_TYPE_SELL;
      market_state.optimal_sl = metrics_sell.avg_sl;
      market_state.optimal_tp = metrics_sell.avg_tp;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Initialize a metric set                                          |
//+------------------------------------------------------------------+
void CLearningEngine::_InitMetricSet(SMetricSet &metrics)
{
   metrics.Reset();
}

//+------------------------------------------------------------------+
//| Update a metric set with a single trade's data                   |
//+------------------------------------------------------------------+
void CLearningEngine::_UpdateMetricSetWithTrade(SMetricSet &metrics, const STradeRecord *trade)
{
   if(CheckPointer(trade) == POINTER_INVALID) return;

   metrics.total_trades++;
   metrics.total_sl_pips += (trade->stop_loss > 0 && trade->entry_price > 0) ? MathAbs(trade->entry_price - trade->stop_loss) / _Point : 0;
   metrics.total_tp_pips += (trade->take_profit > 0 && trade->entry_price > 0) ? MathAbs(trade->entry_price - trade->take_profit) / _Point : 0;

   if(trade->profit > 0)
   {
      metrics.total_wins++;
      metrics.total_profit += trade->profit;
   }
   else
   {
      metrics.total_losses++;
      metrics.total_loss += trade->profit;
   }
}

//+------------------------------------------------------------------+
//| Finalize calculations for a metric set                           |
//+------------------------------------------------------------------+
void CLearningEngine::_FinalizeMetricSet(SMetricSet &metrics)
{
   if(metrics.total_trades > 0)
   {
      metrics.win_rate = (double)metrics.total_wins / metrics.total_trades;
      metrics.avg_sl = (metrics.total_sl_pips > 0) ? metrics.total_sl_pips / metrics.total_trades : 0;
      metrics.avg_tp = (metrics.total_tp_pips > 0) ? metrics.total_tp_pips / metrics.total_trades : 0;
   }

   if(metrics.gross_loss != 0)
   {
      metrics.profit_factor = MathAbs(metrics.gross_profit / metrics.gross_loss);
   }
   else
   {
      metrics.profit_factor = (metrics.gross_profit > 0) ? 999.0 : 0.0; // High value for no losses
   }
}

//+------------------------------------------------------------------+
//| Calculate performance metrics for all regimes                    |
//+------------------------------------------------------------------+
void CLearningEngine::CalculatePerformanceMetrics()
{
   // Reset all metrics
   _InitMetricSet(m_overall_metrics);
   for(int i = 0; i < 4; i++)
   {
      _InitMetricSet(m_metrics_buy[i]);
      _InitMetricSet(m_metrics_sell[i]);
   }

   // Recalculate from history
   int total = m_trade_history.Total();
   for(int i = 0; i < total; i++)
   {
      STradeRecord *trade = m_trade_history.At(i);
      _AnalyzeClosedTrade(trade);
   }

   // Finalize all metrics
   _FinalizeMetricSet(m_overall_metrics);
   for(int i = 0; i < 4; i++)
   {
      _FinalizeMetricSet(m_metrics_buy[i]);
      _FinalizeMetricSet(m_metrics_sell[i]);
   }
}

//+------------------------------------------------------------------+
//| Get total trades from history                                    |
//+------------------------------------------------------------------+
int CLearningEngine::GetTotalTrades() const
{
   return m_trade_history.Total();
}

//+------------------------------------------------------------------+
//| Get file path for metrics                                        |
//+------------------------------------------------------------------+
string CLearningEngine::_GetMetricsFilePath()
{
   return TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + m_symbol + "_" + EnumToString(m_period) + "_metrics.bin";
}

//+------------------------------------------------------------------+
//| Get file path for trade history                                  |
//+------------------------------------------------------------------+
string CLearningEngine::_GetTradeHistoryFilePath()
{
   return StringFormat("%s\\%s_%s_trades.bin", m_data_path, m_symbol, EnumToString(m_period));
}

//+------------------------------------------------------------------+
//| Save metrics to a file                                           |
//+------------------------------------------------------------------+
bool CLearningEngine::SaveMetrics()
{
   string file_path = _GetMetricsFilePath();
   int handle = FileOpen(file_path, FILE_WRITE | FILE_BIN);
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("Failed to open metrics file for writing: %s", file_path);
      return false;
   }

   FileWriteStruct(handle, &m_overall_metrics);
   for(int i = 0; i < 4; i++)
   {
      FileWriteStruct(handle, &m_metrics_buy[i]);
      FileWriteStruct(handle, &m_metrics_sell[i]);
   }

   FileClose(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Load metrics from a file                                         |
//+------------------------------------------------------------------+
bool CLearningEngine::LoadMetrics()
{
   string file_path = _GetMetricsFilePath();
   if(!FileIsExist(file_path))
   {
      // Initialize all metrics if file doesn't exist
      _InitMetricSet(m_overall_metrics);
      for(int i = 0; i < 4; i++)
      {
         _InitMetricSet(m_metrics_buy[i]);
         _InitMetricSet(m_metrics_sell[i]);
      }
      return true; // Not an error, just first run
   }

   int handle = FileOpen(file_path, FILE_READ | FILE_BIN);
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("Failed to open metrics file for reading: %s", file_path);
      return false;
   }

   FileReadStruct(handle, &m_overall_metrics);
   for(int i = 0; i < 4; i++)
   {
      FileReadStruct(handle, &m_metrics_buy[i]);
      FileReadStruct(handle, &m_metrics_sell[i]);
   }

   FileClose(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Save trade history to a file                                     |
//+------------------------------------------------------------------+
bool CLearningEngine::SaveTradeHistory()
{
   string file_path = _GetTradeHistoryFilePath();
   int handle = FileOpen(file_path, FILE_WRITE | FILE_BIN);
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("Failed to open trade history file for writing: %s", file_path);
      return false;
   }

   int total = m_trade_history.Total();
   FileWriteInteger(handle, total, INT_VALUE);

   for(int i = 0; i < total; i++)
   {
      STradeRecord *trade = m_trade_history.At(i);
      if(CheckPointer(trade) == POINTER_INVALID) continue;
      FileWriteStruct(handle, trade);
   }

   FileClose(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Load trade history from a file                                   |
//+------------------------------------------------------------------+
void CLearningEngine::_LoadTradeHistory()
{
   string file_path = _GetTradeHistoryFilePath();
   if(!FileIsExist(file_path)) return;

   int handle = FileOpen(file_path, FILE_READ | FILE_BIN);
   if(handle == INVALID_HANDLE)
   {
      PrintFormat("Failed to open trade history file for reading: %s", file_path);
      return;
   }

   m_trade_history.Clear();
   int total = (int)FileReadInteger(handle, INT_VALUE);

   for(int i = 0; i < total; i++)
   {
      STradeRecord *trade = new STradeRecord();
      if(FileReadStruct(handle, trade) > 0)
      {
         if(!m_trade_history.Add(trade))
         {
            Print("Failed to add loaded trade to history, deleting record.");
            delete trade;
         }
      }
      else
      {
         Print("Failed to read trade record from file, deleting placeholder.");
         delete trade;
         break; // Stop reading if there's an error
      }
   }

   FileClose(handle);
}


//+------------------------------------------------------------------+
//| Initialize the learning engine with symbol and period            |
//+------------------------------------------------------------------+
void CLearningEngine::Init(string symbol, ENUM_TIMEFRAMES period)
{
   m_symbol = symbol;
   m_period = period;

   // Now that we have symbol and period, load data
   if(!LoadMetrics())
   {
      Print("No metrics file found. Initializing new metrics.");
      // Initialize all metrics if file doesn't exist
      _InitMetricSet(m_overall_metrics);
      for(int i = 0; i < 4; i++)
      {
         _InitMetricSet(m_metrics_buy[i]);
         _InitMetricSet(m_metrics_sell[i]);
      }
   }
   _LoadTradeHistory();
}


