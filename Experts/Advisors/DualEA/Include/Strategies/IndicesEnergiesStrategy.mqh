#include "..\IStrategy.mqh"
#include "..\KnowledgeBase.mqh"
#include "..\TradeManager.mqh"

class CIndicesEnergiesStrategy : public IStrategy
{
private:
   string           m_symbol;
   ENUM_TIMEFRAMES  m_tf;
   
   // Multi-timeframe analysis
   int m_fastTF, m_mediumTF, m_slowTF;
   
   // Indicators for indices/energies
   int m_vwapPeriod;
   int m_fractalPeriod;
   int m_envelopePeriod;
   double m_envelopeDeviation;
   
   // Cached values
   double m_vwap, m_fractal_up, m_fractal_down;
   double m_envelope_upper, m_envelope_lower;
   double m_close0, m_close1;
   
public:
   CIndicesEnergiesStrategy(const string symbol, const ENUM_TIMEFRAMES tf)
   {
      m_symbol = symbol; m_tf = tf;
      
      m_vwapPeriod = 24; // Daily VWAP for intraday
      m_fractalPeriod = 5;
      m_envelopePeriod = 20;
      m_envelopeDeviation = 0.1; // 10% envelope
      
      ResetValues();
   }
   
   virtual string Name() { return "IndicesEnergiesStrategy"; }
   
   void ResetValues()
   {
      m_vwap = m_fractal_up = m_fractal_down = 0;
      m_envelope_upper = m_envelope_lower = 0;
      m_close0 = m_close1 = 0;
   }
   
   virtual void Refresh()
   {
      ResetValues();
      m_close0 = iClose(m_symbol, m_tf, 0);
      m_close1 = iClose(m_symbol, m_tf, 1);
      
      // VWAP calculation (simplified)
      double typical_price = (iHigh(m_symbol, m_tf, 0) + iLow(m_symbol, m_tf, 0) + iClose(m_symbol, m_tf, 0)) / 3;
      double volume = (double)iVolume(m_symbol, m_tf, 0);
      
      // For now, use a moving average as VWAP proxy
      double vwap_buffer[];
      int vwap_handle = iMA(m_symbol, m_tf, m_vwapPeriod, 0, MODE_SMA, PRICE_TYPICAL);
      if(vwap_handle > 0) CopyBuffer(vwap_handle, 0, 0, 1, vwap_buffer);
      m_vwap = vwap_buffer[0];
      
      // Fractals
      double fractal_up_buffer[], fractal_down_buffer[];
      int fractal_handle = iFractals(m_symbol, m_tf);
      if(fractal_handle > 0)
      {
         CopyBuffer(fractal_handle, 0, 0, 1, fractal_up_buffer);
         CopyBuffer(fractal_handle, 1, 0, 1, fractal_down_buffer);
         m_fractal_up = fractal_up_buffer[0];
         m_fractal_down = fractal_down_buffer[0];
      }
      
      // Envelope
      double envelope_upper[], envelope_lower[];
      int envelope_handle = iEnvelopes(m_symbol, m_tf, m_envelopePeriod, 0, MODE_SMA, PRICE_CLOSE, m_envelopeDeviation);
      if(envelope_handle > 0)
      {
         CopyBuffer(envelope_handle, 0, 0, 1, envelope_upper);
         CopyBuffer(envelope_handle, 1, 0, 1, envelope_lower);
         m_envelope_upper = envelope_upper[0];
         m_envelope_lower = envelope_lower[0];
      }
   }
   
   virtual TradeOrder CheckSignal()
   {
      TradeOrder ord; ord.strategy_name = Name();
      
      // Skip if insufficient data
      if(m_vwap <= 0 || m_envelope_upper <= 0) return ord;
      
      // VWAP-based strategies
      double vwap_distance = (m_close0 - m_vwap) / m_vwap * 100;
      
      // Fractal breakout strategy
      bool fractal_breakout_up = m_close0 > m_fractal_up && m_fractal_up > 0;
      bool fractal_breakout_down = m_close0 < m_fractal_down && m_fractal_down > 0;
      
      // Envelope strategies
      bool near_upper_envelope = m_close0 >= m_envelope_upper * 0.98;
      bool near_lower_envelope = m_close0 <= m_envelope_lower * 1.02;
      
      // Volume spike confirmation
      double volume = (double)iVolume(m_symbol, m_tf, 0);
      double volume_ma = 0;
      double volume_ma_buffer[];
      int volume_ma_handle = iMA(m_symbol, m_tf, 20, 0, MODE_SMA, VOLUME_TICK);
      if(volume_ma_handle > 0) CopyBuffer(volume_ma_handle, 0, 0, 1, volume_ma_buffer);
      volume_ma = volume_ma_buffer[0];
      
      bool volume_spike = volume > volume_ma * 1.5;
      
      // Long setup: VWAP reversion + fractal breakout
      if(vwap_distance < -2.0 && near_lower_envelope && volume_spike)
      {
         ord.action = ACTION_BUY;
         ord.order_type = ORDER_TYPE_BUY;
         ord.stop_loss = m_envelope_lower * 0.99;
         ord.take_profit = m_vwap;
         ord.trailing_enabled = true;
         ord.trailing_type = TRAIL_FIXED_POINTS;
         ord.trail_activation_points = 10;
         ord.trail_distance_points = 8;
         ord.trail_step_points = 3;
         return ord;
      }
      
      // Short setup: VWAP reversion + fractal breakout
      else if(vwap_distance > 2.0 && near_upper_envelope && volume_spike)
      {
         ord.action = ACTION_SELL;
         ord.order_type = ORDER_TYPE_SELL;
         ord.stop_loss = m_envelope_upper * 1.01;
         ord.take_profit = m_vwap;
         ord.trailing_enabled = true;
         ord.trailing_type = TRAIL_FIXED_POINTS;
         ord.trail_activation_points = 10;
         ord.trail_distance_points = 8;
         ord.trail_step_points = 3;
         return ord;
      }
      
      // Fractal breakout strategy
      else if(fractal_breakout_up && volume_spike)
      {
         ord.action = ACTION_BUY;
         ord.order_type = ORDER_TYPE_BUY;
         ord.stop_loss = m_fractal_up * 0.995;
         ord.take_profit = m_fractal_up + (m_fractal_up - m_fractal_down) * 0.5;
         return ord;
      }
      else if(fractal_breakout_down && volume_spike)
      {
         ord.action = ACTION_SELL;
         ord.order_type = ORDER_TYPE_SELL;
         ord.stop_loss = m_fractal_down * 1.005;
         ord.take_profit = m_fractal_down - (m_fractal_up - m_fractal_down) * 0.5;
         return ord;
      }
      
      return ord;
   }
   
   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
   {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      
      double vwap_distance = (m_close0 - m_vwap) / m_vwap * 100;
      
      (*kb).WriteKV(ts, m_symbol, Name(), "vwap_distance_pct", vwap_distance);
      (*kb).WriteKV(ts, m_symbol, Name(), "envelope_position", 
                   (m_close0 - m_envelope_lower) / (m_envelope_upper - m_envelope_lower));
      (*kb).WriteKV(ts, m_symbol, Name(), "fractal_range", 
                   MathAbs(m_fractal_up - m_fractal_down));
   }
};
