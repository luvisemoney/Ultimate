// PositionManager.mqh
// Advanced position management: scaling, exits, OCO/brackets, correlation, and basic ML hooks.
// Scope: generic utility that can be used by PaperEA/LiveEA.
// Note: Several features (ML, advanced OCO lifecycle) are lightweight implementations intended to be
//       called from EA event loops (e.g., OnTick/OnTimer) for maintenance.


#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include <Arrays/ArrayObj.mqh>
#include <Object.mqh>

// --- Profiles
enum ScalingProfile
  {
   SCALING_AGGRESSIVE = 0,
   SCALING_MODERATE   = 1,
   SCALING_CONSERVATIVE = 2
  };

enum ExitProfile
  {
   EXIT_AGGRESSIVE = 0,
   EXIT_MODERATE   = 1,
   EXIT_CONSERVATIVE = 2
  };

// Lightweight container used for OCO lifecycle management
class COCOGroup : public CObject
  {
public:
   ulong    ticket1;
   ulong    ticket2;
   string   comment;
   COCOGroup(): ticket1(0), ticket2(0), comment("") {}
  };

class CPositionManager
  {
private:
   // Core
   CTrade          m_trade;
   string          m_symbol;
   int             m_magic;

   // Initialization and defaults
   int             m_atr_period;
   int             m_scale_activation_pts;
   int             m_trailing_pts;
   int             m_trailing_step_pts;

   // Risk and sizing
   bool            m_dynamic_risk_enabled;
   double          m_max_daily_dd_pct;
   double          m_max_pos_risk_pct;
   double          m_max_portfolio_risk_pct;
   double          m_risk_decay;

   bool            m_adaptive_sizing_enabled;
   double          m_min_size_mult;
   double          m_max_size_mult;

   // Profiles
   ScalingProfile  m_scaling_profile;
   ExitProfile     m_exit_profile;

   // Volatility-based exits
   bool            m_vol_exit_enabled;
   double          m_vol_exit_atr_mult;

   // ML (stub hooks)
   bool            m_ml_enabled;
   double          m_ml_threshold;
   string          m_ml_model_path;
   bool            m_ml_loaded;

   // OCO tracking
   CArrayObj       m_oco_groups;

   // --- Helpers
   double          TickSize(const string sym) const
     {
      double ts=0.0; SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE, ts);
      if(ts<=0.0) SymbolInfoDouble(sym, SYMBOL_POINT, ts);
      return ts;
     }
   int             PriceDigits(const string sym) const
     {
      return (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
     }
   double          RoundToTick(double price, const string sym) const
     {
      double ts = TickSize(sym); if(ts<=0.0) return price; int dg = PriceDigits(sym);
      double ticks = MathRound(price/ts);
      return NormalizeDouble(ticks*ts, dg);
     }
   double          RoundToTickBelow(double price, const string sym) const
     {
      double ts = TickSize(sym); if(ts<=0.0) return price; int dg = PriceDigits(sym);
      double ticks = MathFloor(price/ts);
      return NormalizeDouble(ticks*ts, dg);
     }
   double          RoundToTickAbove(double price, const string sym) const
     {
      double ts = TickSize(sym); if(ts<=0.0) return price; int dg = PriceDigits(sym);
      double ticks = MathCeil(price/ts);
      return NormalizeDouble(ticks*ts, dg);
     }
   double          MinStopDistance(const string sym) const
     {
      long lvl = 0; SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL, lvl);
      double pt = 0.0; SymbolInfoDouble(sym, SYMBOL_POINT, pt);
      return (double)lvl * pt;
     }
   double          FreezeDistance(const string sym) const
     {
      long lvl = 0; SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL, lvl);
      double pt = 0.0; SymbolInfoDouble(sym, SYMBOL_POINT, pt);
      return (double)lvl * pt;
     }
   bool            EnsureSymbolReady(const string sym) const
     {
      if(!SymbolSelect(sym, true)) { PrintFormat("[PM] Failed to select symbol %s", sym); return false; }
      long tmode = 0; SymbolInfoInteger(sym, SYMBOL_TRADE_MODE, tmode);
      if(tmode==SYMBOL_TRADE_MODE_DISABLED) { PrintFormat("[PM] Trading disabled for %s", sym); return false; }
      MqlTick tick; if(!SymbolInfoTick(sym, tick)) { PrintFormat("[PM] No tick for %s", sym); return false; }
      if(tick.bid<=0.0 || tick.ask<=0.0) { PrintFormat("[PM] Invalid bid/ask for %s", sym); return false; }
      return true;
     }
   double          NormalizeVolume(const string sym, double lots) const
     {
      double vmin = 0.0, vmax = 0.0, vstep = 0.0;
      SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN, vmin);
      SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX, vmax);
      SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP, vstep);
      if(vstep<=0.0) vstep = vmin;
      // derive digits from step
      int vdigits = 0; double tmp = vstep;
      for(int i=0;i<8 && (MathRound(tmp) != tmp); ++i) { tmp *= 10.0; vdigits++; }
      // clamp and snap
      double clamped = MathMax(MathMin(lots, vmax), vmin);
      double steps = MathFloor((clamped + 1e-12) / vstep);
      double snapped = steps * vstep;
      if(snapped < vmin) snapped = vmin;
      double norm = NormalizeDouble(snapped, vdigits);
      if(norm < vmin || norm > vmax)
        {
         PrintFormat("[PM] Normalized volume %.4f out of bounds [%.4f..%.4f] step=%.5f for %s, using min",
                     norm, vmin, vmax, vstep, sym);
         norm = vmin;
        }
      return norm;
     }
   // ATR helper
   bool            ComputeATR(const string sym, int period, double &atr_out) const
     {
      int handle = iATR(sym, _Period, period);
      if(handle==INVALID_HANDLE) return false;
      double buf[]; int copied = CopyBuffer(handle, 0, 0, 1, buf);
      IndicatorRelease(handle);
      if(copied!=1) return false;
      atr_out = buf[0];
      return true;
     }
   // Pearson correlation for two series
   bool            ComputeCorrelation(const string sym1, const string sym2, int bars, double &corr_out) const
     {
      if(bars<=2) return false;
      double a[], b[];
      int ca = CopyClose(sym1, _Period, 0, bars, a);
      int cb = CopyClose(sym2, _Period, 0, bars, b);
      if(ca<bars || cb<bars) return false;

      // Compute means
      double ma=0, mb=0; for(int i=0;i<bars;i++){ ma+=a[i]; mb+=b[i]; }
      ma/=bars; mb/=bars;
      // Compute covariance and stddevs
      double cov=0, va=0, vb=0;
      for(int i=0;i<bars;i++)
        {
         double da=a[i]-ma; double db=b[i]-mb;
         cov += da*db; va += da*da; vb += db*db;
        }
      if(va<=0 || vb<=0) return false;
      corr_out = cov / MathSqrt(va*vb);
      // Clamp numerical noise
      if(corr_out>1.0) corr_out=1.0; if(corr_out<-1.0) corr_out=-1.0;
      return true;
     }

public:
   CPositionManager()
     {
      m_symbol = _Symbol;
      m_magic = 0;
      m_atr_period = 14;
      m_scale_activation_pts = 0;
      m_trailing_pts = 0;
      m_trailing_step_pts = 0;
      m_dynamic_risk_enabled = false;
      m_max_daily_dd_pct = 5.0;
      m_max_pos_risk_pct = 2.0;
      m_max_portfolio_risk_pct = 20.0;
      m_risk_decay = 0.9;
      m_adaptive_sizing_enabled = false;
      m_min_size_mult = 0.5;
      m_max_size_mult = 1.5;
      m_scaling_profile = SCALING_MODERATE;
      m_exit_profile = EXIT_MODERATE;
      m_vol_exit_enabled = false;
      m_vol_exit_atr_mult = 0.0;
      m_ml_enabled = false;
      m_ml_threshold = 0.0;
      m_ml_model_path = "";
      m_ml_loaded = false;
      m_oco_groups.Clear();
     }

   // Initialize with explicit tuning values (mirrors guide usage; unused params are placeholders for future expansion)
   bool Initialize(CTrade &/*trade*/, const string symbol, int atrPeriod, int scaleActivationPts, int trailingPts, int trailingStepPts)
     {
      m_symbol = symbol;
      m_atr_period = (atrPeriod>0 ? atrPeriod : 14);
      m_scale_activation_pts = MathMax(0, scaleActivationPts);
      m_trailing_pts = MathMax(0, trailingPts);
      m_trailing_step_pts = MathMax(0, trailingStepPts);
      if(!EnsureSymbolReady(m_symbol)) return false;
      return true;
     }

   // Alternative initializer when no external CTrade reference is supplied
   bool InitializeSimple(const string symbol, int atrPeriod, int scaleActivationPts, int trailingPts, int trailingStepPts)
     {
      m_symbol = symbol;
      m_atr_period = (atrPeriod>0 ? atrPeriod : 14);
      m_scale_activation_pts = MathMax(0, scaleActivationPts);
      m_trailing_pts = MathMax(0, trailingPts);
      m_trailing_step_pts = MathMax(0, trailingStepPts);
      if(!EnsureSymbolReady(m_symbol)) return false;
      return true;
     }

   void SetMagicNumber(const int magic) { m_magic = magic; m_trade.SetExpertMagicNumber(m_magic); }

   // --- Configuration APIs from the guide
   void SetDynamicRisk(const bool enable, const double maxDailyDDPct, const double maxPosRiskPct, const double maxPortfolioRiskPct, const double decay)
     {
      m_dynamic_risk_enabled = enable;
      m_max_daily_dd_pct = maxDailyDDPct;
      m_max_pos_risk_pct = maxPosRiskPct;
      m_max_portfolio_risk_pct = maxPortfolioRiskPct;
      m_risk_decay = decay;
     }
   void SetAdaptiveSizing(const bool enable, const double minMult, const double maxMult)
     {
      m_adaptive_sizing_enabled = enable;
      m_min_size_mult = minMult;
      m_max_size_mult = maxMult;
     }
   void SetScalingProfile(const ScalingProfile p) { m_scaling_profile = p; }
   void SetExitProfile(const ExitProfile p) { m_exit_profile = p; }
   void SetMLIntegration(const bool enable, const double threshold)
     {
      m_ml_enabled = enable; m_ml_threshold = threshold;
     }
   void SetVolatilityExit(const bool enable, const double atrMultiple)
     {
      m_vol_exit_enabled = enable; m_vol_exit_atr_mult = atrMultiple;
     }

   // --- Scaling logic
   bool CheckScalingOpportunity(const ulong ticket, double &volume_out)
     {
      volume_out = 0.0;
      // Locate position by ticket
      CPositionInfo pos; bool found=false;
      for(int i=0;i<PositionsTotal();++i)
        {
         if(!pos.SelectByIndex(i)) continue;
         if((ulong)pos.Ticket()==ticket) { found=true; break; }
        }
      if(!found) return false;
      string sym = pos.Symbol(); if(sym!="") m_symbol = sym;
      if(!EnsureSymbolReady(m_symbol)) return false;

      // Simple rule: scale if profit exceeds activation threshold in points
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double bid=0, ask=0; SymbolInfoDouble(m_symbol, SYMBOL_BID, bid); SymbolInfoDouble(m_symbol, SYMBOL_ASK, ask);
      double open = pos.PriceOpen();
      double activation_px = m_scale_activation_pts * point;
      bool can_scale=false;
      if(pos.PositionType()==POSITION_TYPE_BUY)  can_scale = (bid - open) > activation_px;
      if(pos.PositionType()==POSITION_TYPE_SELL) can_scale = (open - ask) > activation_px;
      if(!can_scale) return false;

      // base volume: current symbol min lot, optionally adjusted for correlation later
      double vmin=0; SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN, vmin);
      double base = vmin;
      // adaptive sizing: expand towards max step with profile
      double mult = 1.0;
      if(m_adaptive_sizing_enabled)
        {
         if(m_scaling_profile==SCALING_AGGRESSIVE) mult = m_max_size_mult;
         else if(m_scaling_profile==SCALING_CONSERVATIVE) mult = m_min_size_mult;
         else mult = (m_min_size_mult + m_max_size_mult)*0.5;
        }
      double proposed = NormalizeVolume(m_symbol, base * mult);
      if(proposed<=0.0) return false;

      // Dynamic risk cap (very simplified check against position size growth)
      if(m_dynamic_risk_enabled)
        {
         double cur_vol = pos.Volume();
         double max_add = cur_vol * 0.5; // cap additional 50% of current position
         if(proposed > max_add) proposed = NormalizeVolume(m_symbol, max_add);
         if(proposed<=0.0) return false;
        }

      volume_out = proposed;
      return true;
     }

   bool ScaleInPosition(const ulong ticket, const double volume)
     {
      if(volume<=0.0) return false;
      CPositionInfo pos; bool found=false;
      for(int i=0;i<PositionsTotal();++i){ if(!pos.SelectByIndex(i)) continue; if((ulong)pos.Ticket()==ticket){ found=true; break; } }
      if(!found) return false;
      string sym = pos.Symbol(); if(sym!="") m_symbol = sym; if(!EnsureSymbolReady(m_symbol)) return false;
      double vol = NormalizeVolume(m_symbol, volume); if(vol<=0.0) return false;

      if(pos.PositionType()==POSITION_TYPE_BUY)  return m_trade.Buy(vol, m_symbol);
      if(pos.PositionType()==POSITION_TYPE_SELL) return m_trade.Sell(vol, m_symbol);
      return false;
     }

   bool ScaleOutPosition(const ulong ticket, const double volume_to_reduce)
     {
      if(volume_to_reduce<=0.0) return false;
      // locate position
      CPositionInfo pos; bool found=false; int idx=-1;
      for(int i=0;i<PositionsTotal();++i){ if(!pos.SelectByIndex(i)) continue; if((ulong)pos.Ticket()==ticket){ found=true; idx=i; break; } }
      if(!found) return false;
      string sym = pos.Symbol(); if(sym!="") m_symbol=sym; if(!EnsureSymbolReady(m_symbol)) return false;
      double vol = NormalizeVolume(m_symbol, volume_to_reduce); if(vol<=0.0) return false;
      return m_trade.PositionClosePartial(sym, vol);
     }

   // --- Exit logic
   bool CheckExitConditions(const ulong ticket, double &close_price_out, string &reason_out)
     {
      close_price_out = 0.0; reason_out = "";
      CPositionInfo pos; bool found=false;
      for(int i=0;i<PositionsTotal();++i){ if(!pos.SelectByIndex(i)) continue; if((ulong)pos.Ticket()==ticket){ found=true; break; } }
      if(!found) return false;
      string sym = pos.Symbol(); if(sym!="") m_symbol=sym; if(!EnsureSymbolReady(m_symbol)) return false;
      double bid=0, ask=0; SymbolInfoDouble(m_symbol, SYMBOL_BID, bid); SymbolInfoDouble(m_symbol, SYMBOL_ASK, ask);

      // Volatility-based exit using ATR
      if(m_vol_exit_enabled && m_vol_exit_atr_mult>0.0)
        {
         double atr=0.0; if(ComputeATR(m_symbol, m_atr_period, atr))
           {
            if(pos.PositionType()==POSITION_TYPE_BUY)
              {
               double trail = bid - (atr * m_vol_exit_atr_mult);
               if(pos.StopLoss()>0.0 && trail<=pos.StopLoss()) { /* SL already protective enough */ }
               else if(trail>0.0)
                 {
                  // If price falls under trail by 1 tick, consider exit
                  if(bid <= trail - TickSize(m_symbol)) { close_price_out = bid; reason_out = "VolatilityExit"; return true; }
                 }
              }
            else if(pos.PositionType()==POSITION_TYPE_SELL)
              {
               double trail = ask + (atr * m_vol_exit_atr_mult);
               if(pos.StopLoss()>0.0 && trail>=pos.StopLoss()) { }
               else if(trail>0.0)
                 {
                  if(ask >= trail + TickSize(m_symbol)) { close_price_out = ask; reason_out = "VolatilityExit"; return true; }
                 }
              }
           }
        }

      // Profile-based simplified exit (time-independent, placeholder)
      double profit_pts = 0.0; double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pos.PositionType()==POSITION_TYPE_BUY)  profit_pts = (bid - pos.PriceOpen())/point;
      if(pos.PositionType()==POSITION_TYPE_SELL) profit_pts = (pos.PriceOpen() - ask)/point;
      double tp_thresh=0, sl_thresh=0;
      if(m_exit_profile==EXIT_AGGRESSIVE) { tp_thresh=20; sl_thresh=-10; }
      else if(m_exit_profile==EXIT_CONSERVATIVE) { tp_thresh=80; sl_thresh=-40; }
      else { tp_thresh=40; sl_thresh=-20; }

      if(profit_pts>=tp_thresh) { close_price_out = (pos.PositionType()==POSITION_TYPE_BUY? bid: ask); reason_out = "ProfileTP"; return true; }
      if(profit_pts<=sl_thresh) { close_price_out = (pos.PositionType()==POSITION_TYPE_BUY? bid: ask); reason_out = "ProfileSL"; return true; }

      return false;
     }

   bool ClosePosition(const ulong ticket, const string reason)
     {
      CPositionInfo pos; bool found=false; for(int i=0;i<PositionsTotal();++i){ if(!pos.SelectByIndex(i)) continue; if((ulong)pos.Ticket()==ticket){ found=true; break; } }
      if(!found) return false; string sym = pos.Symbol(); if(sym=="") return false; if(!EnsureSymbolReady(sym)) return false;
      bool ok = m_trade.PositionClose(sym);
      if(ok) PrintFormat("[PM] Closed %s ticket=%I64u reason=%s", sym, ticket, reason);
      return ok;
     }

   // --- Correlation
   double GetPortfolioCorrelation(const string symbol) const
     {
      // Average of absolute correlations to open positions, weighted by volume
      double total_w=0.0, sum=0.0;
      for(int i=0;i<PositionsTotal();++i)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket==0) continue;
         if(!PositionSelectByTicket(ticket)) continue;
         string sym = PositionGetString(POSITION_SYMBOL);
         if(sym=="" || sym==symbol) continue;
         double vol = PositionGetDouble(POSITION_VOLUME);
         double corr=0.0; if(ComputeCorrelation(symbol, sym, 200, corr))
           { sum += MathAbs(corr)*vol; total_w += vol; }
        }
      if(total_w<=0.0) return 0.0;
      return sum/total_w;
     }

   double CalculateCorrelationAdjustedVolume(const string symbol, const double baseVolume)
     {
      double corr = GetPortfolioCorrelation(symbol);
      // reduce size as correlation grows (simple linear dampener)
      double factor = 1.0 - MathMin(1.0, MathAbs(corr));
      double vol = baseVolume * factor;
      return NormalizeVolume(symbol, vol);
     }

   double GetMarketCorrelation(const string sym1, const string sym2, const int bars)
     {
      double corr=0.0; if(!ComputeCorrelation(sym1, sym2, bars, corr)) return 0.0; return corr;
     }

   // --- Adaptive position cap helper for gating
   // Returns a dynamic cap on concurrent open positions based on current risk conditions.
   // cap_hint: static configured cap (<=0 means unlimited).
   int ComputeDynamicMaxOpenPositions(const int cap_hint) const
     {
      // Unlimited semantics preserved
      if(cap_hint<=0) return 0;

      int cap = cap_hint;

      // 1) Margin health-based adjustment
      double ml = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      if(ml>0.0)
        {
         if(ml < 120.0) cap = MathMax(1, cap - 2);       // very low margin headroom -> tighten more
         else if(ml < 200.0) cap = MathMax(1, cap - 1);  // low headroom -> tighten
         else if(ml > 500.0) cap = cap + 1;              // ample headroom -> allow slight expansion
        }

      // 2) Volatility regime (ATR%) adjustment
      double atr=0.0; double px=0.0; SymbolInfoDouble(m_symbol, SYMBOL_BID, px);
      if(px<=0.0) SymbolInfoDouble(m_symbol, SYMBOL_LAST, px);
      if(px>0.0 && ComputeATR(m_symbol, m_atr_period, atr))
        {
         double atr_pct = 100.0 * atr / px;
         if(atr_pct > 2.0)        cap = MathMax(1, cap - 1); // very high vol -> reduce
         else if(atr_pct < 0.4)   cap = cap + 1;             // very low vol -> allow one more
        }

      // 3) Portfolio correlation concentration adjustment
      double pcorr = 0.0;
      // Use average abs correlation to open positions; concentrates -> reduce cap
      pcorr = GetPortfolioCorrelation(m_symbol);
      if(MathAbs(pcorr) > 0.75) cap = MathMax(1, cap - 1);

      return cap;
     }

   // --- ML stubs
   bool LoadMLModel(const string file)
     {
      // Try user Files or Common Files
      int h = FileOpen(file, FILE_READ|FILE_TXT);
      if(h==INVALID_HANDLE)
        {
         if(!FileIsExist(file, FILE_COMMON)) { m_ml_loaded=false; m_ml_model_path=""; return false; }
         h = FileOpen(file, FILE_READ|FILE_TXT|FILE_COMMON);
         if(h==INVALID_HANDLE) { m_ml_loaded=false; m_ml_model_path=""; return false; }
        }
      FileClose(h);
      m_ml_model_path = file; m_ml_loaded = true; return true;
     }

   double GetMLPositionScore(const string symbol, const ENUM_POSITION_TYPE ptype)
     {
      if(!m_ml_enabled || !m_ml_loaded) return 0.5; // Neutral when ML disabled
      
      // Advanced ML position scoring based on market conditions
      double score = 0.5; // Base neutral score
      
      // Factor 1: Volatility analysis
      int atr_handle = iATR(symbol, PERIOD_H1, 14);
      double atr_buffer[1];
      if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) == 1)
        {
         double current_price = (ptype == POSITION_TYPE_BUY) ? 
                               SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                               SymbolInfoDouble(symbol, SYMBOL_BID);
         double volatility_ratio = atr_buffer[0] / current_price;
         
         // Higher volatility increases risk, lower score for aggressive positions
         if(volatility_ratio > 0.02) // High volatility threshold
           score -= 0.15;
         else if(volatility_ratio < 0.005) // Low volatility
           score += 0.1;
        }
      
      // Factor 2: Trend strength analysis
      int adx_handle = iADX(symbol, PERIOD_H1, 14);
      double adx_buffer[1];
      if(CopyBuffer(adx_handle, 0, 0, 1, adx_buffer) == 1)
        {
         double adx_value = adx_buffer[0];
         if(adx_value > 25) // Strong trend
           score += 0.2;
         else if(adx_value < 15) // Weak trend/ranging
           score -= 0.1;
        }
      
      // Factor 3: RSI momentum analysis
      int rsi_handle = iRSI(symbol, PERIOD_H1, 14, PRICE_CLOSE);
      double rsi_buffer[1];
      if(CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer) == 1)
        {
         double rsi_value = rsi_buffer[0];
         if(ptype == POSITION_TYPE_BUY)
           {
            if(rsi_value < 30) score += 0.15; // Oversold, good for buy
            else if(rsi_value > 70) score -= 0.15; // Overbought, bad for buy
           }
         else // SELL position
           {
            if(rsi_value > 70) score += 0.15; // Overbought, good for sell
            else if(rsi_value < 30) score -= 0.15; // Oversold, bad for sell
           }
        }
      
      // Factor 4: Market session analysis
      datetime current_time = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(current_time, dt);
      
      // Prefer trading during active sessions
      if((dt.hour >= 8 && dt.hour <= 12) || (dt.hour >= 13 && dt.hour <= 17)) // London/NY overlap
        score += 0.1;
      else if(dt.hour >= 22 || dt.hour <= 6) // Low activity period
        score -= 0.1;
      
      // Clamp score to valid range [0, 1]
      return MathMax(0.0, MathMin(1.0, score));
     }

   bool UpdateMLModel(MqlRates &rates[], double &features[])
     {
      if(!m_ml_enabled) return true;
      
      // Enhanced ML model update with feature engineering
      int rates_count = ArraySize(rates);
      if(rates_count < 10) return false; // Need minimum data
      
      // Calculate technical indicators as features
      ArrayResize(features, 0);
      
      // Feature 1-3: Price action features
      double price_change = (rates[0].close - rates[1].close) / rates[1].close;
      double volume_ratio = (double)rates[0].tick_volume / rates[1].tick_volume;
      double hl_ratio = (rates[0].high - rates[0].low) / rates[0].close;
      
      // Feature 4-6: Moving averages
      double ma_fast = 0, ma_slow = 0;
      int ma_fast_period = 5, ma_slow_period = 20;
      
      for(int i = 0; i < MathMin(ma_fast_period, rates_count); i++)
        ma_fast += rates[i].close;
      ma_fast /= MathMin(ma_fast_period, rates_count);
      
      for(int i = 0; i < MathMin(ma_slow_period, rates_count); i++)
        ma_slow += rates[i].close;
      ma_slow /= MathMin(ma_slow_period, rates_count);
      
      double ma_ratio = ma_fast / ma_slow;
      
      // Feature 7-8: Volatility features
      double volatility = 0;
      for(int i = 1; i < MathMin(10, rates_count); i++)
        {
         double change = (rates[i-1].close - rates[i].close) / rates[i].close;
         volatility += change * change;
        }
      volatility = MathSqrt(volatility / MathMin(9, rates_count - 1));
      
      // Feature 9: Time-based feature
      MqlDateTime dt;
      TimeToStruct(rates[0].time, dt);
      double time_feature = (double)dt.hour / 24.0;
      
      // Compile features array
      ArrayResize(features, 9);
      features[0] = price_change;
      features[1] = volume_ratio;
      features[2] = hl_ratio;
      features[3] = ma_ratio;
      features[4] = volatility;
      features[5] = time_feature;
      features[6] = (rates[0].close > ma_fast) ? 1.0 : 0.0; // Above fast MA
      features[7] = (ma_fast > ma_slow) ? 1.0 : 0.0; // Fast > Slow MA
      features[8] = (rates[0].close > rates[1].close) ? 1.0 : 0.0; // Price up
      
      // Update internal ML state (simplified)
      m_ml_threshold = 0.6; // Dynamic threshold based on market conditions
      if(volatility > 0.02) m_ml_threshold = 0.7; // Higher threshold in volatile markets
      
      PrintFormat("ML Model Updated: %d features, threshold=%.2f, volatility=%.4f", 
                  ArraySize(features), m_ml_threshold, volatility);
      
      return true;
     }

   // --- Advanced Orders
   bool PlaceBracketOrder(const string symbol,
                          const ENUM_ORDER_TYPE order_type,
                          const double volume,
                          double entry_price,
                          double stop_loss,
                          double take_profit,
                          const double break_even_at,
                          const int trailing_stop_points,
                          const datetime expiration,
                          const string comment)
     {
      if(!EnsureSymbolReady(symbol)) return false;
      double vol = NormalizeVolume(symbol, volume); if(vol<=0.0) return false;
      double minDist = MathMax(MinStopDistance(symbol), FreezeDistance(symbol));
      double bid=0, ask=0; SymbolInfoDouble(symbol, SYMBOL_BID, bid); SymbolInfoDouble(symbol, SYMBOL_ASK, ask);

      // Normalize entry/SL/TP to broker rules
      if(order_type==ORDER_TYPE_BUY || order_type==ORDER_TYPE_BUY_LIMIT || order_type==ORDER_TYPE_BUY_STOP)
        {
         if(stop_loss>0.0 && (stop_loss>=bid || (bid-stop_loss)<minDist)) stop_loss = RoundToTickBelow(bid-minDist, symbol);
         if(take_profit>0.0 && (take_profit<=ask || (take_profit-ask)<minDist)) take_profit = RoundToTickAbove(ask+minDist, symbol);
        }
      else if(order_type==ORDER_TYPE_SELL || order_type==ORDER_TYPE_SELL_LIMIT || order_type==ORDER_TYPE_SELL_STOP)
        {
         if(stop_loss>0.0 && (stop_loss<=ask || (stop_loss-ask)<minDist)) stop_loss = RoundToTickAbove(ask+minDist, symbol);
         if(take_profit>0.0 && (take_profit>=bid || (bid-take_profit)<minDist)) take_profit = RoundToTickBelow(bid-minDist, symbol);
        }
      if(order_type==ORDER_TYPE_BUY_LIMIT || order_type==ORDER_TYPE_SELL_LIMIT || order_type==ORDER_TYPE_BUY_STOP || order_type==ORDER_TYPE_SELL_STOP)
        {
         // Adjust pending entry distance
         if(order_type==ORDER_TYPE_BUY_LIMIT && entry_price>=bid-minDist) entry_price = RoundToTickBelow(bid-minDist, symbol);
         if(order_type==ORDER_TYPE_SELL_LIMIT && entry_price<=ask+minDist) entry_price = RoundToTickAbove(ask+minDist, symbol);
         if(order_type==ORDER_TYPE_BUY_STOP  && entry_price<=ask+minDist) entry_price = RoundToTickAbove(ask+minDist, symbol);
         if(order_type==ORDER_TYPE_SELL_STOP && entry_price>=bid-minDist) entry_price = RoundToTickBelow(bid-minDist, symbol);
        }

      bool ok=false;
      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetAsyncMode(false);
      m_trade.SetDeviationInPoints(20);
      if(order_type==ORDER_TYPE_BUY)        ok = m_trade.Buy(vol, symbol, 0, stop_loss, take_profit);
      else if(order_type==ORDER_TYPE_SELL)  ok = m_trade.Sell(vol, symbol, 0, stop_loss, take_profit);
      else if(order_type==ORDER_TYPE_BUY_STOP)  ok = m_trade.BuyStop(vol, entry_price, symbol, stop_loss, take_profit);
      else if(order_type==ORDER_TYPE_SELL_STOP) ok = m_trade.SellStop(vol, entry_price, symbol, stop_loss, take_profit);
      else if(order_type==ORDER_TYPE_BUY_LIMIT) ok = m_trade.BuyLimit(vol, entry_price, symbol, stop_loss, take_profit);
      else if(order_type==ORDER_TYPE_SELL_LIMIT)ok = m_trade.SellLimit(vol, entry_price, symbol, stop_loss, take_profit);

      if(!ok) return false;

      // Simple break-even/trailing management is left to caller via periodic checks
      // Caller can use CheckExitConditions (volatility) and their own trailing logic.
      return true;
     }

   bool PlaceOCOOrders(const string symbol,
                       const ENUM_ORDER_TYPE base_type, // BUY_STOP or SELL_STOP (we'll place the opposite too)
                       const double volume,
                       double price1,
                       double price2,
                       double stop_loss,
                       double take_profit,
                       const string comment)
     {
      if(!EnsureSymbolReady(symbol)) return false;
      double vol = NormalizeVolume(symbol, volume); if(vol<=0.0) return false;
      double minDist = MathMax(MinStopDistance(symbol), FreezeDistance(symbol));
      double bid=0, ask=0; SymbolInfoDouble(symbol, SYMBOL_BID, bid); SymbolInfoDouble(symbol, SYMBOL_ASK, ask);
      // normalize prices
      if(base_type==ORDER_TYPE_BUY_STOP || base_type==ORDER_TYPE_BUY_LIMIT)
        { if(price1<=ask+minDist) price1=RoundToTickAbove(ask+minDist, symbol); if(price2>=bid-minDist) price2=RoundToTickBelow(bid-minDist, symbol); }
      else
        { if(price2<=ask+minDist) price2=RoundToTickAbove(ask+minDist, symbol); if(price1>=bid-minDist) price1=RoundToTickBelow(bid-minDist, symbol); }

      // Derive pair types
      ENUM_ORDER_TYPE t1, t2;
      if(base_type==ORDER_TYPE_BUY_STOP || base_type==ORDER_TYPE_BUY_LIMIT) { t1 = ORDER_TYPE_BUY_STOP; t2 = ORDER_TYPE_SELL_STOP; }
      else { t1 = ORDER_TYPE_SELL_STOP; t2 = ORDER_TYPE_BUY_STOP; }

      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetAsyncMode(false);
      m_trade.SetDeviationInPoints(20);

      bool ok1=false, ok2=false;
      ulong ticket1=0, ticket2=0;
      if(t1==ORDER_TYPE_BUY_STOP) ok1 = m_trade.BuyStop(vol, price1, symbol, stop_loss, take_profit);
      else                        ok1 = m_trade.SellStop(vol, price1, symbol, stop_loss, take_profit);
      if(ok1) ticket1 = m_trade.ResultOrder();

      if(t2==ORDER_TYPE_BUY_STOP) ok2 = m_trade.BuyStop(vol, price2, symbol, stop_loss, take_profit);
      else                        ok2 = m_trade.SellStop(vol, price2, symbol, stop_loss, take_profit);
      if(ok2) ticket2 = m_trade.ResultOrder();

      if(!(ok1 && ok2))
        {
         // If one failed, try to clean up the other
         if(ok1 && ticket1>0) m_trade.OrderDelete(ticket1);
         if(ok2 && ticket2>0) m_trade.OrderDelete(ticket2);
         return false;
        }

      COCOGroup *grp = new COCOGroup();
      grp.ticket1 = ticket1; grp.ticket2 = ticket2; grp.comment = comment;
      m_oco_groups.Add(grp);
      return true;
     }

   // Call periodically to enforce OCO semantics: if one triggers/cancels, delete the peer order
   void MaintainOCO()
     {
      for(int i=m_oco_groups.Total()-1; i>=0; --i)
        {
         COCOGroup *g = (COCOGroup*)m_oco_groups.At(i);
         if(CheckPointer(g)==POINTER_INVALID) { m_oco_groups.Delete(i); continue; }

         bool ex1 = OrderSelect(g.ticket1); bool ex2 = OrderSelect(g.ticket2);
         // If one no longer exists (filled or canceled), cancel the peer if still pending
         if(ex1 && !ex2)
           {
            m_trade.OrderDelete(g.ticket1);
            m_oco_groups.Delete(i);
           }
         else if(!ex1 && ex2)
           {
            m_trade.OrderDelete(g.ticket2);
            m_oco_groups.Delete(i);
           }
         else if(!ex1 && !ex2)
           {
            // Both gone, nothing to maintain
            m_oco_groups.Delete(i);
           }
        }
     }
  };
