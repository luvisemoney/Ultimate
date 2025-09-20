#include "..\IStrategy.mqh"
#include "..\KnowledgeBase.mqh"
#include "..\TradeManager.mqh"

class CGoldVolatilityStrategy : public IStrategy
{
private:
   string           m_symbol;
   ENUM_TIMEFRAMES  m_tf;
   
   // Gold-specific parameters
   int m_atrPeriod;
   int m_bollingerPeriod;
   double m_bollingerDeviation;
   int m_volumeMAPeriod;
   
   // Cached values
   double m_atr, m_bb_upper, m_bb_lower, m_bb_middle;
   double m_volume, m_volume_ma;
   double m_close0, m_close1;
   
public:
   CGoldVolatilityStrategy(const string symbol, const ENUM_TIMEFRAMES tf)
   {
      m_symbol = symbol; m_tf = tf;
      m_atrPeriod = 14;
      m_bollingerPeriod = 20;
      m_bollingerDeviation = 2.0;
      m_volumeMAPeriod = 20;
      
      ResetValues();
   }
   
   virtual string Name() { return "GoldVolatilityStrategy"; }
   
   void ResetValues()
   {
      m_atr = m_bb_upper = m_bb_lower = m_bb_middle = 0;
      m_volume = m_volume_ma = 0;
      m_close0 = m_close1 = 0;
   }
   
   virtual void Refresh()
   {
      ResetValues();
      m_close0 = iClose(m_symbol, m_tf, 0);
      m_close1 = iClose(m_symbol, m_tf, 1);
      
      // ATR for volatility measurement
      double atr_buffer[];
      int atr_handle = iATR(m_symbol, m_tf, m_atrPeriod);
      if(atr_handle > 0 && CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) == 1)
         m_atr = atr_buffer[0];
      
      // Bollinger Bands
      double bb_upper[], bb_middle[], bb_lower[];
      int period_bb = (int)m_bollingerPeriod;
      int deviation_bb = (int)MathRound(m_bollingerDeviation); // align with iBands signature in this terminal build
      int shift_bb = 0;
      int price_bb = (int)PRICE_CLOSE;
      int bb_handle = iBands(m_symbol, m_tf, period_bb, deviation_bb, shift_bb, price_bb);
      if(bb_handle > 0)
      {
         CopyBuffer(bb_handle, 0, 0, 1, bb_upper);
         CopyBuffer(bb_handle, 1, 0, 1, bb_middle);
         CopyBuffer(bb_handle, 2, 0, 1, bb_lower);
         
         m_bb_upper = bb_upper[0];
         m_bb_middle = bb_middle[0];
         m_bb_lower = bb_lower[0];
      }
      
      // Volume analysis
      double volume_buffer[];
      m_volume = (double)iVolume(m_symbol, m_tf, 0);
      
      // Simple volume MA
      double volume_ma_buffer[];
      int volume_ma_handle = iMA(m_symbol, m_tf, m_volumeMAPeriod, 0, MODE_SMA, VOLUME_TICK);
      if(volume_ma_handle > 0 && CopyBuffer(volume_ma_handle, 0, 0, 1, volume_ma_buffer) == 1)
         m_volume_ma = volume_ma_buffer[0];
   }
   
   virtual TradeOrder CheckSignal()
   {
      TradeOrder ord; ord.strategy_name = Name();
      
      // Skip if insufficient data
      if(m_atr <= 0 || m_bb_upper <= 0) return ord;
      
      // Gold-specific volatility breakout strategy
      double bb_width = m_bb_upper - m_bb_lower;
      double bb_position = (m_close0 - m_bb_lower) / bb_width;
      
      // Volume confirmation
      bool high_volume = m_volume > m_volume_ma * 1.5;
      
      // Bollinger Band squeeze breakout
      bool squeeze_condition = bb_width < m_atr * 2.0;
      
      // Long setup: breakout above upper band with volume
      if(m_close0 > m_bb_upper && high_volume && !squeeze_condition)
      {
         ord.action = ACTION_BUY;
         ord.order_type = ORDER_TYPE_BUY;
         ord.stop_loss = m_bb_middle;
         ord.take_profit = m_close0 + m_atr * 2;
         ord.trailing_enabled = true;
         ord.trailing_type = TRAIL_ATR;
         ord.atr_period = m_atrPeriod;
         ord.atr_multiplier = 1.5;
         return ord;
      }
      
      // Short setup: breakdown below lower band with volume
      else if(m_close0 < m_bb_lower && high_volume && !squeeze_condition)
      {
         ord.action = ACTION_SELL;
         ord.order_type = ORDER_TYPE_SELL;
         ord.stop_loss = m_bb_middle;
         ord.take_profit = m_close0 - m_atr * 2;
         ord.trailing_enabled = true;
         ord.trailing_type = TRAIL_ATR;
         ord.atr_period = m_atrPeriod;
         ord.atr_multiplier = 1.5;
         return ord;
      }
      
      // Mean reversion: oversold bounce from lower band
      else if(bb_position < 0.1 && m_close0 > m_close1)
      {
         ord.action = ACTION_BUY;
         ord.order_type = ORDER_TYPE_BUY;
         ord.stop_loss = m_close0 - m_atr * 0.5;
         ord.take_profit = m_bb_middle;
         return ord;
      }
      
      // Mean reversion: overbought pullback from upper band
      else if(bb_position > 0.9 && m_close0 < m_close1)
      {
         ord.action = ACTION_SELL;
         ord.order_type = ORDER_TYPE_SELL;
         ord.stop_loss = m_close0 + m_atr * 0.5;
         ord.take_profit = m_bb_middle;
         return ord;
      }
      
      return ord;
   }
   
   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
   {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      (*kb).WriteKV(ts, m_symbol, Name(), "atr", m_atr);
      (*kb).WriteKV(ts, m_symbol, Name(), "bb_position", (m_close0 - m_bb_lower) / (m_bb_upper - m_bb_lower));
      (*kb).WriteKV(ts, m_symbol, Name(), "volume_ratio", m_volume / (m_volume_ma + 0.00001));
   }
};
