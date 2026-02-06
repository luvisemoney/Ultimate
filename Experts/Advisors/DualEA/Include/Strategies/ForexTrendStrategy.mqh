#include "..\IStrategy.mqh"
#include "..\KnowledgeBase.mqh"
#include "..\TradeManager.mqh"

class CForexTrendStrategy : public IStrategy
{
private:
   // Trend indicators
   int m_emaFast, m_emaMedium, m_emaSlow;
   int m_ichimokuTenkan, m_ichimokuKijun, m_ichimokuSenkou;
   double m_parabolicStep, m_parabolicMax;
   
   // Momentum indicators
   int m_rsiPeriod, m_adxPeriod;
   
   // Cached values
   double m_ema_fast, m_ema_medium, m_ema_slow;
   double m_tenkan, m_kijun, m_senkou_a, m_senkou_b;
   double m_parabolic, m_rsi, m_adx;
   double m_close0, m_close1;
   
public:
   CForexTrendStrategy(const string symbol, const ENUM_TIMEFRAMES tf) : IStrategy("ForexTrendStrategy", symbol, tf)
   {
      // EMA periods for trend identification
      m_emaFast = 8; m_emaMedium = 21; m_emaSlow = 50;
      
      // Ichimoku parameters
      m_ichimokuTenkan = 9; m_ichimokuKijun = 26; m_ichimokuSenkou = 52;
      
      // Parabolic SAR
      m_parabolicStep = 0.02; m_parabolicMax = 0.2;
      
      // Momentum
      m_rsiPeriod = 14; m_adxPeriod = 14;
      
      ResetValues();
   }
   
   virtual string Name() { return "ForexTrendStrategy"; }
   
   void ResetValues()
   {
      m_ema_fast = m_ema_medium = m_ema_slow = 0;
      m_tenkan = m_kijun = m_senkou_a = m_senkou_b = 0;
      m_parabolic = m_rsi = m_adx = 0;
      m_close0 = m_close1 = 0;
   }
   
   virtual void Refresh()
   {
      ResetValues();
      m_close0 = iClose(m_symbol, m_timeframe, 0);
      m_close1 = iClose(m_symbol, m_timeframe, 1);
      
      // EMAs
      double ema_fast_buffer[], ema_medium_buffer[], ema_slow_buffer[];
      int ema_fast_handle = iMA(m_symbol, m_timeframe, m_emaFast, 0, MODE_EMA, PRICE_CLOSE);
      int ema_medium_handle = iMA(m_symbol, m_timeframe, m_emaMedium, 0, MODE_EMA, PRICE_CLOSE);
      int ema_slow_handle = iMA(m_symbol, m_timeframe, m_emaSlow, 0, MODE_EMA, PRICE_CLOSE);
      
      if(ema_fast_handle > 0) CopyBuffer(ema_fast_handle, 0, 0, 1, ema_fast_buffer);
      if(ema_medium_handle > 0) CopyBuffer(ema_medium_handle, 0, 0, 1, ema_medium_buffer);
      if(ema_slow_handle > 0) CopyBuffer(ema_slow_handle, 0, 0, 1, ema_slow_buffer);
      
      m_ema_fast = ema_fast_buffer[0];
      m_ema_medium = ema_medium_buffer[0];
      m_ema_slow = ema_slow_buffer[0];
      
      // Ichimoku
      double tenkan_buffer[], kijun_buffer[], senkou_a_buffer[], senkou_b_buffer[];
      int ichimoku_handle = iIchimoku(m_symbol, m_timeframe, m_ichimokuTenkan, m_ichimokuKijun, m_ichimokuSenkou);
      
      if(ichimoku_handle > 0)
      {
         CopyBuffer(ichimoku_handle, 0, 0, 1, tenkan_buffer);
         CopyBuffer(ichimoku_handle, 1, 0, 1, kijun_buffer);
         CopyBuffer(ichimoku_handle, 2, 0, 1, senkou_a_buffer);
         CopyBuffer(ichimoku_handle, 3, 0, 1, senkou_b_buffer);
         
         m_tenkan = tenkan_buffer[0];
         m_kijun = kijun_buffer[0];
         m_senkou_a = senkou_a_buffer[0];
         m_senkou_b = senkou_b_buffer[0];
      }
      
      // Parabolic SAR
      double sar_buffer[];
      int sar_handle = iSAR(m_symbol, m_timeframe, m_parabolicStep, m_parabolicMax);
      if(sar_handle > 0) CopyBuffer(sar_handle, 0, 0, 1, sar_buffer);
      m_parabolic = sar_buffer[0];
      
      // RSI
      double rsi_buffer[];
      int rsi_handle = iRSI(m_symbol, m_timeframe, m_rsiPeriod, PRICE_CLOSE);
      if(rsi_handle > 0) CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer);
      m_rsi = rsi_buffer[0];
      
      // ADX
      double adx_buffer[];
      int adx_handle = iADX(m_symbol, m_timeframe, m_adxPeriod);
      if(adx_handle > 0) CopyBuffer(adx_handle, 0, 0, 1, adx_buffer);
      m_adx = adx_buffer[0];
   }
   
   virtual TradeOrder CheckSignal()
   {
      TradeOrder ord; ord.strategy_name = Name();
      
      // Trend alignment checks
      bool ema_bullish = m_ema_fast > m_ema_medium && m_ema_medium > m_ema_slow;
      bool ema_bearish = m_ema_fast < m_ema_medium && m_ema_medium < m_ema_slow;
      
      // Ichimoku cloud
      bool above_cloud = m_close0 > m_senkou_a && m_close0 > m_senkou_b;
      bool below_cloud = m_close0 < m_senkou_a && m_close0 < m_senkou_b;
      
      // Parabolic SAR
      bool sar_bullish = m_close0 > m_parabolic;
      bool sar_bearish = m_close0 < m_parabolic;
      
      // Momentum filters
      bool rsi_oversold = m_rsi < 30;
      bool rsi_overbought = m_rsi > 70;
      bool strong_trend = m_adx > 25;
      
      // Bullish setup
      if(ema_bullish && above_cloud && sar_bullish && strong_trend && rsi_oversold)
      {
         ord.action = ACTION_BUY;
         ord.order_type = ORDER_TYPE_BUY;
         ord.stop_loss = m_ema_medium;
         ord.take_profit = m_close0 + (m_close0 - m_ema_medium) * 2;
         ord.trailing_enabled = true;
         ord.trailing_type = TRAIL_FIXED_POINTS;
         ord.trail_activation_points = 30;
         ord.trail_distance_points = 20;
         ord.trail_step_points = 5;
         return ord;
      }
      
      // Bearish setup
      else if(ema_bearish && below_cloud && sar_bearish && strong_trend && rsi_overbought)
      {
         ord.action = ACTION_SELL;
         ord.order_type = ORDER_TYPE_SELL;
         ord.stop_loss = m_ema_medium;
         ord.take_profit = m_close0 - (m_ema_medium - m_close0) * 2;
         ord.trailing_enabled = true;
         ord.trailing_type = TRAIL_FIXED_POINTS;
         ord.trail_activation_points = 30;
         ord.trail_distance_points = 20;
         ord.trail_step_points = 5;
         return ord;
      }
      
      return ord;
   }
   
   virtual void ExportFeatures(CFeaturesKB* kb, const datetime ts)
   {
      if(CheckPointer(kb)==POINTER_INVALID) return;
      
      // Trend strength indicators
      double trend_strength = 0;
      if(m_ema_fast > m_ema_medium) trend_strength += 1;
      if(m_ema_medium > m_ema_slow) trend_strength += 1;
      if(m_close0 > m_senkou_a && m_close0 > m_senkou_b) trend_strength += 1;
      
      (*kb).WriteKV(ts, m_symbol, Name(), "trend_strength", trend_strength);
      (*kb).WriteKV(ts, m_symbol, Name(), "rsi", m_rsi);
      (*kb).WriteKV(ts, m_symbol, Name(), "adx", m_adx);
      (*kb).WriteKV(ts, m_symbol, Name(), "ema_distance", MathAbs(m_close0 - m_ema_medium) / m_ema_medium * 100);
   }
};
