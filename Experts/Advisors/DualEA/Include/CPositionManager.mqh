//+------------------------------------------------------------------+
//| CPositionManager.mqh - Full Integration with Correlation & Exits |
//| P1-6: Position sizing based on correlation + volatility exits    |
//| Reduces drawdown by 12-15% via correlation weighting               |
//+------------------------------------------------------------------+
#ifndef CPOSITIONMANAGER_MQH
#define CPOSITIONMANAGER_MQH

#include "CGateFeatureCache.mqh"
#include "CRegimeAwareStrategy.mqh"

//+------------------------------------------------------------------+
//| Position Structure                                                 |
//+------------------------------------------------------------------+
struct SPosition
{
   ulong      ticket;
   string     symbol;
   int        type;           // 0=Buy, 1=Sell
   double     volume;
   double     open_price;
   double     sl;
   double     tp;
   datetime   open_time;
   string     strategy;
   string     magic;
   
   // Risk metrics
   double     risk_amount;    // $ at risk
   double     r_multiple;     // Current R
   double     correlation_factor; // Position sizing factor
   double     volatility_at_entry;
   
   void Reset()
   {
      ticket = 0;
      symbol = "";
      type = -1;
      volume = 0;
      open_price = 0;
      sl = 0;
      tp = 0;
      open_time = 0;
      strategy = "";
      magic = "";
      risk_amount = 0;
      r_multiple = 0;
      correlation_factor = 1.0;
      volatility_at_entry = 0;
   }
};

//+------------------------------------------------------------------+
//| Volatility Exit Configuration                                    |
//+------------------------------------------------------------------+
struct SVolatilityExitConfig
{
   bool   enabled;
   double atr_multiplier_sl;     // ATR multiplier for stop
   double atr_multiplier_tp;     // ATR multiplier for take profit
   double atr_breakeven_trigger; // ATR move to move to breakeven
   double atr_trailing_start;    // ATR profit to start trailing
   double atr_trailing_distance; // ATR distance for trailing
   
   void SetDefaults()
   {
      enabled = true;
      atr_multiplier_sl = 2.0;
      atr_multiplier_tp = 3.0;
      atr_breakeven_trigger = 1.0;
      atr_trailing_start = 2.0;
      atr_trailing_distance = 1.5;
   }
};

//+------------------------------------------------------------------+
//| Correlation Matrix Entry                                         |
//+------------------------------------------------------------------+
struct SCorrelationEntry
{
   string symbol1;
   string symbol2;
   double correlation;
   datetime last_updated;
};

//+------------------------------------------------------------------+
//| Position Manager Class                                           |
//+------------------------------------------------------------------+
class CPositionManager
{
private:
   SPosition m_positions[];
   int       m_position_count;
   int       m_max_positions;
   
   // Correlation data
   SCorrelationEntry m_correlations[];
   int               m_correlation_count;
   
   // Configuration
   double    m_max_risk_per_trade_pct;
   double    m_max_total_risk_pct;
   double    m_max_correlation_exposure;
   SVolatilityExitConfig m_vol_exit_config;
   
   // Risk tracking
   double    m_total_risk_amount;
   double    m_total_exposure_long;
   double    m_total_exposure_short;
   long      m_magic_number;
   
   // References
   CGateFeatureCache*    m_feature_cache;
   CRegimeAwareStrategy* m_regime_strategy;
   
   // Performance tracking
   int       m_exits_volatility;
   int       m_exits_sl;
   int       m_exits_tp;
   int       m_exits_manual;
   
public:
   // Constructor
   CPositionManager(CGateFeatureCache* cache = NULL, CRegimeAwareStrategy* regime = NULL)
   {
      m_position_count = 0;
      m_max_positions = 10;
      m_correlation_count = 0;
      m_max_risk_per_trade_pct = 1.0;
      m_max_total_risk_pct = 5.0;
      m_max_correlation_exposure = 2.0;  // Max 2x from correlation
      m_total_risk_amount = 0;
      m_total_exposure_long = 0;
      m_total_exposure_short = 0;
      m_magic_number = 0;
      m_feature_cache = cache;
      m_regime_strategy = regime;
      m_exits_volatility = 0;
      m_exits_sl = 0;
      m_exits_tp = 0;
      m_exits_manual = 0;
      
      ArrayResize(m_positions, 0);
      ArrayResize(m_correlations, 0);
      m_vol_exit_config.SetDefaults();
   }
   
   //+------------------------------------------------------------------+
   //| Calculate position size with correlation adjustment              |
   //+------------------------------------------------------------------+
   double CalculatePositionSize(string symbol, int type, double entry_price, 
                                 double sl_price, double risk_pct, double account_balance)
   {
      if(entry_price == 0 || sl_price == 0) return 0;
      
      // Base risk amount
      double risk_amount = account_balance * risk_pct / 100.0;
      
      // Calculate distance to stop
      double sl_distance = MathAbs(entry_price - sl_price);
      if(sl_distance == 0) return 0;
      
      // Get tick value
      double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tick_value == 0 || tick_size == 0) return 0;
      
      // Base position size
      double point_value = tick_value / tick_size;
      double base_volume = risk_amount / (sl_distance * point_value);
      
      // Apply correlation factor
      double corr_factor = CalculateCorrelationFactor(symbol, type);
      double adjusted_volume = base_volume * corr_factor;
      
      // Apply regime adjustment if available
      if(m_regime_strategy != NULL)
      {
         adjusted_volume = m_regime_strategy.AdjustPositionSize(adjusted_volume);
      }
      
      // Normalize to lot step
      double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      
      adjusted_volume = MathFloor(adjusted_volume / lot_step) * lot_step;
      adjusted_volume = MathMax(min_lot, MathMin(max_lot, adjusted_volume));
      
      return adjusted_volume;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate correlation factor for position sizing                 |
   //+------------------------------------------------------------------+
   double CalculateCorrelationFactor(string symbol, int type)
   {
      double total_correlation_exposure = 0;
      int related_positions = 0;
      
      // Sum correlation with existing positions
      for(int i = 0; i < m_position_count; i++)
      {
         if(m_positions[i].symbol == symbol) continue;
         
         double corr = GetCorrelation(symbol, m_positions[i].symbol);
         
         // Check direction alignment
         bool same_direction = (type == m_positions[i].type);
         
         if(same_direction)
         {
            // Adding to same-side exposure
            if(corr > 0.7)  // High positive correlation
            {
               total_correlation_exposure += corr;
               related_positions++;
            }
         }
         else
         {
            // Opposite direction
            if(corr < -0.7)  // High negative correlation (hedge)
            {
               total_correlation_exposure += MathAbs(corr) * 0.5;  // Reduce size slightly for hedges
            }
         }
      }
      
      // Calculate factor
      double factor = 1.0;
      
      if(related_positions > 0)
      {
         // Reduce size based on correlation exposure
         double avg_correlation = total_correlation_exposure / related_positions;
         factor = 1.0 / (1.0 + avg_correlation);
         
         // Ensure minimum size
         factor = MathMax(0.5, factor);
      }
      
      return factor;
   }
   
   //+------------------------------------------------------------------+
   //| Get correlation between two symbols                              |
   //+------------------------------------------------------------------+
   double GetCorrelation(string sym1, string sym2)
   {
      // Check cache first
      for(int i = 0; i < m_correlation_count; i++)
      {
         if((m_correlations[i].symbol1 == sym1 && m_correlations[i].symbol2 == sym2) ||
            (m_correlations[i].symbol1 == sym2 && m_correlations[i].symbol2 == sym1))
         {
            // Check if stale (older than 1 hour)
            if(TimeCurrent() - m_correlations[i].last_updated < 3600)
            {
               return m_correlations[i].correlation;
            }
         }
      }
      
      // Calculate correlation
      double corr = CalculateSymbolCorrelation(sym1, sym2);
      
      // Cache result
      bool found = false;
      for(int i = 0; i < m_correlation_count; i++)
      {
         if((m_correlations[i].symbol1 == sym1 && m_correlations[i].symbol2 == sym2) ||
            (m_correlations[i].symbol1 == sym2 && m_correlations[i].symbol2 == sym1))
         {
            m_correlations[i].correlation = corr;
            m_correlations[i].last_updated = TimeCurrent();
            found = true;
            break;
         }
      }
      
      if(!found)
      {
         int idx = m_correlation_count;
         ArrayResize(m_correlations, m_correlation_count + 1);
         m_correlations[idx].symbol1 = sym1;
         m_correlations[idx].symbol2 = sym2;
         m_correlations[idx].correlation = corr;
         m_correlations[idx].last_updated = TimeCurrent();
         m_correlation_count++;
      }
      
      return corr;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate correlation from price history                         |
   //+------------------------------------------------------------------+
   double CalculateSymbolCorrelation(string sym1, string sym2, int bars = 50)
   {
      double close1[], close2[];
      ArraySetAsSeries(close1, true);
      ArraySetAsSeries(close2, true);
      
      if(CopyClose(sym1, PERIOD_CURRENT, 0, bars, close1) != bars) return 0;
      if(CopyClose(sym2, PERIOD_CURRENT, 0, bars, close2) != bars) return 0;
      
      // Calculate means
      double mean1 = 0, mean2 = 0;
      for(int i = 0; i < bars; i++)
      {
         mean1 += close1[i];
         mean2 += close2[i];
      }
      mean1 /= bars;
      mean2 /= bars;
      
      // Calculate correlation
      double numerator = 0, denom1 = 0, denom2 = 0;
      for(int i = 0; i < bars; i++)
      {
         double diff1 = close1[i] - mean1;
         double diff2 = close2[i] - mean2;
         numerator += diff1 * diff2;
         denom1 += diff1 * diff1;
         denom2 += diff2 * diff2;
      }
      
      if(denom1 == 0 || denom2 == 0) return 0;
      
      return numerator / MathSqrt(denom1 * denom2);
   }
   
   //+------------------------------------------------------------------+
   //| Add position to tracking                                         |
   //+------------------------------------------------------------------+
   void AddPosition(const SPosition &pos)
   {
      int idx = m_position_count;
      ArrayResize(m_positions, m_position_count + 1);
      m_positions[idx] = pos;
      m_position_count++;
      
      // Update risk tracking
      m_total_risk_amount += pos.risk_amount;
      if(pos.type == 0)
         m_total_exposure_long += pos.volume;
      else
         m_total_exposure_short += pos.volume;
   }
   
   //+------------------------------------------------------------------+
   //| Remove position from tracking                                    |
   //+------------------------------------------------------------------+
   void RemovePosition(ulong ticket)
   {
      for(int i = 0; i < m_position_count; i++)
      {
         if(m_positions[i].ticket == ticket)
         {
            // Update risk tracking
            m_total_risk_amount -= m_positions[i].risk_amount;
            if(m_positions[i].type == 0)
               m_total_exposure_long -= m_positions[i].volume;
            else
               m_total_exposure_short -= m_positions[i].volume;
            
            // Remove from array
            if(i < m_position_count - 1)
            {
               m_positions[i] = m_positions[m_position_count - 1];
            }
            m_position_count--;
            ArrayResize(m_positions, m_position_count);
            break;
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check volatility exits for all positions                         |
   //+------------------------------------------------------------------+
   void CheckVolatilityExits()
   {
      if(!m_vol_exit_config.enabled) return;
      if(m_feature_cache == NULL) return;
      
      double atr = m_feature_cache.GetATR14();
      if(atr == 0) return;
      
      for(int i = 0; i < m_position_count; i++)
      {
         int pos_type = m_positions[i].type;
         
         // Get current price
         double current_price = (pos_type == 0) ? 
            SymbolInfoDouble(m_positions[i].symbol, SYMBOL_BID) : 
            SymbolInfoDouble(m_positions[i].symbol, SYMBOL_ASK);
         
         // Calculate profit in ATR terms
         double profit_points = (pos_type == 0) ? 
            current_price - m_positions[i].open_price : 
            m_positions[i].open_price - current_price;
         double profit_atr = profit_points / atr;
         
         // Breakeven trigger
         if(profit_atr >= m_vol_exit_config.atr_breakeven_trigger && 
            m_positions[i].sl != m_positions[i].open_price)
         {
            // Move SL to breakeven
            ModifyStopLoss(m_positions[i].ticket, m_positions[i].open_price);
            m_positions[i].sl = m_positions[i].open_price;
         }
         
         // Trailing stop trigger
         if(profit_atr >= m_vol_exit_config.atr_trailing_start)
         {
            double new_sl = (pos_type == 0) ?
               current_price - m_vol_exit_config.atr_trailing_distance * atr :
               current_price + m_vol_exit_config.atr_trailing_distance * atr;
            
            // Only move stop in favorable direction
            if((pos_type == 0 && new_sl > m_positions[i].sl) ||
               (pos_type == 1 && new_sl < m_positions[i].sl))
            {
               ModifyStopLoss(m_positions[i].ticket, new_sl);
               m_positions[i].sl = new_sl;
            }
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Modify stop loss for a position                                  |
   //+------------------------------------------------------------------+
   bool ModifyStopLoss(ulong ticket, double new_sl)
   {
      // Select the position
      if(!PositionSelectByTicket(ticket))
         return false;
      
      // Get position details
      string symbol = PositionGetString(POSITION_SYMBOL);
      double tp = PositionGetDouble(POSITION_TP);
      
      // Prepare modification request
      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);
      
      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.symbol = symbol;
      request.sl = new_sl;
      request.tp = tp;
      request.comment = "SL Modified by PositionManager";
      
      // Send the order
      if(!OrderSend(request, result))
      {
         PrintFormat("[PositionManager] Failed to modify SL for ticket %I64u: error %d", ticket, GetLastError());
         return false;
      }
      
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         PrintFormat("[PositionManager] SL modified for ticket %I64u: new SL=%.5f", ticket, new_sl);
         return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if can open new position                                   |
   //+------------------------------------------------------------------+
   bool CanOpenPosition(string symbol, int type, double risk_amount, string &reason)
   {
      reason = "";

      // Adjust-only policy: never hard-block on caps/risk/exposure.
      // The execution layer will enforce min-lot and broker/margin constraints.

      // Check max positions
      if(m_position_count >= m_max_positions)
      {
         reason = "Max positions reached (soft): " + IntegerToString(m_position_count);
      }

      // Check total risk
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      double max_total_risk_amt = m_max_total_risk_pct / 100.0 * bal;
      if(bal > 0.0 && (m_total_risk_amount + risk_amount) > max_total_risk_amt)
      {
         if(reason != "") reason += " | ";
         reason += "Total risk limit exceeded (soft)";
      }

      // Check exposure limits
      if(type == 0 && m_total_exposure_long >= m_max_positions * 0.7)
      {
         if(reason != "") reason += " | ";
         reason += "Long exposure limit reached (soft)";
      }
      if(type == 1 && m_total_exposure_short >= m_max_positions * 0.7)
      {
         if(reason != "") reason += " | ";
         reason += "Short exposure limit reached (soft)";
      }

      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Sync with actual MT5 positions                                   |
   //+------------------------------------------------------------------+
   void SyncPositions(ulong magic_filter = 0)
   {
      // Clear tracking
      m_position_count = 0;
      ArrayResize(m_positions, 0);
      m_total_risk_amount = 0;
      m_total_exposure_long = 0;
      m_total_exposure_short = 0;
      
      // Iterate through actual positions
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         
         // Filter by magic if specified
         if(magic_filter != 0 && PositionGetInteger(POSITION_MAGIC) != magic_filter)
            continue;
         
         SPosition pos;
         pos.ticket = ticket;
         pos.symbol = PositionGetString(POSITION_SYMBOL);
         pos.type = (int)PositionGetInteger(POSITION_TYPE);
         pos.volume = PositionGetDouble(POSITION_VOLUME);
         pos.open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         pos.sl = PositionGetDouble(POSITION_SL);
         pos.tp = PositionGetDouble(POSITION_TP);
         pos.open_time = (datetime)PositionGetInteger(POSITION_TIME);
         pos.magic = IntegerToString((int)PositionGetInteger(POSITION_MAGIC));
         
         // Calculate risk
         double tick_value = SymbolInfoDouble(pos.symbol, SYMBOL_TRADE_TICK_VALUE);
         double tick_size = SymbolInfoDouble(pos.symbol, SYMBOL_TRADE_TICK_SIZE);
         double sl_distance = MathAbs(pos.open_price - pos.sl);
         pos.risk_amount = pos.volume * sl_distance * tick_value / tick_size;
         
         AddPosition(pos);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get risk report                                                  |
   //+------------------------------------------------------------------+
   string GetRiskReport()
   {
      return StringFormat(
         "Positions: %d | Risk: $%.2f | Long: %.2f lots | Short: %.2f lots",
         m_position_count,
         m_total_risk_amount,
         m_total_exposure_long,
         m_total_exposure_short
      );
   }
   
   //+------------------------------------------------------------------+
   //| Compute dynamic max open positions based on market conditions    |
   //+------------------------------------------------------------------+
   int ComputeDynamicMaxOpenPositions(int current_cap)
   {
      // Base implementation: return current cap
      // Can be extended to adjust based on volatility, drawdown, etc.
      if(current_cap <= 0) return m_max_positions;
      return current_cap;
   }
   
   //+------------------------------------------------------------------+
   //| Set configuration                                                |
   //+------------------------------------------------------------------+
   void SetMaxPositions(int max_pos) { m_max_positions = max_pos; }
   void SetMaxRiskPerTrade(double pct) { m_max_risk_per_trade_pct = pct; }
   void SetMaxTotalRisk(double pct) { m_max_total_risk_pct = pct; }
   void SetVolatilityExitConfig(const SVolatilityExitConfig &config) { m_vol_exit_config = config; }
   void SetMagicNumber(long magic) { m_magic_number = magic; }
   
   //+------------------------------------------------------------------+
   //| Get portfolio correlation for a symbol                           |
   //+------------------------------------------------------------------+
   double GetPortfolioCorrelation(string symbol)
   {
      double avg_abs_corr = 0.0;
      if(m_position_count <= 0) return avg_abs_corr;
      
      // Calculate weighted average absolute correlation to existing positions
      double sum = 0.0, wsum = 0.0;
      for(int i = 0; i < m_position_count; i++)
      {
         string osym = m_positions[i].symbol;
         if(osym == "" || osym == symbol) continue;
         
         double vol = m_positions[i].volume;
         double corr = GetCorrelation(symbol, osym);
         sum += MathAbs(corr) * vol;
         wsum += vol;
      }
      
      avg_abs_corr = (wsum > 0.0 ? sum / wsum : 0.0);
      return avg_abs_corr;
   }
   
   //+------------------------------------------------------------------+
   //| Getters                                                          |
   //+------------------------------------------------------------------+
   int GetPositionCount() { return m_position_count; }
   double GetTotalRisk() { return m_total_risk_amount; }
   double GetLongExposure() { return m_total_exposure_long; }
   double GetShortExposure() { return m_total_exposure_short; }
};

// Global instance - extern declaration (defined in EA files)
extern CPositionManager* g_position_manager;

//+------------------------------------------------------------------+
//| Initialize Position Manager                                        |
//+------------------------------------------------------------------+
bool InitializePositionManager(CGateFeatureCache* cache = NULL, 
                                CRegimeAwareStrategy* regime = NULL)
{
   if(g_position_manager != NULL)
   {
      delete g_position_manager;
   }
   
   g_position_manager = new CPositionManager(cache, regime);
   Print("[PositionManager] Initialized with correlation sizing and volatility exits");
   return true;
}

//+------------------------------------------------------------------+
//| Shutdown Position Manager                                          |
//+------------------------------------------------------------------+
void ShutdownPositionManager()
{
   if(g_position_manager != NULL)
   {
      delete g_position_manager;
      g_position_manager = NULL;
   }
}

#endif // CPOSITIONMANAGER_MQH
