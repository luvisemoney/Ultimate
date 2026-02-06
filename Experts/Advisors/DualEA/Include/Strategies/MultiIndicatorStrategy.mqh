#include "..\IStrategy.mqh"
#include "..\KnowledgeBase.mqh"
#include "..\TradeManager.mqh"

class CMultiIndicatorStrategy : public IStrategy
{
private:
   // Indicator parameters
   int m_rsiPeriod, m_macdFast, m_macdSlow, m_macdSignal;
   int m_stochK, m_stochD, m_stochSlow;
   int m_cciPeriod, m_williamsPeriod;
   int m_momentumPeriod, m_rocPeriod;
   int m_schaffPeriod, m_vortexPeriod;
   
   // Cached indicator values
   double m_rsi, m_macd_main, m_macd_signal;
   double m_stoch_k, m_stoch_d;
   double m_cci, m_williams;
   double m_momentum, m_roc;
   double m_schaff, m_vortex_plus, m_vortex_minus;
   double m_close0, m_close1;
   
   // Score calculation
   double m_bullish_score, m_bearish_score;
   int m_min_score_threshold;
   
public:
   CMultiIndicatorStrategy(const string symbol, const ENUM_TIMEFRAMES tf) : IStrategy("MultiIndicatorStrategy", symbol, tf)
   {
      // Initialize parameters
      m_rsiPeriod = 14; m_macdFast = 12; m_macdSlow = 26; m_macdSignal = 9;
      m_stochK = 14; m_stochD = 3; m_stochSlow = 3;
      m_cciPeriod = 14; m_williamsPeriod = 14;
      m_momentumPeriod = 14; m_rocPeriod = 14;
      m_schaffPeriod = 23; m_vortexPeriod = 14;
      m_min_score_threshold = 3;
      
      ResetValues();
   }
   
   virtual string Name() { return "MultiIndicatorStrategy"; }
   
   void ResetValues()
   {
      m_rsi = m_macd_main = m_macd_signal = 0;
      m_stoch_k = m_stoch_d = 0;
      m_cci = m_williams = 0;
      m_momentum = m_roc = 0;
      m_schaff = m_vortex_plus = m_vortex_minus = 0;
      m_close0 = m_close1 = 0;
      m_bullish_score = m_bearish_score = 0;
   }
   
   virtual void Refresh()
   {
      ResetValues();
      m_close0 = iClose(m_symbol, m_timeframe, 0);
      m_close1 = iClose(m_symbol, m_timeframe, 1);
      
      // RSI
      double rsi_buffer[];
      int rsi_handle = iRSI(m_symbol, m_timeframe, m_rsiPeriod, PRICE_CLOSE);
      if(rsi_handle > 0 && CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer) == 1)
         m_rsi = rsi_buffer[0];
      
      // MACD
      double macd_main[], macd_signal[];
      int macd_handle = iMACD(m_symbol, m_timeframe, m_macdFast, m_macdSlow, m_macdSignal, PRICE_CLOSE);
      if(macd_handle > 0)
      {
         CopyBuffer(macd_handle, 0, 0, 1, macd_main);
         CopyBuffer(macd_handle, 1, 0, 1, macd_signal);
         m_macd_main = macd_main[0];
         m_macd_signal = macd_signal[0];
      }
      
      // Stochastic
      double stoch_k[], stoch_d[];
      int stoch_handle = iStochastic(m_symbol, m_timeframe, m_stochK, m_stochD, m_stochSlow, MODE_SMA, STO_LOWHIGH);
      if(stoch_handle > 0)
      {
         CopyBuffer(stoch_handle, 0, 0, 1, stoch_k);
         CopyBuffer(stoch_handle, 1, 0, 1, stoch_d);
         m_stoch_k = stoch_k[0];
         m_stoch_d = stoch_d[0];
      }
      
      // CCI
      double cci_buffer[];
      int cci_handle = iCCI(m_symbol, m_timeframe, m_cciPeriod, PRICE_TYPICAL);
      if(cci_handle > 0 && CopyBuffer(cci_handle, 0, 0, 1, cci_buffer) == 1)
         m_cci = cci_buffer[0];
      
      // Williams %R
      double williams_buffer[];
      int williams_handle = iWPR(m_symbol, m_timeframe, m_williamsPeriod);
      if(williams_handle > 0 && CopyBuffer(williams_handle, 0, 0, 1, williams_buffer) == 1)
         m_williams = williams_buffer[0];
      
      // Momentum
      double momentum_buffer[];
      int momentum_handle = iMomentum(m_symbol, m_timeframe, m_momentumPeriod, PRICE_CLOSE);
      if(momentum_handle > 0 && CopyBuffer(momentum_handle, 0, 0, 1, momentum_buffer) == 1)
         m_momentum = momentum_buffer[0];
      
      // ROC (manual): ((Close(0) - Close(period)) / Close(period)) * 100
      double close_now = iClose(m_symbol, m_timeframe, 0);
      double close_n   = iClose(m_symbol, m_timeframe, m_rocPeriod);
      if(close_n!=0.0)
         m_roc = 100.0 * (close_now - close_n) / close_n;
      
      // Calculate composite scores
      CalculateScores();
   }
   
   void CalculateScores()
   {
      m_bullish_score = 0;
      m_bearish_score = 0;
      
      // RSI scoring
      if(m_rsi < 30) m_bullish_score += 1;
      else if(m_rsi > 70) m_bearish_score += 1;
      
      // MACD scoring
      if(m_macd_main > m_macd_signal && m_macd_main > 0) m_bullish_score += 1;
      else if(m_macd_main < m_macd_signal && m_macd_main < 0) m_bearish_score += 1;
      
      // Stochastic scoring
      if(m_stoch_k < 20 && m_stoch_k > m_stoch_d) m_bullish_score += 1;
      else if(m_stoch_k > 80 && m_stoch_k < m_stoch_d) m_bearish_score += 1;
      
      // CCI scoring
      if(m_cci < -100) m_bullish_score += 1;
      else if(m_cci > 100) m_bearish_score += 1;
      
      // Williams %R scoring
      if(m_williams < -80) m_bullish_score += 1;
      else if(m_williams > -20) m_bearish_score += 1;
      
      // Momentum scoring
      if(m_momentum > 100) m_bullish_score += 1;
      else if(m_momentum < 100) m_bearish_score += 1;
      
      // ROC scoring
      if(m_roc > 0) m_bullish_score += 1;
      else if(m_roc < 0) m_bearish_score += 1;
   }
   
   virtual TradeOrder CheckSignal()
   {
      TradeOrder ord; ord.strategy_name = Name();
      
      // Strong consensus required
      if(m_bullish_score >= m_min_score_threshold)
      {
         ord.action = ACTION_BUY;
         ord.order_type = ORDER_TYPE_BUY;
         ord.stop_loss = m_close0 - 40 * _Point;
         ord.take_profit = m_close0 + 120 * _Point;
         ord.trailing_enabled = true;
         ord.trailing_type = TRAIL_FIXED_POINTS;
         ord.trail_activation_points = 20;
         ord.trail_distance_points = 15;
         ord.trail_step_points = 5;
         return ord;
      }
      else if(m_bearish_score >= m_min_score_threshold)
      {
         ord.action = ACTION_SELL;
         ord.order_type = ORDER_TYPE_SELL;
         ord.stop_loss = m_close0 + 40 * _Point;
         ord.take_profit = m_close0 - 120 * _Point;
         ord.trailing_enabled = true;
         ord.trailing_type = TRAIL_FIXED_POINTS;
         ord.trail_activation_points = 20;
         ord.trail_distance_points = 15;
         ord.trail_step_points = 5;
         return ord;
      }
      
      return ord;
   }
   
   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
   {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      (*kb).WriteKV(ts, m_symbol, Name(), "rsi", m_rsi);
      (*kb).WriteKV(ts, m_symbol, Name(), "macd_main", m_macd_main);
      (*kb).WriteKV(ts, m_symbol, Name(), "macd_signal", m_macd_signal);
      (*kb).WriteKV(ts, m_symbol, Name(), "stoch_k", m_stoch_k);
      (*kb).WriteKV(ts, m_symbol, Name(), "stoch_d", m_stoch_d);
      (*kb).WriteKV(ts, m_symbol, Name(), "cci", m_cci);
      (*kb).WriteKV(ts, m_symbol, Name(), "williams", m_williams);
      (*kb).WriteKV(ts, m_symbol, Name(), "momentum", m_momentum);
      (*kb).WriteKV(ts, m_symbol, Name(), "roc", m_roc);
      (*kb).WriteKV(ts, m_symbol, Name(), "bullish_score", m_bullish_score);
      (*kb).WriteKV(ts, m_symbol, Name(), "bearish_score", m_bearish_score);
   }
};
