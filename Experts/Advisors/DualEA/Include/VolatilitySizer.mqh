//+------------------------------------------------------------------+
//| VolatilitySizer.mqh                                              |
//| FR-06: Volatility Position Sizing Module                        |
//+------------------------------------------------------------------+
#property copyright "DualEA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Volatility-based position sizing calculator                     |
//+------------------------------------------------------------------+
class CVolatilitySizer
{
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   
   // Configuration
   bool m_enabled;
   int m_atr_period;
   double m_base_atr_pct;
   double m_min_multiplier;
   double m_max_multiplier;
   double m_target_risk_pct;
   
public:
   CVolatilitySizer(const string symbol, const ENUM_TIMEFRAMES timeframe) :
      m_symbol(symbol), m_timeframe(timeframe), m_enabled(false),
      m_atr_period(14), m_base_atr_pct(1.0), m_min_multiplier(0.1), 
      m_max_multiplier(3.0), m_target_risk_pct(1.0) {}
   
   // Configuration methods
   void SetEnabled(const bool enabled) { m_enabled = enabled; }
   void SetATRPeriod(const int period) { m_atr_period = period; }
   void SetBaseATRPercent(const double pct) { m_base_atr_pct = pct; }
   void SetMultiplierRange(const double min_mult, const double max_mult) 
   { 
      m_min_multiplier = min_mult; 
      m_max_multiplier = max_mult; 
   }
   void SetTargetRiskPercent(const double risk_pct) { m_target_risk_pct = risk_pct; }
   
   // Main sizing calculation
   double CalculateSizeMultiplier(double &atr_pct_out, string &reason)
   {
      reason = "ok";
      atr_pct_out = 0.0;
      
      if(!m_enabled)
      {
         reason = "vol_sizer_disabled";
         return 1.0; // Neutral multiplier
      }
      
      // Get current ATR
      int atr_handle = iATR(m_symbol, m_timeframe, m_atr_period);
      if(atr_handle == INVALID_HANDLE)
      {
         reason = "atr_handle_failed";
         return 1.0;
      }
      
      double atr_buf[1];
      int copied = CopyBuffer(atr_handle, 0, 0, 1, atr_buf);
      IndicatorRelease(atr_handle);
      
      if(copied != 1)
      {
         reason = "atr_copy_failed";
         return 1.0;
      }
      
      double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      if(current_price <= 0.0 || atr_buf[0] <= 0.0)
      {
         reason = "invalid_price_or_atr";
         return 1.0;
      }
      
      // Calculate ATR as percentage of price
      atr_pct_out = 100.0 * atr_buf[0] / current_price;
      
      // Calculate volatility multiplier
      // Higher volatility = smaller position size (inverse relationship)
      double vol_ratio = m_base_atr_pct / atr_pct_out;
      double multiplier = MathSqrt(vol_ratio); // Square root for smoother scaling
      
      // Apply bounds
      multiplier = MathMax(m_min_multiplier, MathMin(m_max_multiplier, multiplier));
      
      reason = StringFormat("atr_pct=%.2f vol_ratio=%.3f", atr_pct_out, vol_ratio);
      return multiplier;
   }
   
   // Calculate position size based on account equity and risk
   double CalculatePositionSize(const double base_lot_size, const double stop_loss_points,
                               double &final_multiplier, string &reason)
   {
      double atr_pct;
      final_multiplier = CalculateSizeMultiplier(atr_pct, reason);
      
      if(!m_enabled)
         return base_lot_size;
      
      // Risk-based sizing if stop loss is provided
      if(stop_loss_points > 0.0 && m_target_risk_pct > 0.0)
      {
         double account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
         double risk_amount = account_equity * m_target_risk_pct / 100.0;
         
         double point_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
         double risk_per_lot = stop_loss_points * point_value;
         
         if(risk_per_lot > 0.0)
         {
            double risk_based_size = risk_amount / risk_per_lot;
            double vol_adjusted_size = risk_based_size * final_multiplier;
            
            reason = StringFormat("%s risk_based=%.2f", reason, risk_based_size);
            return MathMax(0.01, vol_adjusted_size); // Minimum lot size
         }
      }
      
      // Fallback to base size with volatility adjustment
      return MathMax(0.01, base_lot_size * final_multiplier);
   }
};
