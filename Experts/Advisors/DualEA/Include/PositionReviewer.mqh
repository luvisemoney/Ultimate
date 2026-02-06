//+------------------------------------------------------------------+
//| PositionReviewer.mqh                                             |
//| Purpose: Continuous position re-evaluation and adaptive mgmt     |
//| Features: Review open positions every 5 min, close/adjust        |
//+------------------------------------------------------------------+
#ifndef __POSITIONREVIEWER_MQH__
#define __POSITIONREVIEWER_MQH__

#include "AdaptiveSignalOptimizer.mqh"
#include "GateSystemAutoLearning.mqh"
#include <Trade/Trade.mqh>

// Position review decision
enum PositionAction
{
   PA_HOLD,              // Keep position as-is
   PA_CLOSE,             // Close position immediately
   PA_ADJUST_SL,         // Tighten/widen stop loss
   PA_ADJUST_TP,         // Adjust take profit
   PA_SCALE_OUT_HALF,    // Close 50% of position
   PA_REVERSE            // Close and open opposite position
};

// Review result
struct PositionReview
{
   string position_id;
   datetime review_time;
   PositionAction action;
   string reason;
   double current_pnl;
   double current_pnl_pct;
   
   // Signal re-evaluation
   double new_signal_confidence;
   string new_signal_direction;  // "same", "opposite", "neutral"
   
   // Market condition changes
   string current_regime;
   double current_volatility;
   bool conditions_deteriorated;
   
   // Adjustment details
   double new_sl;
   double new_tp;
   double close_volume;
};

//+------------------------------------------------------------------+
//| Position Reviewer - Living Trade Management                     |
//+------------------------------------------------------------------+
class CPositionReviewer
{
private:
   CEfficientGateManagerEnhanced* m_gate_manager;
   CAdaptiveSignalOptimizer* m_optimizer;
   
   int m_review_interval_seconds;
   datetime m_last_review_time;
   
   // Statistics
   int m_total_reviews;
   int m_positions_closed;
   int m_positions_adjusted;
   int m_positions_held;
   
   // Review thresholds
   double m_min_pnl_to_close;        // Close if profit exceeds this
   double m_max_loss_to_close;       // Close if loss exceeds this
   double m_signal_reversal_threshold; // Close if confidence flips
   
   // Evaluate current market conditions for a position
   bool EvaluateMarketConditions(const string symbol, const int timeframe,
                                  string &regime, double &volatility)
   {
      // Get current regime
      regime = GetMarketRegimeForReview(symbol, timeframe);
      
      // Get current volatility
      int atr_handle = iATR(symbol, (ENUM_TIMEFRAMES)timeframe, 14);
      double atr_array[1];
      if(CopyBuffer(atr_handle, 0, 0, 1, atr_array) != 1)
         return false;
      
      double price = 0;
      if(!SymbolInfoDouble(symbol, SYMBOL_BID, price))
         return false;
      
      volatility = atr_array[0] / price;
      return true;
   }
   
   // Simple regime detection for review
   string GetMarketRegimeForReview(const string symbol, const int timeframe)
   {
      int adx_handle = iADX(symbol, (ENUM_TIMEFRAMES)timeframe, 14);
      double adx_array[1];
      
      if(CopyBuffer(adx_handle, 0, 0, 1, adx_array) == 1)
      {
         double adx = adx_array[0];
         if(adx > 25.0)
            return "trending";
         else
            return "ranging";
      }
      
      return "unknown";
   }

public:
   CPositionReviewer(CEfficientGateManagerEnhanced* gate_mgr, CAdaptiveSignalOptimizer* optimizer,
                     int review_interval_seconds = 300)
   {
      m_gate_manager = gate_mgr;
      m_optimizer = optimizer;
      m_review_interval_seconds = review_interval_seconds;
      m_last_review_time = 0;
      
      // Initialize statistics
      m_total_reviews = 0;
      m_positions_closed = 0;
      m_positions_adjusted = 0;
      m_positions_held = 0;
      
      // Default thresholds
      m_min_pnl_to_close = 2.0;          // Close if +2% profit
      m_max_loss_to_close = -1.0;        // Close if -1% loss
      m_signal_reversal_threshold = 0.4; // Close if confidence drops below 0.4
      
      PrintFormat("🔄 PositionReviewer initialized: Review every %d seconds (%.1f min)",
                  m_review_interval_seconds, m_review_interval_seconds / 60.0);
   }
   
   // Check if it's time to review positions
   bool IsReviewTime()
   {
      datetime now = TimeCurrent();
      if(now - m_last_review_time >= m_review_interval_seconds)
      {
         m_last_review_time = now;
         return true;
      }
      return false;
   }
   
   // NOTE: ReviewPaperPosition removed - now using real MT5 positions
   // Use PositionGetDouble(), PositionSelectByTicket() instead
   /*
   PositionReview ReviewPaperPosition_DEPRECATED(void* position, 
                                      IStrategy* strategy,
                                      const string strategy_name)
   {
      PositionReview review;
      review.position_id = IntegerToString(position.ticket);
      review.review_time = TimeCurrent();
      review.action = PA_HOLD;  // Default action
      review.reason = "Position OK";
      
      m_total_reviews++;
      
      // Calculate current PnL
      double current_price = 0;
      if(position.type == ORDER_TYPE_BUY)
         SymbolInfoDouble(position.symbol, SYMBOL_BID, current_price);
      else
         SymbolInfoDouble(position.symbol, SYMBOL_ASK, current_price);
      
      double pnl = (position.type == ORDER_TYPE_BUY) ? 
                   (current_price - position.open_price) * position.volume :
                   (position.open_price - current_price) * position.volume;
      
      double pnl_pct = (pnl / (position.open_price * position.volume)) * 100.0;
      
      review.current_pnl = pnl;
      review.current_pnl_pct = pnl_pct;
      
      // Evaluate market conditions
      string current_regime;
      double current_volatility;
      EvaluateMarketConditions(position.symbol, position.timeframe, 
                               current_regime, current_volatility);
      
      review.current_regime = current_regime;
      review.current_volatility = current_volatility;
      
      // DECISION LOGIC
      
      // 1. Profit target reached?
      if(pnl_pct >= m_min_pnl_to_close)
      {
         review.action = PA_CLOSE;
         review.reason = StringFormat("Profit target reached: %.2f%%", pnl_pct);
         m_positions_closed++;
         return review;
      }
      
      // 2. Stop loss hit?
      if(pnl_pct <= m_max_loss_to_close)
      {
         review.action = PA_CLOSE;
         review.reason = StringFormat("Stop loss hit: %.2f%%", pnl_pct);
         m_positions_closed++;
         return review;
      }
      
      // 3. Re-evaluate signal using strategy
      if(strategy != NULL)
      {
         TradingSignal new_signal;
         new_signal.Init();  // CRITICAL: Initialize all fields to safe defaults
         new_signal.symbol = position.symbol;
         new_signal.timeframe = position.timeframe;
         new_signal.timestamp = TimeCurrent();
         
         // Generate fresh signal
         bool should_trade = false;
         int signal_type = -1;
         double confidence = 0.0;
         
         should_trade = strategy.ShouldTrade(signal_type, confidence);
         
         review.new_signal_confidence = confidence;
         
         if(!should_trade || confidence < m_signal_reversal_threshold)
         {
            review.action = PA_CLOSE;
            review.reason = StringFormat("Signal confidence dropped: %.2f (was: %.2f)",
                                        confidence, position.confidence);
            review.new_signal_direction = "weak";
            m_positions_closed++;
            return review;
         }
         
         // Check if signal reversed direction
         bool signal_reversed = false;
         if(position.type == ORDER_TYPE_BUY && signal_type == 1)  // Was buy, now sell
            signal_reversed = true;
         if(position.type == ORDER_TYPE_SELL && signal_type == 0) // Was sell, now buy
            signal_reversed = true;
         
         if(signal_reversed)
         {
            review.action = PA_CLOSE;
            review.reason = "Signal reversed direction";
            review.new_signal_direction = "opposite";
            m_positions_closed++;
            return review;
         }
         
         review.new_signal_direction = "same";
      }
      
      // 4. Volatility spike?
      if(current_volatility > 0.03)  // 3% volatility
      {
         review.action = PA_ADJUST_SL;
         review.reason = "High volatility detected, tightening stop";
         
         // Tighten stop loss by 20%
         double sl_distance = MathAbs(current_price - position.sl);
         review.new_sl = (position.type == ORDER_TYPE_BUY) ?
                         current_price - (sl_distance * 0.8) :
                         current_price + (sl_distance * 0.8);
         review.new_tp = position.tp;
         
         m_positions_adjusted++;
         return review;
      }
      
      // 5. Regime change?
      if(review.current_regime != position.regime && review.current_regime != "unknown")
      {
         // Regime changed - adjust expectations
         if(current_regime == "ranging" && pnl_pct > 0.5)
         {
            review.action = PA_SCALE_OUT_HALF;
            review.reason = "Regime changed to ranging, taking partial profit";
            review.close_volume = position.volume * 0.5;
            m_positions_adjusted++;
            return review;
         }
      }
      
      // 6. Position holding well - trail stop if in profit
      if(pnl_pct > 1.0)  // 1% profit
      {
         review.action = PA_ADJUST_SL;
         review.reason = StringFormat("Trailing stop - profit: %.2f%%", pnl_pct);
         
         // Trail at 50% of current profit
         double trail_distance = MathAbs(current_price - position.open_price) * 0.5;
         review.new_sl = (position.type == ORDER_TYPE_BUY) ?
                         current_price - trail_distance :
                         current_price + trail_distance;
         review.new_tp = position.tp;
         
         m_positions_adjusted++;
         return review;
      }
      
      // Default: HOLD
      m_positions_held++;
      review.action = PA_HOLD;
      review.reason = StringFormat("Position healthy: PnL=%.2f%%, Conf=%.2f",
                                   pnl_pct, review.new_signal_confidence);
      
      return review;
   }
   */  // End of deprecated CPaperPosition functions
   
   // NOTE: ApplyReviewDecision removed - now using real MT5 position modifications
   // Use TradeManager::ModifyPosition() instead
   /*
   bool ApplyReviewDecision_DEPRECATED(void* position, const PositionReview &review)
   {
      if(position == NULL) return false;
      
      switch(review.action)
      {
         case PA_CLOSE:
            // Close position
            position.status = "closed";
            position.close_time = TimeCurrent();
            
            double close_price = 0;
            if(position.type == ORDER_TYPE_BUY)
               SymbolInfoDouble(position.symbol, SYMBOL_BID, close_price);
            else
               SymbolInfoDouble(position.symbol, SYMBOL_ASK, close_price);
            
            position.close_price = close_price;
            position.pnl = review.current_pnl;
            
            PrintFormat("🔴 CLOSED Position #%d: %s (PnL: %.2f%%)",
                       position.ticket, review.reason, review.current_pnl_pct);
            return true;
            
         case PA_ADJUST_SL:
            position.sl = review.new_sl;
            PrintFormat("📊 ADJUSTED SL Position #%d: %.5f → %.5f (%s)",
                       position.ticket, position.sl, review.new_sl, review.reason);
            return true;
            
         case PA_ADJUST_TP:
            position.tp = review.new_tp;
            PrintFormat("📊 ADJUSTED TP Position #%d: %.5f → %.5f (%s)",
                       position.ticket, position.tp, review.new_tp, review.reason);
            return true;
            
         case PA_SCALE_OUT_HALF:
            position.volume *= 0.5;
            PrintFormat("📉 SCALED OUT 50%% Position #%d: %s",
                       position.ticket, review.reason);
            return true;
            
         case PA_HOLD:
            // Do nothing
            return true;
            
         default:
            return false;
      }
   }
   */  // End of deprecated ApplyReviewDecision
   
   // Get statistics
   void GetStatistics(int &total, int &closed, int &adjusted, int &held)
   {
      total = m_total_reviews;
      closed = m_positions_closed;
      adjusted = m_positions_adjusted;
      held = m_positions_held;
   }
   
   // Print review report
   void PrintReport()
   {
      PrintFormat("\n=== 🔄 Position Review Report ===");
      PrintFormat("Total Reviews: %d", m_total_reviews);
      PrintFormat("Positions Closed: %d (%.1f%%)", m_positions_closed,
                  m_total_reviews > 0 ? (double)m_positions_closed/m_total_reviews*100 : 0);
      PrintFormat("Positions Adjusted: %d (%.1f%%)", m_positions_adjusted,
                  m_total_reviews > 0 ? (double)m_positions_adjusted/m_total_reviews*100 : 0);
      PrintFormat("Positions Held: %d (%.1f%%)", m_positions_held,
                  m_total_reviews > 0 ? (double)m_positions_held/m_total_reviews*100 : 0);
      PrintFormat("================================\n");
   }
   
   // Configuration methods
   void SetProfitTarget(double pct) { m_min_pnl_to_close = pct; }
   void SetStopLoss(double pct) { m_max_loss_to_close = pct; }
   void SetSignalThreshold(double threshold) { m_signal_reversal_threshold = threshold; }
};

#endif
