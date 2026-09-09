//+------------------------------------------------------------------+
//| CInsightsRealtime.mqh                                            |
//| Real-time insights generation for PaperEA v2                     |
//| Provides on-demand strategy insights without batch processing    |
//+------------------------------------------------------------------+
#ifndef CINSIGHTSREALTIME_MQH
#define CINSIGHTSREALTIME_MQH

#include "IStrategy.mqh"
#include "IncrementalInsightEngine.mqh"
#include <Files\File.mqh>

//+------------------------------------------------------------------+
//| Real-time Insight Structure                                      |
//+------------------------------------------------------------------+
struct SRealtimeInsight
{
   datetime timestamp;
   string   strategy_name;
   string   symbol;
   int      timeframe;
   
   // Performance metrics
   double   win_rate;
   double   avg_profit;
   double   avg_loss;
   double   profit_factor;
   int      total_trades;
   int      winning_trades;
   int      losing_trades;
   
   // Risk metrics
   double   max_drawdown;
   double   sharpe_ratio;
   double   recovery_factor;
   
   // Market conditions
   double   volatility;
   double   trend_strength;
   
   // Recommendation
   string   recommendation;
   double   confidence;
   
   void Reset()
   {
      timestamp = 0;
      strategy_name = "";
      symbol = "";
      timeframe = 0;
      win_rate = 0.0;
      avg_profit = 0.0;
      avg_loss = 0.0;
      profit_factor = 0.0;
      total_trades = 0;
      winning_trades = 0;
      losing_trades = 0;
      max_drawdown = 0.0;
      sharpe_ratio = 0.0;
      recovery_factor = 0.0;
      volatility = 0.0;
      trend_strength = 0.0;
      recommendation = "HOLD";
      confidence = 0.0;
   }
};

//+------------------------------------------------------------------+
//| Real-time Insights Class                                         |
//+------------------------------------------------------------------+
class CInsightsRealtime
{
private:
   CIncrementalInsightEngine* m_engine;
   SRealtimeInsight           m_insights[];
   int                        m_insight_count;
   string                     m_data_path;
   datetime                   m_last_update;
   int                        m_update_interval_sec;
   bool                       m_initialized;
   
   // Cache for quick access
   map<string, int>           m_strategy_index;
   
public:
   // Constructor
   CInsightsRealtime()
   {
      m_engine = NULL;
      m_insight_count = 0;
      m_data_path = "DualEA\\insights_realtime.csv";
      m_last_update = 0;
      m_update_interval_sec = 60;  // Update every minute
      m_initialized = false;
      
      ArrayResize(m_insights, 100);
   }
   
   // Destructor
   ~CInsightsRealtime()
   {
      if(CheckPointer(m_engine) != POINTER_INVALID)
         delete m_engine;
      ArrayFree(m_insights);
   }
   
   //+------------------------------------------------------------------+
   //| Initialize with data path                                        |
   //+------------------------------------------------------------------+
   bool Initialize(const string data_path = "DualEA\\")
   {
      m_data_path = data_path;
      
      // Create incremental engine
      m_engine = new CIncrementalInsightEngine();
      if(CheckPointer(m_engine) == POINTER_INVALID)
      {
         Print("[CInsightsRealtime] ERROR: Failed to create IncrementalInsightEngine");
         return false;
      }
      
      // Load existing state if available
      string state_file = m_data_path + "insights_state.bin";
      m_engine.LoadState(state_file);
      
      m_initialized = true;
      PrintFormat("[CInsightsRealtime] Initialized with data path: %s", m_data_path);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Update insights from recent trades                               |
   //+------------------------------------------------------------------+
   void UpdateInsights()
   {
      if(!m_initialized || CheckPointer(m_engine) == POINTER_INVALID)
         return;
      
      datetime now = TimeCurrent();
      if(now - m_last_update < m_update_interval_sec)
         return;
      
      m_last_update = now;
      
      // Engine automatically maintains running statistics
      // Here we refresh our cached insights
      RefreshInsights();
   }
   
   //+------------------------------------------------------------------+
   //| Record a completed trade for analysis                            |
   //+------------------------------------------------------------------+
   void RecordTrade(const string strategy_name, const string symbol, 
                    int timeframe, double profit, double entry_price,
                    double exit_price, datetime close_time)
   {
      if(!m_initialized || CheckPointer(m_engine) == POINTER_INVALID)
         return;
      
      // Feed trade data to incremental engine
      m_engine.RecordTrade(strategy_name, symbol, timeframe, profit, close_time);
      
      // Mark for refresh on next update
      m_last_update = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Get insight for specific strategy                                |
   //+------------------------------------------------------------------+
   SRealtimeInsight* GetInsight(const string strategy_name)
   {
      if(!m_initialized)
         return NULL;
      
      // Check cache first
      if(m_strategy_index.ContainsKey(strategy_name))
      {
         int idx = m_strategy_index.Get(strategy_name);
         if(idx >= 0 && idx < m_insight_count)
            return &m_insights[idx];
      }
      
      // Search array
      for(int i = 0; i < m_insight_count; i++)
      {
         if(m_insights[i].strategy_name == strategy_name)
         {
            m_strategy_index.Set(strategy_name, i);
            return &m_insights[i];
         }
      }
      
      return NULL;
   }
   
   //+------------------------------------------------------------------+
   //| Get all insights                                                 |
   //+------------------------------------------------------------------+
   SRealtimeInsight& GetAllInsights(int &count)
   {
      count = m_insight_count;
      return m_insights[0];
   }
   
   //+------------------------------------------------------------------+
   //| Generate recommendation for strategy                             |
   //+------------------------------------------------------------------+
   string GenerateRecommendation(const string strategy_name)
   {
      SRealtimeInsight* insight = GetInsight(strategy_name);
      if(insight == NULL)
         return "NO_DATA";
      
      string rec = "HOLD";
      
      // Strong buy: high win rate, positive profit factor, low drawdown
      if(insight.win_rate > 0.6 && insight.profit_factor > 2.0 && insight.max_drawdown < 0.15)
      {
         rec = "STRONG_BUY";
         insight.confidence = 0.9;
      }
      // Buy: good win rate and profit factor
      else if(insight.win_rate > 0.5 && insight.profit_factor > 1.5)
      {
         rec = "BUY";
         insight.confidence = 0.7;
      }
      // Strong sell: poor performance across metrics
      else if(insight.win_rate < 0.4 && insight.profit_factor < 0.8)
      {
         rec = "STRONG_SELL";
         insight.confidence = 0.85;
      }
      // Sell: below average performance
      else if(insight.win_rate < 0.45 || insight.profit_factor < 1.0)
      {
         rec = "SELL";
         insight.confidence = 0.6;
      }
      // Hold: mixed signals or insufficient data
      else
      {
         rec = "HOLD";
         insight.confidence = 0.5;
      }
      
      insight.recommendation = rec;
      return rec;
   }
   
   //+------------------------------------------------------------------+
   //| Export insights to CSV                                           |
   //+------------------------------------------------------------------+
   bool ExportToCSV(const string filename = "")
   {
      if(!m_initialized || m_insight_count == 0)
         return false;
      
      string export_file = (filename != "") ? filename : m_data_path + "insights_export.csv";
      
      int handle = FileOpen(export_file, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
      {
         PrintFormat("[CInsightsRealtime] ERROR: Cannot open file %s for writing", export_file);
         return false;
      }
      
      // Write header
      FileWrite(handle, "timestamp,strategy,symbol,timeframe,win_rate,avg_profit,avg_loss," +
                       "profit_factor,total_trades,max_drawdown,sharpe_ratio,recommendation,confidence");
      
      // Write data
      for(int i = 0; i < m_insight_count; i++)
      {
         SRealtimeInsight& ins = m_insights[i];
         FileWrite(handle, 
                   TimeToString(ins.timestamp),
                   ins.strategy_name,
                   ins.symbol,
                   EnumToString((ENUM_TIMEFRAMES)ins.timeframe),
                   DoubleToString(ins.win_rate, 4),
                   DoubleToString(ins.avg_profit, 2),
                   DoubleToString(ins.avg_loss, 2),
                   DoubleToString(ins.profit_factor, 2),
                   IntegerToString(ins.total_trades),
                   DoubleToString(ins.max_drawdown, 4),
                   DoubleToString(ins.sharpe_ratio, 2),
                   ins.recommendation,
                   DoubleToString(ins.confidence, 2));
      }
      
      FileClose(handle);
      PrintFormat("[CInsightsRealtime] Exported %d insights to %s", m_insight_count, export_file);
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get summary report                                               |
   //+------------------------------------------------------------------+
   string GetSummaryReport()
   {
      if(!m_initialized || m_insight_count == 0)
         return "No insights available";
      
      string report = "[Real-time Insights Summary]\n";
      report += StringFormat("Total Strategies: %d\n", m_insight_count);
      report += StringFormat("Last Update: %s\n\n", TimeToString(m_last_update));
      
      for(int i = 0; i < m_insight_count; i++)
      {
         SRealtimeInsight& ins = m_insights[i];
         report += StringFormat("%s [%s]: WinRate=%.1f%%, PF=%.2f, Trades=%d, Rec=%s (%.0f%%)\n",
                               ins.strategy_name,
                               ins.symbol,
                               ins.win_rate * 100,
                               ins.profit_factor,
                               ins.total_trades,
                               ins.recommendation,
                               ins.confidence * 100);
      }
      
      return report;
   }
   
   //+------------------------------------------------------------------+
   //| Set update interval                                              |
   //+------------------------------------------------------------------+
   void SetUpdateInterval(int seconds)
   {
      m_update_interval_sec = MathMax(10, seconds);
   }
   
   //+------------------------------------------------------------------+
   //| Check if initialized                                             |
   //+------------------------------------------------------------------+
   bool IsInitialized() const
   {
      return m_initialized;
   }
   
private:
   //+------------------------------------------------------------------+
   //| Refresh cached insights from engine                              |
   //+------------------------------------------------------------------+
   void RefreshInsights()
   {
      if(CheckPointer(m_engine) == POINTER_INVALID)
         return;
      
      // Get stats from engine and convert to insights
      // This is a simplified implementation
      // In production, you'd iterate through engine's internal stats
      
      m_insight_count = 0;
      
      // Example: create insight for each tracked strategy
      // Actual implementation would query the engine's internal state
      Print("[CInsightsRealtime] Refreshing insights from incremental engine...");
   }
};

// Global instance (declared in PaperEA_v2.mq5)
extern CInsightsRealtime g_ins_rt;

#endif // CINSIGHTSREALTIME_MQH
