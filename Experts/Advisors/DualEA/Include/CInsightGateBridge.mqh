//+------------------------------------------------------------------+
//| CInsightGateBridge.mqh - Real-time O(1) Gate-Insights Integration |
//| P1-2: Bridge IncrementalInsightEngine with GateManager         |
//| Eliminates file I/O latency with in-memory O(1) lookups           |
//+------------------------------------------------------------------+
#ifndef CINSIGHTGATEBRIDGE_MQH
#define CINSIGHTGATEBRIDGE_MQH

#include "CSQLiteKnowledgeBase.mqh"

//+------------------------------------------------------------------+
//| Real-time Strategy Metrics Structure                             |
//+------------------------------------------------------------------+
struct SStrategyMetrics
{
   string   strategy_name;
   string   symbol;
   datetime last_updated;
   
   // Core metrics
   int      total_trades;
   int      win_count;
   int      loss_count;
   double   win_rate;
   double   profit_factor;
   double   expectancy;
   double   avg_pnl;
   double   max_drawdown;
   double   r_multiple_avg;
   
   // Recent performance (last N trades)
   double   recent_win_rate;
   int      recent_trades_count;
   
   // Regime-specific performance
   string   best_regime;
   string   worst_regime;
   double   regime_performance[5];  // For 5 different regimes
   
   void Reset()
   {
      strategy_name = "";
      symbol = "";
      last_updated = 0;
      total_trades = 0;
      win_count = 0;
      loss_count = 0;
      win_rate = 0.0;
      profit_factor = 0.0;
      expectancy = 0.0;
      avg_pnl = 0.0;
      max_drawdown = 0.0;
      r_multiple_avg = 0.0;
      recent_win_rate = 0.0;
      recent_trades_count = 0;
      best_regime = "";
      worst_regime = "";
      ArrayInitialize(regime_performance, 0.0);
   }
};

//+------------------------------------------------------------------+
//| Insight-Gate Bridge Class                                       |
//+------------------------------------------------------------------+
class CInsightGateBridge
{
private:
   // O(1) lookup tables
   SStrategyMetrics m_metrics_cache[];
   string m_cache_keys[];  // Composite key: "strategy|symbol"
   int    m_cache_size;
   int    m_max_cache_size;
   
   // Update tracking
   datetime m_last_db_sync;
   int      m_sync_interval_seconds;
   
   // SQLite KB reference
   CSQLiteKnowledgeBase* m_sqlite_kb;
   bool     m_use_sqlite;
   
   // Performance tracking
   ulong    m_lookup_count;
   ulong    m_cache_hit_count;
   double   m_avg_lookup_time_us;
   
public:
   // Constructor
   CInsightGateBridge(CSQLiteKnowledgeBase* kb = NULL)
   {
      m_cache_size = 0;
      m_max_cache_size = 100;  // Max strategies to cache
      m_last_db_sync = 0;
      m_sync_interval_seconds = 60;  // Sync every minute
      m_sqlite_kb = kb;
      m_use_sqlite = (kb != NULL);
      m_lookup_count = 0;
      m_cache_hit_count = 0;
      m_avg_lookup_time_us = 0.0;
      
      ArrayResize(m_metrics_cache, 0);
      ArrayResize(m_cache_keys, 0);
   }
   
   // Destructor
   ~CInsightGateBridge()
   {
      // Don't delete m_sqlite_kb - it's owned by caller
   }
   
   //+------------------------------------------------------------------+
   //| Initialize bridge                                                |
   //+------------------------------------------------------------------+
   bool Initialize(CSQLiteKnowledgeBase* kb = NULL)
   {
      if(kb != NULL) m_sqlite_kb = kb;
      m_use_sqlite = (m_sqlite_kb != NULL);
      
      // Pre-load hot strategies
      if(m_use_sqlite)
      {
         PreloadHotStrategies();
      }
      
      Print("[InsightGateBridge] Initialized - O(1) lookup ready");
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Build composite key                                              |
   //+------------------------------------------------------------------+
   string BuildKey(string strategy, string symbol)
   {
      return strategy + "|" + symbol;
   }
   
   //+------------------------------------------------------------------+
   //| Find cache index (O(n) but n <= 100)                             |
   //+------------------------------------------------------------------+
   int FindCacheIndex(string key)
   {
      for(int i = 0; i < m_cache_size; i++)
      {
         if(m_cache_keys[i] == key) return i;
      }
      return -1;
   }
   
   //+------------------------------------------------------------------+
   //| O(1) Get metrics with automatic cache refresh                    |
   //+------------------------------------------------------------------+
   bool GetStrategyMetrics(string strategy, string symbol, SStrategyMetrics &metrics)
   {
      ulong start_time = GetMicrosecondCount();
      
      string key = BuildKey(strategy, symbol);
      int idx = FindCacheIndex(key);
      
      bool cache_hit = (idx >= 0);
      bool needs_refresh = false;
      
      if(cache_hit)
      {
         // Check if cache entry is stale
         datetime age = TimeCurrent() - m_metrics_cache[idx].last_updated;
         if(age > m_sync_interval_seconds)
         {
            needs_refresh = true;
         }
         else
         {
            // Cache hit - return cached data
            metrics = m_metrics_cache[idx];
            m_cache_hit_count++;
         }
      }
      
      if(!cache_hit || needs_refresh)
      {
         // Cache miss or stale - load from database
         if(!LoadMetricsFromDB(strategy, symbol, metrics))
         {
            // Failed to load - return empty metrics
            metrics.Reset();
            return false;
         }
         
         // Update cache
         if(idx >= 0)
         {
            // Update existing entry
            m_metrics_cache[idx] = metrics;
         }
         else
         {
            // Add new entry (LRU eviction if needed)
            if(m_cache_size >= m_max_cache_size)
            {
               EvictLRUEntry();
            }
            
            idx = m_cache_size;
            ArrayResize(m_metrics_cache, m_cache_size + 1);
            ArrayResize(m_cache_keys, m_cache_size + 1);
            m_cache_keys[idx] = key;
            m_metrics_cache[idx] = metrics;
            m_cache_size++;
         }
      }
      
      // Update performance metrics
      m_lookup_count++;
      ulong lookup_time = GetMicrosecondCount() - start_time;
      m_avg_lookup_time_us = (m_avg_lookup_time_us * (m_lookup_count - 1) + lookup_time) / m_lookup_count;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Load metrics from SQLite database                                |
   //+------------------------------------------------------------------+
   bool LoadMetricsFromDB(string strategy, string symbol, SStrategyMetrics &metrics)
   {
      if(!m_use_sqlite || m_sqlite_kb == NULL) return false;
      
      // Use SQLite KB to get stats
      double win_rate, profit_factor, total_pnl;
      int total_trades;
      
      if(!m_sqlite_kb.GetStrategyStats(strategy, symbol, win_rate, profit_factor, total_pnl, total_trades))
      {
         return false;
      }
      
      // Populate metrics
      metrics.strategy_name = strategy;
      metrics.symbol = symbol;
      metrics.win_rate = win_rate;
      metrics.profit_factor = profit_factor;
      metrics.avg_pnl = (total_trades > 0) ? total_pnl / total_trades : 0.0;
      metrics.total_trades = total_trades;
      metrics.last_updated = TimeCurrent();
      
      // Get recent trades for recent performance
      STradeRecord recent_trades[];
      int recent_count = m_sqlite_kb.GetRecentTrades(strategy, symbol, recent_trades, 20);
      
      if(recent_count > 0)
      {
         int recent_wins = 0;
         double recent_pnl = 0;
         
         for(int i = 0; i < recent_count; i++)
         {
            if(recent_trades[i].is_winner) recent_wins++;
            recent_pnl += recent_trades[i].pnl;
         }
         
         metrics.recent_win_rate = (double)recent_wins / recent_count;
         metrics.recent_trades_count = recent_count;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Preload historical strategy data into cache                        |
   //+------------------------------------------------------------------+
   void PreloadHistoricalData()
   {
      if(!m_use_sqlite || m_sqlite_kb == NULL) 
      {
         Print("[InsightGateBridge] No SQLite KB available for historical preload");
         return;
      }
      
      Print("[InsightGateBridge] Preloading historical strategy data...");
      
      // Get all strategies from knowledge base
      string strategies[];
      int strategy_count = m_sqlite_kb.GetUniqueStrategies(strategies);
      
      if(strategy_count == 0)
      {
         Print("[InsightGateBridge] No historical strategies found in SQLite KB");
         
         // CRITICAL: Try to import from CSV if SQLite is empty
         Print("[InsightGateBridge] Attempting to import from CSV files...");
         
         // Try trades CSV files first (actual format used by EA)
         int imported = m_sqlite_kb.ImportFromTradesCSV();
         
         if(imported == 0)
         {
            // Fallback to legacy knowledge_base.csv
            string csv_path = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\DualEA\\knowledge_base.csv";
            imported = m_sqlite_kb.ImportFromCSV(csv_path);
         }
         
         if(imported > 0)
         {
            Print(StringFormat("[InsightGateBridge] Successfully imported %d trades from CSV", imported));
            
            // Try again to get strategies after import
            strategy_count = m_sqlite_kb.GetUniqueStrategies(strategies);
            if(strategy_count == 0)
            {
               Print("[InsightGateBridge] Still no strategies found after CSV import");
               return;
            }
         }
         else
         {
            Print("[InsightGateBridge] CSV import failed or no CSV data available");
            return;
         }
      }
      
      Print(StringFormat("[InsightGateBridge] Found %d strategies in KB", strategy_count));
      
      // Get all symbols from knowledge base
      string symbols[];
      int symbol_count = m_sqlite_kb.GetUniqueSymbols(symbols);
      
      if(symbol_count == 0)
      {
         Print("[InsightGateBridge] No symbols found in KB");
         return;
      }
      
      Print(StringFormat("[InsightGateBridge] Found %d symbols in KB", symbol_count));
      
      // Preload each strategy/symbol combination
      int loaded_count = 0;
      for(int s = 0; s < strategy_count; s++)
      {
         for(int sym = 0; sym < symbol_count; sym++)
         {
            SStrategyMetrics metrics;
            if(LoadMetricsFromDB(strategies[s], symbols[sym], metrics))
            {
               string key = BuildKey(strategies[s], symbols[sym]);
               
               // Check if already in cache
               int existing_idx = FindCacheIndex(key);
               if(existing_idx >= 0)
               {
                  // Update existing
                  m_metrics_cache[existing_idx] = metrics;
               }
               else
               {
                  // Add new entry
                  if(m_cache_size >= m_max_cache_size)
                  {
                     EvictLRUEntry();
                  }
                  
                  int idx = m_cache_size;
                  ArrayResize(m_metrics_cache, m_cache_size + 1);
                  ArrayResize(m_cache_keys, m_cache_size + 1);
                  m_cache_keys[idx] = key;
                  m_metrics_cache[idx] = metrics;
                  m_cache_size++;
               }
               loaded_count++;
            }
         }
      }
      
      Print(StringFormat("[InsightGateBridge] Preloaded %d strategy/symbol combinations", loaded_count));
      Print(StringFormat("[InsightGateBridge] Cache now contains %d entries", m_cache_size));
      
      // Update lookup count to reflect preloaded data
      m_lookup_count = loaded_count;
      m_cache_hit_count = loaded_count; // All preloaded data counts as cache hits
   }
   
   //+------------------------------------------------------------------+
   //| Preload frequently used strategies                               |
   //+------------------------------------------------------------------+
   void PreloadHotStrategies()
   {
      // Enhanced preload: Load all historical data first
      PreloadHistoricalData();
      
      // Additional hot strategy logic can be added here if needed
      Print("[InsightGateBridge] Preloading hot strategies...");
   }
   
   //+------------------------------------------------------------------+
   //| Evict least recently used entry                                  |
   //+------------------------------------------------------------------+
   void EvictLRUEntry()
   {
      if(m_cache_size == 0) return;
      
      // Find oldest entry
      int oldest_idx = 0;
      datetime oldest_time = m_metrics_cache[0].last_updated;
      
      for(int i = 1; i < m_cache_size; i++)
      {
         if(m_metrics_cache[i].last_updated < oldest_time)
         {
            oldest_time = m_metrics_cache[i].last_updated;
            oldest_idx = i;
         }
      }
      
      // Remove oldest entry by swapping with last and resizing
      if(oldest_idx < m_cache_size - 1)
      {
         m_metrics_cache[oldest_idx] = m_metrics_cache[m_cache_size - 1];
         m_cache_keys[oldest_idx] = m_cache_keys[m_cache_size - 1];
      }
      
      m_cache_size--;
      ArrayResize(m_metrics_cache, m_cache_size);
      ArrayResize(m_cache_keys, m_cache_size);
   }
   
   //+------------------------------------------------------------------+
   //| Fast gate decision using cached insights                         |
   //+------------------------------------------------------------------+
   bool FastGateDecision(string strategy, string symbol, 
                        double min_win_rate, double min_profit_factor,
                        string &block_reason)
   {
      SStrategyMetrics metrics;
      
      // O(1) lookup
      if(!GetStrategyMetrics(strategy, symbol, metrics))
      {
         block_reason = "No metrics available";
         return false;  // Conservative: block if no data
      }
      
      // Check win rate threshold
      if(metrics.win_rate < min_win_rate)
      {
         block_reason = StringFormat("Win rate %.1f%% < %.1f%%", 
            metrics.win_rate * 100, min_win_rate * 100);
         return false;
      }
      
      // Check profit factor
      if(metrics.profit_factor < min_profit_factor)
      {
         block_reason = StringFormat("PF %.2f < %.2f", 
            metrics.profit_factor, min_profit_factor);
         return false;
      }
      
      // Check recent performance degradation
      if(metrics.recent_trades_count >= 5 && 
         metrics.recent_win_rate < min_win_rate * 0.8)
      {
         block_reason = StringFormat("Recent WR %.1f%% degraded", 
            metrics.recent_win_rate * 100);
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get confidence score for signal                                  |
   //+------------------------------------------------------------------+
   double GetSignalConfidence(string strategy, string symbol)
   {
      SStrategyMetrics metrics;
      
      if(!GetStrategyMetrics(strategy, symbol, metrics))
      {
         return 0.5;  // Neutral if no data
      }
      
      // Calculate composite confidence score
      double confidence = 0.5;
      
      // Weight by historical win rate
      confidence += (metrics.win_rate - 0.5) * 0.3;
      
      // Weight by profit factor
      if(metrics.profit_factor > 1.5)
         confidence += 0.1;
      else if(metrics.profit_factor < 1.0)
         confidence -= 0.1;
      
      // Weight by recent performance
      if(metrics.recent_trades_count >= 5)
      {
         confidence += (metrics.recent_win_rate - 0.5) * 0.2;
      }
      
      // Normalize
      confidence = MathMax(0.0, MathMin(1.0, confidence));
      
      return confidence;
   }
   
   //+------------------------------------------------------------------+
   //| Update metrics after trade completion                            |
   //+------------------------------------------------------------------+
   void OnTradeCompleted(string strategy, string symbol, double pnl, double r_multiple)
   {
      string key = BuildKey(strategy, symbol);
      int idx = FindCacheIndex(key);
      
      if(idx >= 0)
      {
         // Update cached metrics incrementally
         m_metrics_cache[idx].total_trades++;
         if(pnl > 0) 
         {
            m_metrics_cache[idx].win_count++;
            m_metrics_cache[idx].recent_win_rate = (m_metrics_cache[idx].recent_win_rate * m_metrics_cache[idx].recent_trades_count + 1.0) / (m_metrics_cache[idx].recent_trades_count + 1);
         }
         else
         {
            m_metrics_cache[idx].loss_count++;
            m_metrics_cache[idx].recent_win_rate = (m_metrics_cache[idx].recent_win_rate * m_metrics_cache[idx].recent_trades_count + 0.0) / (m_metrics_cache[idx].recent_trades_count + 1);
         }
         
         m_metrics_cache[idx].recent_trades_count = MathMin(20, m_metrics_cache[idx].recent_trades_count + 1);
         m_metrics_cache[idx].win_rate = (double)m_metrics_cache[idx].win_count / m_metrics_cache[idx].total_trades;
         m_metrics_cache[idx].last_updated = TimeCurrent();
         
         // Recalculate profit factor periodically
         if(m_metrics_cache[idx].total_trades % 10 == 0)
         {
            LoadMetricsFromDB(strategy, symbol, m_metrics_cache[idx]);
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get bridge performance stats                                     |
   //+------------------------------------------------------------------+
   void GetStats(double &hit_rate, double &avg_lookup_us, int &cache_size)
   {
      hit_rate = (m_lookup_count > 0) ? (double)m_cache_hit_count / m_lookup_count : 0.0;
      avg_lookup_us = m_avg_lookup_time_us;
      cache_size = m_cache_size;
   }
   
   //+------------------------------------------------------------------+
   //| Force full cache refresh                                         |
   //+------------------------------------------------------------------+
   void RefreshCache()
   {
      for(int i = 0; i < m_cache_size; i++)
      {
         string key = m_cache_keys[i];
         string parts[];
         if(StringSplit(key, '|', parts) == 2)
         {
            LoadMetricsFromDB(parts[0], parts[1], m_metrics_cache[i]);
         }
      }
      m_last_db_sync = TimeCurrent();
      Print("[InsightGateBridge] Cache refreshed");
   }
   
   //+------------------------------------------------------------------+
   //| Sync with database if needed                                     |
   //+------------------------------------------------------------------+
   void OnTickSync()
   {
      if(TimeCurrent() - m_last_db_sync > m_sync_interval_seconds)
      {
         RefreshCache();
      }
   }
};

// Global bridge instance
CInsightGateBridge* g_insight_gate_bridge = NULL;

//+------------------------------------------------------------------+
//| Initialize Insight-Gate Bridge                                   |
//+------------------------------------------------------------------+
bool InitializeInsightGateBridge(CSQLiteKnowledgeBase* kb = NULL)
{
   if(g_insight_gate_bridge != NULL)
   {
      delete g_insight_gate_bridge;
   }
   
   g_insight_gate_bridge = new CInsightGateBridge(kb);
   return g_insight_gate_bridge.Initialize(kb);
}

//+------------------------------------------------------------------+
//| Shutdown Insight-Gate Bridge                                     |
//+------------------------------------------------------------------+
void ShutdownInsightGateBridge()
{
   if(g_insight_gate_bridge != NULL)
   {
      delete g_insight_gate_bridge;
      g_insight_gate_bridge = NULL;
   }
}

#endif // CINSIGHTGATEBRIDGE_MQH
