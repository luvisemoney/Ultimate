//+------------------------------------------------------------------+
//| CInsightsRealtime.mqh - Real-time Insights Engine                |
//| Provides real-time performance insights for trading signals       |
//+------------------------------------------------------------------+
#ifndef CINSIGHTSREALTIME_MQH
#define CINSIGHTSREALTIME_MQH

#include <Object.mqh>

//+------------------------------------------------------------------+
//| Insight Data Structure                                            |
//+------------------------------------------------------------------+
struct SInsightData
{
   string   strategy;
   string   symbol;
   double   win_rate;
   double   profit_factor;
   double   expectancy;
   int      total_trades;
   int      winning_trades;
   int      losing_trades;
   double   avg_profit;
   double   avg_loss;
   double   max_drawdown;
   double   sharpe_ratio;
   datetime last_update;
   bool     valid;
};

//+------------------------------------------------------------------+
//| Insights Realtime Class                                           |
//+------------------------------------------------------------------+
class CInsightsRealtime : public CObject
{
private:
   SInsightData     m_insights[];
   int              m_insight_count;
   int              m_max_insights;
   int              m_min_trades_for_validity;
   double           m_decay_factor;
   
   int FindInsightIndex(const string strategy, const string symbol)
   {
      for(int i = 0; i < m_insight_count; i++)
      {
         if(m_insights[i].strategy == strategy && m_insights[i].symbol == symbol)
            return i;
      }
      return -1;
   }
   
public:
   CInsightsRealtime()
   {
      m_insight_count = 0;
      m_max_insights = 1000;
      m_min_trades_for_validity = 10;
      m_decay_factor = 0.95;
      ArrayResize(m_insights, 0);
   }
   
   ~CInsightsRealtime()
   {
      ArrayResize(m_insights, 0);
   }
   
   bool Initialize()
   {
      Print("[InsightsRealtime] Initialized");
      return true;
   }
   
   void Shutdown()
   {
      ArrayResize(m_insights, 0);
      m_insight_count = 0;
   }
   
   // Update insight based on completed trade
   void OnTradeCompleted(const string strategy, const string symbol, 
                        double pnl, double r_multiple)
   {
      int idx = FindInsightIndex(strategy, symbol);
      
      if(idx < 0)
      {
         // Create new insight entry
         idx = m_insight_count;
         if(idx >= m_max_insights)
         {
            Print("[InsightsRealtime] Warning: Max insights reached");
            return;
         }
         ArrayResize(m_insights, idx + 1);
         m_insights[idx].strategy = strategy;
         m_insights[idx].symbol = symbol;
         m_insights[idx].win_rate = 0.0;
         m_insights[idx].profit_factor = 0.0;
         m_insights[idx].expectancy = 0.0;
         m_insights[idx].total_trades = 0;
         m_insights[idx].winning_trades = 0;
         m_insights[idx].losing_trades = 0;
         m_insights[idx].avg_profit = 0.0;
         m_insights[idx].avg_loss = 0.0;
         m_insights[idx].max_drawdown = 0.0;
         m_insights[idx].sharpe_ratio = 0.0;
         m_insights[idx].valid = false;
         m_insight_count++;
      }
      
      // Update statistics directly on array element
      m_insights[idx].total_trades++;
      
      if(pnl > 0)
      {
         m_insights[idx].winning_trades++;
         m_insights[idx].avg_profit = (m_insights[idx].avg_profit * (m_insights[idx].winning_trades - 1) + pnl) / m_insights[idx].winning_trades;
      }
      else
      {
         m_insights[idx].losing_trades++;
         m_insights[idx].avg_loss = (m_insights[idx].avg_loss * (m_insights[idx].losing_trades - 1) + MathAbs(pnl)) / m_insights[idx].losing_trades;
      }
      
      m_insights[idx].win_rate = (double)m_insights[idx].winning_trades / m_insights[idx].total_trades;
      
      double gross_profit = m_insights[idx].avg_profit * m_insights[idx].winning_trades;
      double gross_loss = m_insights[idx].avg_loss * m_insights[idx].losing_trades;
      m_insights[idx].profit_factor = (gross_loss > 0) ? gross_profit / gross_loss : 0.0;
      
      double win_prob = m_insights[idx].win_rate;
      double loss_prob = 1.0 - win_prob;
      m_insights[idx].expectancy = (win_prob * m_insights[idx].avg_profit) - (loss_prob * m_insights[idx].avg_loss);
      
      if(r_multiple < 0)
      {
         double current_dd = MathAbs(r_multiple);
         if(current_dd > m_insights[idx].max_drawdown)
            m_insights[idx].max_drawdown = current_dd;
      }
      
      m_insights[idx].valid = (m_insights[idx].total_trades >= m_min_trades_for_validity);
      m_insights[idx].last_update = TimeCurrent();
   }
   
   // Get signal confidence based on historical performance
   double GetSignalConfidence(const string strategy, const string symbol)
   {
      int idx = FindInsightIndex(strategy, symbol);
      if(idx < 0) return 0.5; // Default neutral confidence
      
      if(!m_insights[idx].valid || m_insights[idx].total_trades < m_min_trades_for_validity)
         return 0.5;
      
      // Calculate confidence based on win rate and profit factor
      double win_confidence = m_insights[idx].win_rate;
      double pf_confidence = MathMin(m_insights[idx].profit_factor / 2.0, 1.0); // Cap at 1.0, normalize
      
      // Combine factors
      double confidence = (win_confidence * 0.6) + (pf_confidence * 0.4);
      
      // Apply decay for stale data
      datetime now = TimeCurrent();
      int hours_since_update = (int)((now - m_insights[idx].last_update) / 3600);
      if(hours_since_update > 24)
      {
         double age_factor = MathPow(m_decay_factor, hours_since_update / 24.0);
         confidence *= age_factor;
      }
      
      return MathMin(MathMax(confidence, 0.0), 1.0);
   }
   
   // Get full insight data
   bool GetInsight(const string strategy, const string symbol, SInsightData &data)
   {
      int idx = FindInsightIndex(strategy, symbol);
      if(idx < 0) return false;
      
      data = m_insights[idx];
      return true;
   }
   
   // Check if strategy/symbol combination has valid insights
   bool HasValidInsight(const string strategy, const string symbol)
   {
      int idx = FindInsightIndex(strategy, symbol);
      if(idx < 0) return false;
      return m_insights[idx].valid;
   }
   
   // Get metrics for strategy selection
   bool GetStrategyMetrics(const string strategy, const string symbol,
                          double &win_rate, double &profit_factor, double &expectancy)
   {
      int idx = FindInsightIndex(strategy, symbol);
      if(idx < 0 || !m_insights[idx].valid)
      {
         win_rate = 0.5;
         profit_factor = 1.0;
         expectancy = 0.0;
         return false;
      }
      
      win_rate = m_insights[idx].win_rate;
      profit_factor = m_insights[idx].profit_factor;
      expectancy = m_insights[idx].expectancy;
      return true;
   }
   
   // Get best performing strategy for symbol
   string GetBestStrategy(const string symbol)
   {
      string best_strategy = "";
      double best_score = -1.0;
      
      for(int i = 0; i < m_insight_count; i++)
      {
         if(m_insights[i].symbol == symbol && m_insights[i].valid)
         {
            // Score based on expectancy and win rate
            double score = m_insights[i].expectancy * m_insights[i].win_rate;
            if(score > best_score)
            {
               best_score = score;
               best_strategy = m_insights[i].strategy;
            }
         }
      }
      
      return best_strategy;
   }
   
   // Reset all insights
   void Reset()
   {
      ArrayResize(m_insights, 0);
      m_insight_count = 0;
   }
   
   // Get total insight count
   int GetCount() const { return m_insight_count; }
   
   // Get valid insight count
   int GetValidCount()
   {
      int count = 0;
      for(int i = 0; i < m_insight_count; i++)
      {
         if(m_insights[i].valid)
            count++;
      }
      return count;
   }
   
   void SetMinTradesForValidity(int min_trades) { m_min_trades_for_validity = min_trades; }
   int GetMinTradesForValidity() const { return m_min_trades_for_validity; }
};

#endif // CINSIGHTSREALTIME_MQH
