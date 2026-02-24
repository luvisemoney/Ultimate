//+------------------------------------------------------------------+
//| StrategySignalGenerators.mqh - Extensible Signal Generator Framework |
//| Provides actual indicator-based signal generation for all strategies |
//+------------------------------------------------------------------+
#ifndef __STRATEGY_SIGNAL_GENERATORS_MQH__
#define __STRATEGY_SIGNAL_GENERATORS_MQH__

#include "GateManager.mqh"

//+------------------------------------------------------------------+
//| Base Interface for Strategy Signal Generators                     |
//+------------------------------------------------------------------+
class ISignalGenerator
{
public:
   virtual ~ISignalGenerator() {}
   virtual string GetName() = 0;
   virtual bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) = 0;
   virtual string GetDescription() { return ""; }
};

//+------------------------------------------------------------------+
//| Helper Functions for All Strategies                               |
//+------------------------------------------------------------------+
double GetATR(string symbol, ENUM_TIMEFRAMES tf, int period = 14)
{
   int handle = iATR(symbol, tf, period);
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[1];
   if(CopyBuffer(handle, 0, 0, 1, buf) != 1) { IndicatorRelease(handle); return 0.0; }
   IndicatorRelease(handle);
   return buf[0];
}

double GetCurrentPrice(string symbol, bool bid = true)
{
   return bid ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
}

void SetSignalDefaults(TradingSignal &signal, string symbol, ENUM_TIMEFRAMES tf, string strategy, int type, double price)
{
   // Initialize all fields first to prevent garbage values
   signal.Init();
   
   signal.id = strategy + "_" + IntegerToString(TimeCurrent());
   signal.symbol = symbol;
   signal.timeframe = tf;
   signal.timestamp = TimeCurrent();
   signal.price = price;
   signal.type = type;
   signal.order_type = (type == 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;  // Set order_type based on type
   signal.strategy = strategy;
   signal.volume = 0.1;
   signal.confidence = 0.6;
   
   double atr = GetATR(symbol, tf, 14);
   if(atr <= 0) atr = 100 * SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // TIMEFRAME-BASED MULTIPLIER: Longer timeframes = wider SL/TP
   double tf_multiplier = 1.0;
   switch(tf)
   {
      case PERIOD_M1:  tf_multiplier = 0.5;  break;  // Tightest stops
      case PERIOD_M5:  tf_multiplier = 0.7;  break;
      case PERIOD_M15: tf_multiplier = 0.85; break;
      case PERIOD_M30: tf_multiplier = 1.0;  break;  // Baseline
      case PERIOD_H1:  tf_multiplier = 1.3;  break;
      case PERIOD_H4:  tf_multiplier = 1.6;  break;
      case PERIOD_D1:  tf_multiplier = 2.0;  break;  // Wider stops
      case PERIOD_W1:  tf_multiplier = 2.5;  break;
      case PERIOD_MN1: tf_multiplier = 3.0;  break;  // Widest stops
      default:         tf_multiplier = 1.0;  break;
   }
   
   // Set SL/TP based on signal type with timeframe adjustment
   double sl_mult = 1.5 * tf_multiplier;
   double tp_mult = 2.5 * tf_multiplier;
   
   if(type == 0) // Buy
   {
      signal.sl = price - atr * sl_mult;
      signal.tp = price + atr * tp_mult;
   }
   else // Sell
   {
      signal.sl = price + atr * sl_mult;
      signal.tp = price - atr * tp_mult;
   }
   
   // Final safety check - ensure TP is never garbage
   if(signal.tp <= 0.0 || signal.tp > 1e10 || MathIsValidNumber(signal.tp) == false)
   {
      signal.tp = (type == 0) ? price + atr * tp_mult : price - atr * tp_mult;
   }
}

//+------------------------------------------------------------------+
//| ADX Strategy - Trend Strength                                     |
//+------------------------------------------------------------------+
class CADXSignalGenerator : public ISignalGenerator
{
private:
   int m_period;
   double m_threshold;
public:
   CADXSignalGenerator(int period = 14, double threshold = 25.0) { m_period = period; m_threshold = threshold; }
   string GetName() override { return "ADXStrategy"; }
   string GetDescription() override { return "ADX trend strength with DI+/DI- crossover"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iADX(symbol, tf, m_period);
      if(handle == INVALID_HANDLE) return false;
      
      double adx[2], di_plus[2], di_minus[2];
      if(CopyBuffer(handle, 0, 0, 2, adx) != 2) { IndicatorRelease(handle); return false; }
      if(CopyBuffer(handle, 1, 0, 2, di_plus) != 2) { IndicatorRelease(handle); return false; }
      if(CopyBuffer(handle, 2, 0, 2, di_minus) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      if(adx[0] < m_threshold) return false;
      
      double price = GetCurrentPrice(symbol);
      
      // DI+ crosses above DI- = Buy
      if(di_plus[1] <= di_minus[1] && di_plus[0] > di_minus[0])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.5 + (adx[0] / 100.0) * 0.3;
         return true;
      }
      // DI- crosses above DI+ = Sell
      if(di_minus[1] <= di_plus[1] && di_minus[0] > di_plus[0])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.5 + (adx[0] / 100.0) * 0.3;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| RSI Strategy - Overbought/Oversold                                |
//+------------------------------------------------------------------+
class CRSISignalGenerator : public ISignalGenerator
{
private:
   int m_period;
   double m_overbought, m_oversold;
public:
   CRSISignalGenerator(int period = 14, double ob = 70.0, double os = 30.0) 
   { m_period = period; m_overbought = ob; m_oversold = os; }
   string GetName() override { return "RSIStrategy"; }
   string GetDescription() override { return "RSI overbought/oversold reversal"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iRSI(symbol, tf, m_period, PRICE_CLOSE);
      if(handle == INVALID_HANDLE) return false;
      
      double rsi[2];
      if(CopyBuffer(handle, 0, 0, 2, rsi) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      
      // RSI crosses above oversold = Buy
      if(rsi[1] < m_oversold && rsi[0] >= m_oversold)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55 + (m_oversold - rsi[1]) / 100.0;
         return true;
      }
      // RSI crosses below overbought = Sell
      if(rsi[1] > m_overbought && rsi[0] <= m_overbought)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55 + (rsi[1] - m_overbought) / 100.0;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| MACD Strategy - Crossover                                         |
//+------------------------------------------------------------------+
class CMACDSignalGenerator : public ISignalGenerator
{
private:
   int m_fast, m_slow, m_signal;
public:
   CMACDSignalGenerator(int fast = 12, int slow = 26, int sig = 9) 
   { m_fast = fast; m_slow = slow; m_signal = sig; }
   string GetName() override { return "MACDStrategy"; }
   string GetDescription() override { return "MACD line/signal crossover"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iMACD(symbol, tf, m_fast, m_slow, m_signal, PRICE_CLOSE);
      if(handle == INVALID_HANDLE) return false;
      
      double macd[2], sig_line[2];
      if(CopyBuffer(handle, 0, 0, 2, macd) != 2) { IndicatorRelease(handle); return false; }
      if(CopyBuffer(handle, 1, 0, 2, sig_line) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      
      // MACD crosses above signal = Buy
      if(macd[1] <= sig_line[1] && macd[0] > sig_line[0])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.6;
         return true;
      }
      // MACD crosses below signal = Sell
      if(macd[1] >= sig_line[1] && macd[0] < sig_line[0])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.6;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Stochastic Strategy - Crossover in OB/OS zones                    |
//+------------------------------------------------------------------+
class CStochasticSignalGenerator : public ISignalGenerator
{
private:
   int m_k, m_d, m_slowing;
   double m_overbought, m_oversold;
public:
   CStochasticSignalGenerator(int k = 14, int d = 3, int slowing = 3, double ob = 80.0, double os = 20.0)
   { m_k = k; m_d = d; m_slowing = slowing; m_overbought = ob; m_oversold = os; }
   string GetName() override { return "StochasticStrategy"; }
   string GetDescription() override { return "Stochastic K/D crossover in OB/OS zones"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iStochastic(symbol, tf, m_k, m_d, m_slowing, MODE_SMA, STO_LOWHIGH);
      if(handle == INVALID_HANDLE) return false;
      
      double k_line[2], d_line[2];
      if(CopyBuffer(handle, 0, 0, 2, k_line) != 2) { IndicatorRelease(handle); return false; }
      if(CopyBuffer(handle, 1, 0, 2, d_line) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      
      // K crosses above D in oversold = Buy
      if(k_line[0] < m_oversold && k_line[1] <= d_line[1] && k_line[0] > d_line[0])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.58;
         return true;
      }
      // K crosses below D in overbought = Sell
      if(k_line[0] > m_overbought && k_line[1] >= d_line[1] && k_line[0] < d_line[0])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.58;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| CCI Strategy - Commodity Channel Index                            |
//+------------------------------------------------------------------+
class CCCISignalGenerator : public ISignalGenerator
{
private:
   int m_period;
   double m_overbought, m_oversold;
public:
   CCCISignalGenerator(int period = 20, double ob = 100.0, double os = -100.0)
   { m_period = period; m_overbought = ob; m_oversold = os; }
   string GetName() override { return "CCIStrategy"; }
   string GetDescription() override { return "CCI overbought/oversold crossover"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iCCI(symbol, tf, m_period, PRICE_TYPICAL);
      if(handle == INVALID_HANDLE) return false;
      
      double cci[2];
      if(CopyBuffer(handle, 0, 0, 2, cci) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      
      // CCI crosses above oversold = Buy
      if(cci[1] < m_oversold && cci[0] >= m_oversold)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55;
         return true;
      }
      // CCI crosses below overbought = Sell
      if(cci[1] > m_overbought && cci[0] <= m_overbought)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Momentum Strategy                                                  |
//+------------------------------------------------------------------+
class CMomentumSignalGenerator : public ISignalGenerator
{
private:
   int m_period;
public:
   CMomentumSignalGenerator(int period = 14) { m_period = period; }
   string GetName() override { return "MomentumStrategy"; }
   string GetDescription() override { return "Momentum zero-line crossover"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iMomentum(symbol, tf, m_period, PRICE_CLOSE);
      if(handle == INVALID_HANDLE) return false;
      
      double mom[2];
      if(CopyBuffer(handle, 0, 0, 2, mom) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      double zero_line = 100.0;
      
      // Momentum crosses above 100 = Buy
      if(mom[1] < zero_line && mom[0] >= zero_line)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55;
         return true;
      }
      // Momentum crosses below 100 = Sell
      if(mom[1] > zero_line && mom[0] <= zero_line)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Williams %R Strategy                                               |
//+------------------------------------------------------------------+
class CWilliamsPercentRangeSignalGenerator : public ISignalGenerator
{
private:
   int m_period;
   double m_overbought, m_oversold;
public:
   CWilliamsPercentRangeSignalGenerator(int period = 14, double ob = -20.0, double os = -80.0)
   { m_period = period; m_overbought = ob; m_oversold = os; }
   string GetName() override { return "WilliamsPercentRangeStrategy"; }
   string GetDescription() override { return "Williams %R overbought/oversold"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iWPR(symbol, tf, m_period);
      if(handle == INVALID_HANDLE) return false;
      
      double wpr[2];
      if(CopyBuffer(handle, 0, 0, 2, wpr) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      
      // WPR crosses above oversold = Buy
      if(wpr[1] < m_oversold && wpr[0] >= m_oversold)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55;
         return true;
      }
      // WPR crosses below overbought = Sell
      if(wpr[1] > m_overbought && wpr[0] <= m_overbought)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| DeMarker Strategy                                                  |
//+------------------------------------------------------------------+
class CDeMarkerSignalGenerator : public ISignalGenerator
{
private:
   int m_period;
   double m_overbought, m_oversold;
public:
   CDeMarkerSignalGenerator(int period = 14, double ob = 0.7, double os = 0.3)
   { m_period = period; m_overbought = ob; m_oversold = os; }
   string GetName() override { return "DeMarkerStrategy"; }
   string GetDescription() override { return "DeMarker overbought/oversold"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iDeMarker(symbol, tf, m_period);
      if(handle == INVALID_HANDLE) return false;
      
      double dem[2];
      if(CopyBuffer(handle, 0, 0, 2, dem) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      
      // DeMarker crosses above oversold = Buy
      if(dem[1] < m_oversold && dem[0] >= m_oversold)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55;
         return true;
      }
      // DeMarker crosses below overbought = Sell
      if(dem[1] > m_overbought && dem[0] <= m_overbought)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Force Index Strategy                                               |
//+------------------------------------------------------------------+
class CForceIndexSignalGenerator : public ISignalGenerator
{
private:
   int m_period;
public:
   CForceIndexSignalGenerator(int period = 13) { m_period = period; }
   string GetName() override { return "ForceIndexStrategy"; }
   string GetDescription() override { return "Force Index zero-line crossover"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iForce(symbol, tf, m_period, MODE_EMA, VOLUME_TICK);
      if(handle == INVALID_HANDLE) return false;
      
      double force[2];
      if(CopyBuffer(handle, 0, 0, 2, force) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      
      // Force crosses above 0 = Buy
      if(force[1] < 0 && force[0] >= 0)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55;
         return true;
      }
      // Force crosses below 0 = Sell
      if(force[1] > 0 && force[0] <= 0)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Bears Power Strategy                                               |
//+------------------------------------------------------------------+
class CBearsPowerSignalGenerator : public ISignalGenerator
{
private:
   int m_period;
public:
   CBearsPowerSignalGenerator(int period = 13) { m_period = period; }
   string GetName() override { return "BearsPowerStrategy"; }
   string GetDescription() override { return "Bears Power zero-line crossover with trend filter"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iBearsPower(symbol, tf, m_period);
      if(handle == INVALID_HANDLE) return false;
      
      double bears[2];
      if(CopyBuffer(handle, 0, 0, 2, bears) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      // Get EMA for trend filter
      int ema_handle = iMA(symbol, tf, m_period, 0, MODE_EMA, PRICE_CLOSE);
      if(ema_handle == INVALID_HANDLE) return false;
      double ema[1], close[1];
      CopyBuffer(ema_handle, 0, 0, 1, ema);
      IndicatorRelease(ema_handle);
      close[0] = GetCurrentPrice(symbol);
      
      double price = close[0];
      
      // Bears Power rising from below 0 while price above EMA = Buy
      if(bears[1] < bears[0] && bears[0] < 0 && price > ema[0])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55;
         return true;
      }
      // Bears Power falling while price below EMA = Sell
      if(bears[1] > bears[0] && bears[0] > 0 && price < ema[0])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Bulls Power Strategy                                               |
//+------------------------------------------------------------------+
class CBullsPowerSignalGenerator : public ISignalGenerator
{
private:
   int m_period;
public:
   CBullsPowerSignalGenerator(int period = 13) { m_period = period; }
   string GetName() override { return "BullsPowerStrategy"; }
   string GetDescription() override { return "Bulls Power zero-line crossover with trend filter"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iBullsPower(symbol, tf, m_period);
      if(handle == INVALID_HANDLE) return false;
      
      double bulls[2];
      if(CopyBuffer(handle, 0, 0, 2, bulls) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      // Get EMA for trend filter
      int ema_handle = iMA(symbol, tf, m_period, 0, MODE_EMA, PRICE_CLOSE);
      if(ema_handle == INVALID_HANDLE) return false;
      double ema[1];
      CopyBuffer(ema_handle, 0, 0, 1, ema);
      IndicatorRelease(ema_handle);
      
      double price = GetCurrentPrice(symbol);
      
      // Bulls Power rising while price above EMA = Buy
      if(bulls[1] < bulls[0] && bulls[0] > 0 && price > ema[0])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55;
         return true;
      }
      // Bulls Power falling from above 0 while price below EMA = Sell
      if(bulls[1] > bulls[0] && bulls[0] < 0 && price < ema[0])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| RVI Strategy - Relative Vigor Index                                |
//+------------------------------------------------------------------+
class CRVISignalGenerator : public ISignalGenerator
{
private:
   int m_period;
public:
   CRVISignalGenerator(int period = 10) { m_period = period; }
   string GetName() override { return "RVIStrategy"; }
   string GetDescription() override { return "RVI signal line crossover"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iRVI(symbol, tf, m_period);
      if(handle == INVALID_HANDLE) return false;
      
      double rvi[2], sig_line[2];
      if(CopyBuffer(handle, 0, 0, 2, rvi) != 2) { IndicatorRelease(handle); return false; }
      if(CopyBuffer(handle, 1, 0, 2, sig_line) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      
      // RVI crosses above signal = Buy
      if(rvi[1] <= sig_line[1] && rvi[0] > sig_line[0])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55;
         return true;
      }
      // RVI crosses below signal = Sell
      if(rvi[1] >= sig_line[1] && rvi[0] < sig_line[0])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| OsMA Strategy - Moving Average of Oscillator                       |
//+------------------------------------------------------------------+
class COsMASignalGenerator : public ISignalGenerator
{
private:
   int m_fast, m_slow, m_signal;
public:
   COsMASignalGenerator(int fast = 12, int slow = 26, int sig = 9)
   { m_fast = fast; m_slow = slow; m_signal = sig; }
   string GetName() override { return "OsMAStrategy"; }
   string GetDescription() override { return "OsMA zero-line crossover"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iOsMA(symbol, tf, m_fast, m_slow, m_signal, PRICE_CLOSE);
      if(handle == INVALID_HANDLE) return false;
      
      double osma[2];
      if(CopyBuffer(handle, 0, 0, 2, osma) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      
      // OsMA crosses above 0 = Buy
      if(osma[1] < 0 && osma[0] >= 0)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55;
         return true;
      }
      // OsMA crosses below 0 = Sell
      if(osma[1] > 0 && osma[0] <= 0)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| TriX Strategy - Triple Exponential Average                         |
//+------------------------------------------------------------------+
class CTriXSignalGenerator : public ISignalGenerator
{
private:
   int m_period;
public:
   CTriXSignalGenerator(int period = 14) { m_period = period; }
   string GetName() override { return "TriXStrategy"; }
   string GetDescription() override { return "TriX zero-line crossover"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iTriX(symbol, tf, m_period, PRICE_CLOSE);
      if(handle == INVALID_HANDLE) return false;
      
      double trix[2];
      if(CopyBuffer(handle, 0, 0, 2, trix) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      
      // TriX crosses above 0 = Buy
      if(trix[1] < 0 && trix[0] >= 0)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55;
         return true;
      }
      // TriX crosses below 0 = Sell
      if(trix[1] > 0 && trix[0] <= 0)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Accelerator Oscillator Strategy                                    |
//+------------------------------------------------------------------+
class CAcceleratorOscillatorSignalGenerator : public ISignalGenerator
{
public:
   string GetName() override { return "AcceleratorOscillatorStrategy"; }
   string GetDescription() override { return "AC zero-line crossover with color confirmation"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iAC(symbol, tf);
      if(handle == INVALID_HANDLE) return false;
      
      double ac[3];
      if(CopyBuffer(handle, 0, 0, 3, ac) != 3) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      
      // AC crosses above 0 with rising momentum = Buy
      if(ac[2] < 0 && ac[1] < 0 && ac[0] >= 0 && ac[0] > ac[1])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55;
         return true;
      }
      // AC crosses below 0 with falling momentum = Sell
      if(ac[2] > 0 && ac[1] > 0 && ac[0] <= 0 && ac[0] < ac[1])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Awesome Oscillator Strategy                                        |
//+------------------------------------------------------------------+
class CAwesomeOscillatorSignalGenerator : public ISignalGenerator
{
public:
   string GetName() override { return "AwesomeOscillatorStrategy"; }
   string GetDescription() override { return "AO zero-line crossover"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iAO(symbol, tf);
      if(handle == INVALID_HANDLE) return false;
      
      double ao[2];
      if(CopyBuffer(handle, 0, 0, 2, ao) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      
      // AO crosses above 0 = Buy
      if(ao[1] < 0 && ao[0] >= 0)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55;
         return true;
      }
      // AO crosses below 0 = Sell
      if(ao[1] > 0 && ao[0] <= 0)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Alligator Strategy                                                 |
//+------------------------------------------------------------------+
class CAlligatorSignalGenerator : public ISignalGenerator
{
private:
   int m_jaw, m_teeth, m_lips;
public:
   CAlligatorSignalGenerator(int jaw = 13, int teeth = 8, int lips = 5)
   { m_jaw = jaw; m_teeth = teeth; m_lips = lips; }
   string GetName() override { return "AlligatorStrategy"; }
   string GetDescription() override { return "Alligator awakening - lines spread apart"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iAlligator(symbol, tf, m_jaw, 8, m_teeth, 5, m_lips, 3, MODE_SMMA, PRICE_MEDIAN);
      if(handle == INVALID_HANDLE) return false;
      
      double jaw[2], teeth[2], lips[2];
      if(CopyBuffer(handle, 0, 0, 2, jaw) != 2) { IndicatorRelease(handle); return false; }
      if(CopyBuffer(handle, 1, 0, 2, teeth) != 2) { IndicatorRelease(handle); return false; }
      if(CopyBuffer(handle, 2, 0, 2, lips) != 2) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      
      // Bullish: Lips > Teeth > Jaw and spreading
      if(lips[0] > teeth[0] && teeth[0] > jaw[0] && 
         (lips[0] - jaw[0]) > (lips[1] - jaw[1]))
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.58;
         return true;
      }
      // Bearish: Lips < Teeth < Jaw and spreading
      if(lips[0] < teeth[0] && teeth[0] < jaw[0] && 
         (jaw[0] - lips[0]) > (jaw[1] - lips[1]))
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.58;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Gator Oscillator Strategy                                          |
//+------------------------------------------------------------------+
class CGatorSignalGenerator : public ISignalGenerator
{
public:
   string GetName() override { return "GatorStrategy"; }
   string GetDescription() override { return "Gator awakening - bars expanding"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iGator(symbol, tf, 13, 8, 8, 5, 5, 3, MODE_SMMA, PRICE_MEDIAN);
      if(handle == INVALID_HANDLE) return false;
      
      double upper[3], lower[3];
      if(CopyBuffer(handle, 0, 0, 3, upper) != 3) { IndicatorRelease(handle); return false; }
      if(CopyBuffer(handle, 2, 0, 3, lower) != 3) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      
      // Gator awakening (bars expanding) = trend starting
      double spread_now = MathAbs(upper[0]) + MathAbs(lower[0]);
      double spread_prev = MathAbs(upper[1]) + MathAbs(lower[1]);
      double spread_prev2 = MathAbs(upper[2]) + MathAbs(lower[2]);
      
      if(spread_now > spread_prev && spread_prev > spread_prev2)
      {
         // Determine direction from upper histogram
         if(upper[0] > 0)
         {
            SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
            signal.confidence = 0.55;
            return true;
         }
         else
         {
            SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
            signal.confidence = 0.55;
            return true;
         }
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Ichimoku Strategy                                                  |
//+------------------------------------------------------------------+
class CIchimokuSignalGenerator : public ISignalGenerator
{
private:
   int m_tenkan, m_kijun, m_senkou;
public:
   CIchimokuSignalGenerator(int tenkan = 9, int kijun = 26, int senkou = 52)
   { m_tenkan = tenkan; m_kijun = kijun; m_senkou = senkou; }
   string GetName() override { return "IchimokuStrategy"; }
   string GetDescription() override { return "Ichimoku Tenkan/Kijun crossover with cloud filter"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iIchimoku(symbol, tf, m_tenkan, m_kijun, m_senkou);
      if(handle == INVALID_HANDLE) return false;
      
      double tenkan[2], kijun[2], senkou_a[1], senkou_b[1];
      if(CopyBuffer(handle, 0, 0, 2, tenkan) != 2) { IndicatorRelease(handle); return false; }
      if(CopyBuffer(handle, 1, 0, 2, kijun) != 2) { IndicatorRelease(handle); return false; }
      if(CopyBuffer(handle, 2, 0, 1, senkou_a) != 1) { IndicatorRelease(handle); return false; }
      if(CopyBuffer(handle, 3, 0, 1, senkou_b) != 1) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      double price = GetCurrentPrice(symbol);
      double cloud_top = MathMax(senkou_a[0], senkou_b[0]);
      double cloud_bottom = MathMin(senkou_a[0], senkou_b[0]);
      
      // Tenkan crosses above Kijun, price above cloud = Buy
      if(tenkan[1] <= kijun[1] && tenkan[0] > kijun[0] && price > cloud_top)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.62;
         return true;
      }
      // Tenkan crosses below Kijun, price below cloud = Sell
      if(tenkan[1] >= kijun[1] && tenkan[0] < kijun[0] && price < cloud_bottom)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.62;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Fractals Strategy                                                  |
//+------------------------------------------------------------------+
class CFractalsSignalGenerator : public ISignalGenerator
{
public:
   string GetName() override { return "FractalsStrategy"; }
   string GetDescription() override { return "Fractal breakout"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iFractals(symbol, tf);
      if(handle == INVALID_HANDLE) return false;
      
      double upper[10], lower[10];
      if(CopyBuffer(handle, 0, 0, 10, upper) != 10) { IndicatorRelease(handle); return false; }
      if(CopyBuffer(handle, 1, 0, 10, lower) != 10) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      // Find last valid fractal
      double last_upper = 0, last_lower = 0;
      for(int i = 2; i < 10; i++)
      {
         if(upper[i] != EMPTY_VALUE && upper[i] > 0) { last_upper = upper[i]; break; }
      }
      for(int i = 2; i < 10; i++)
      {
         if(lower[i] != EMPTY_VALUE && lower[i] > 0) { last_lower = lower[i]; break; }
      }
      
      if(last_upper == 0 && last_lower == 0) return false;
      
      double price = GetCurrentPrice(symbol);
      
      // Price breaks above upper fractal = Buy
      if(last_upper > 0 && price > last_upper)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55;
         return true;
      }
      // Price breaks below lower fractal = Sell
      if(last_lower > 0 && price < last_lower)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| ZigZag Strategy                                                    |
//+------------------------------------------------------------------+
class CZigZagSignalGenerator : public ISignalGenerator
{
private:
   int m_depth, m_deviation, m_backstep;
public:
   CZigZagSignalGenerator(int depth = 12, int deviation = 5, int backstep = 3)
   { m_depth = depth; m_deviation = deviation; m_backstep = backstep; }
   string GetName() override { return "ZigZagStrategy"; }
   string GetDescription() override { return "ZigZag swing point breakout"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int handle = iCustom(symbol, tf, "Examples\\ZigZag", m_depth, m_deviation, m_backstep);
      if(handle == INVALID_HANDLE) return false;
      
      double zz[50];
      if(CopyBuffer(handle, 0, 0, 50, zz) != 50) { IndicatorRelease(handle); return false; }
      IndicatorRelease(handle);
      
      // Find last two swing points
      double swing1 = 0, swing2 = 0;
      int swing1_idx = -1, swing2_idx = -1;
      for(int i = 0; i < 50; i++)
      {
         if(zz[i] != 0 && zz[i] != EMPTY_VALUE)
         {
            if(swing1 == 0) { swing1 = zz[i]; swing1_idx = i; }
            else if(swing2 == 0) { swing2 = zz[i]; swing2_idx = i; break; }
         }
      }
      
      if(swing1 == 0 || swing2 == 0) return false;
      
      double price = GetCurrentPrice(symbol);
      
      // Higher high = uptrend, buy on pullback
      if(swing1 > swing2 && price > swing2)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55;
         return true;
      }
      // Lower low = downtrend, sell on pullback
      if(swing1 < swing2 && price < swing2)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Ultimate Oscillator Strategy                                       |
//+------------------------------------------------------------------+
class CUltimateOscillatorSignalGenerator : public ISignalGenerator
{
private:
   int m_fast, m_middle, m_slow;
   double m_overbought, m_oversold;
public:
   CUltimateOscillatorSignalGenerator(int fast = 7, int middle = 14, int slow = 28, double ob = 70.0, double os = 30.0)
   { m_fast = fast; m_middle = middle; m_slow = slow; m_overbought = ob; m_oversold = os; }
   string GetName() override { return "UltimateOscillatorStrategy"; }
   string GetDescription() override { return "Ultimate Oscillator overbought/oversold with divergence"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      // Ultimate Oscillator is not a built-in indicator, calculate manually
      // Using a simplified approach with ATR and price action
      double close[30], high[30], low[30];
      if(CopyClose(symbol, tf, 0, 30, close) != 30) return false;
      if(CopyHigh(symbol, tf, 0, 30, high) != 30) return false;
      if(CopyLow(symbol, tf, 0, 30, low) != 30) return false;
      
      // Calculate buying pressure and true range
      double bp_sum_fast = 0, tr_sum_fast = 0;
      double bp_sum_mid = 0, tr_sum_mid = 0;
      double bp_sum_slow = 0, tr_sum_slow = 0;
      
      for(int i = 1; i < 29; i++)
      {
         double true_low = MathMin(low[i], close[i+1]);
         double true_high = MathMax(high[i], close[i+1]);
         double bp = close[i] - true_low;
         double tr = true_high - true_low;
         
         if(i < m_fast) { bp_sum_fast += bp; tr_sum_fast += tr; }
         if(i < m_middle) { bp_sum_mid += bp; tr_sum_mid += tr; }
         if(i < m_slow) { bp_sum_slow += bp; tr_sum_slow += tr; }
      }
      
      if(tr_sum_fast == 0 || tr_sum_mid == 0 || tr_sum_slow == 0) return false;
      
      double avg_fast = bp_sum_fast / tr_sum_fast;
      double avg_mid = bp_sum_mid / tr_sum_mid;
      double avg_slow = bp_sum_slow / tr_sum_slow;
      
      double uo = 100.0 * ((4.0 * avg_fast) + (2.0 * avg_mid) + avg_slow) / 7.0;
      
      double price = GetCurrentPrice(symbol);
      
      // UO crosses above oversold = Buy
      if(uo < m_oversold + 5 && uo > m_oversold)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.55;
         return true;
      }
      // UO crosses below overbought = Sell
      if(uo > m_overbought - 5 && uo < m_overbought)
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.55;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Moving Average Strategy (default fallback)                         |
//+------------------------------------------------------------------+
class CMovingAverageSignalGenerator : public ISignalGenerator
{
private:
   int m_fast, m_slow;
public:
   CMovingAverageSignalGenerator(int fast = 20, int slow = 50) { m_fast = fast; m_slow = slow; }
   string GetName() override { return "MovingAverageStrategy"; }
   string GetDescription() override { return "MA crossover"; }
   
   bool GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal) override
   {
      int fast_handle = iMA(symbol, tf, m_fast, 0, MODE_SMA, PRICE_CLOSE);
      int slow_handle = iMA(symbol, tf, m_slow, 0, MODE_SMA, PRICE_CLOSE);
      if(fast_handle == INVALID_HANDLE || slow_handle == INVALID_HANDLE) return false;
      
      double fast_ma[2], slow_ma[2];
      if(CopyBuffer(fast_handle, 0, 0, 2, fast_ma) != 2) { IndicatorRelease(fast_handle); IndicatorRelease(slow_handle); return false; }
      if(CopyBuffer(slow_handle, 0, 0, 2, slow_ma) != 2) { IndicatorRelease(fast_handle); IndicatorRelease(slow_handle); return false; }
      IndicatorRelease(fast_handle);
      IndicatorRelease(slow_handle);
      
      double price = GetCurrentPrice(symbol);
      
      // Fast MA crosses above Slow MA = Buy
      if(fast_ma[1] <= slow_ma[1] && fast_ma[0] > slow_ma[0])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 0, price);
         signal.confidence = 0.6;
         return true;
      }
      // Fast MA crosses below Slow MA = Sell
      if(fast_ma[1] >= slow_ma[1] && fast_ma[0] < slow_ma[0])
      {
         SetSignalDefaults(signal, symbol, tf, GetName(), 1, price);
         signal.confidence = 0.6;
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| STRATEGY SIGNAL GENERATOR REGISTRY                                 |
//| Maps strategy names to their signal generators                     |
//+------------------------------------------------------------------+
class CStrategySignalRegistry
{
private:
   ISignalGenerator* m_generators[];
   int m_count;
   
public:
   CStrategySignalRegistry()
   {
      m_count = 0;
      ArrayResize(m_generators, 0);
   }
   
   ~CStrategySignalRegistry()
   {
      for(int i = 0; i < m_count; i++)
      {
         if(m_generators[i] != NULL)
            delete m_generators[i];
      }
   }
   
   void RegisterGenerator(ISignalGenerator* generator)
   {
      if(generator == NULL) return;
      ArrayResize(m_generators, m_count + 1);
      m_generators[m_count] = generator;
      m_count++;
   }
   
   ISignalGenerator* GetGenerator(const string &strategy_name)
   {
      for(int i = 0; i < m_count; i++)
      {
         if(m_generators[i] != NULL && m_generators[i].GetName() == strategy_name)
            return m_generators[i];
      }
      return NULL;
   }
   
   bool GenerateSignal(const string &strategy_name, string symbol, ENUM_TIMEFRAMES tf, TradingSignal &signal)
   {
      // CRITICAL: Always initialize signal to safe defaults before generation
      signal.Init();
      
      ISignalGenerator* gen = GetGenerator(strategy_name);
      if(gen == NULL) return false;
      return gen.GenerateSignal(symbol, tf, signal);
   }
   
   int GetCount() { return m_count; }
   
   void InitializeAllStrategies()
   {
      RegisterGenerator(new CADXSignalGenerator());
      RegisterGenerator(new CRSISignalGenerator());
      RegisterGenerator(new CMACDSignalGenerator());
      RegisterGenerator(new CStochasticSignalGenerator());
      RegisterGenerator(new CCCISignalGenerator());
      RegisterGenerator(new CMomentumSignalGenerator());
      RegisterGenerator(new CWilliamsPercentRangeSignalGenerator());
      RegisterGenerator(new CDeMarkerSignalGenerator());
      RegisterGenerator(new CForceIndexSignalGenerator());
      RegisterGenerator(new CBearsPowerSignalGenerator());
      RegisterGenerator(new CBullsPowerSignalGenerator());
      RegisterGenerator(new CRVISignalGenerator());
      RegisterGenerator(new COsMASignalGenerator());
      RegisterGenerator(new CTriXSignalGenerator());
      RegisterGenerator(new CAcceleratorOscillatorSignalGenerator());
      RegisterGenerator(new CAwesomeOscillatorSignalGenerator());
      RegisterGenerator(new CAlligatorSignalGenerator());
      RegisterGenerator(new CGatorSignalGenerator());
      RegisterGenerator(new CIchimokuSignalGenerator());
      RegisterGenerator(new CFractalsSignalGenerator());
      RegisterGenerator(new CZigZagSignalGenerator());
      RegisterGenerator(new CUltimateOscillatorSignalGenerator());
      RegisterGenerator(new CMovingAverageSignalGenerator());
   }
   
   string GetRegisteredStrategies()
   {
      string result = "";
      for(int i = 0; i < m_count; i++)
      {
         if(m_generators[i] != NULL)
         {
            if(result != "") result += ",";
            result += m_generators[i].GetName();
         }
      }
      return result;
   }
};

#endif // __STRATEGY_SIGNAL_GENERATORS_MQH__
