//+------------------------------------------------------------------+
//|                                                   CascadeGreepEA |
//|                                   Copyright 2025 Cascade (AI)    |
//|                              Purpose: ATR-risk FX/Gold mean-rev  |
//+------------------------------------------------------------------+
#property copyright "Cascade AI"
#property link      "https://windsurf.ai"
#property version   "1.0"
#property strict

#include <Trade/Trade.mqh>

//==================== Inputs ====================
input group           "Risk Management"
input double          InpRiskPercent              = 1.0;     // per-trade risk % of equity (1.0 - 2.0)
input double          InpKillSwitchDDPercent      = 2.0;     // stop trading if equity DD >= this % from start
input int             InpMaxOpenPositions         = 5;       // cap across entire account
input bool            InpAllowTradeIfBelowMinLot  = true;    // if true, will use min lot even if > risk (guarded by caps)
input bool            InpCloseOnKillSwitch        = true;    // close EA positions when DD hit

input group           "Signals"
input ENUM_TIMEFRAMES InpSignalTF                 = PERIOD_M15;
input int             InpSMAPeriod                = 200;     // trend filter
input bool            InpUseTrendFilter           = true;
input int             InpRSIPeriod                = 2;
input int             InpRSILow                   = 5;       // buy when RSI <= low (with trend filter)
input int             InpRSIHigh                  = 95;      // sell when RSI >= high (with trend filter)
input bool            InpAllowLong                = true;
input bool            InpAllowShort               = true;

input group           "Stops/Targets"
input int             InpATRPeriod                = 14;
input double          InpATRMultiplierSL          = 2.0;     // SL = ATR * mult
input bool            InpUseTrailing              = true;
input double          InpTrailATRMultiplier       = 1.0;     // trail distance in ATR
input double          InpTP_ATR_Mult              = 0.0;     // 0 disables fixed TP; else TP = ATR * mult

input group           "Execution Safety"
input int             InpMaxSpreadPoints          = 30;       // max allowed spread (points); 0 disables
input double          InpMaxATRPoints             = 0.0;      // max allowed ATR (points); 0 disables
input double          InpDailyLossLimitPercent    = 2.0;      // block trading for the day if daily DD >= this %
input bool            InpCloseOnDailyLoss         = true;     // close EA positions when daily loss hit
input int             InpMinBarsBetweenTrades     = 3;        // cooldown per symbol/timeframe
input double          InpMaxRiskPctWhenForcingMinLot      = 5.0; // cap risk % when min lot is used
input double          InpMaxRiskPctWhenForcingMinLot_XAU  = 3.0; // stricter cap for XAU/GOLD

input group           "Misc"
input long            InpMagic                    = 420250810; // unique EA id
input int             InpMaxSlippagePoints        = 10;       // allowed slippage in points for market orders

input group           "Master Adjustments"
input bool            InpUseMasterAdjust          = true;     // read dynamic factors from Master EA
input string          InpGVNamespaceEA            = "CGreep"; // must match Master EA namespace

//==================== Globals ====================
CTrade   trade;
double   g_start_equity = 0.0;
string   g_symbol;
bool     g_trading_disabled = false;

int      hATR = INVALID_HANDLE;
int      hRSI = INVALID_HANDLE;
int      hSMA = INVALID_HANDLE;

datetime g_last_bar_time = 0;
datetime g_last_trade_bar_time = 0;
bool     g_daily_blocked = false;
int      g_day_key = 0;
double   g_day_equity_start = 0.0;

//==================== Utility ====================
bool CopyOne(const int handle, const int buffer, const int shift, double &out)
{
   double tmp[];
   if(CopyBuffer(handle, buffer, shift, 1, tmp) != 1)
      return false;
   out = tmp[0];
   return true;
}

bool GetATR(const int shift, double &atr)
{
   if(hATR==INVALID_HANDLE) return false;
   return CopyOne(hATR, 0, shift, atr);
}

bool GetRSI(const int shift, double &rsi)
{
   if(hRSI==INVALID_HANDLE) return false;
   return CopyOne(hRSI, 0, shift, rsi);
}

bool GetSMA(const int shift, double &sma)
{
   if(hSMA==INVALID_HANDLE) return false;
   return CopyOne(hSMA, 0, shift, sma);
}

bool SymbolIsXAU(const string sym)
{
   return (StringFind(sym, "XAU", 0) >= 0 || StringFind(sym, "GOLD", 0) >= 0);
}

int TodayKey()
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
   return (dt.year*10000 + dt.mon*100 + dt.day);
}

void DailyResetIfNeeded()
{
   int key = TodayKey();
   if(key != g_day_key)
   {
      g_day_key = key;
      g_day_equity_start = AccountInfoDouble(ACCOUNT_EQUITY);
      g_daily_blocked = false;
      Print("[RESET] New day baseline equity=", g_day_equity_start);
   }
}

bool CheckDailyLossLimit()
{
   if(g_daily_blocked) return true;
   if(g_day_equity_start<=0) return false;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddpct = (g_day_equity_start - eq) / g_day_equity_start * 100.0;
   if(ddpct >= InpDailyLossLimitPercent)
   {
      g_daily_blocked = true;
      Print("[DAILY] Loss limit ", DoubleToString(ddpct,2), "% >= ", InpDailyLossLimitPercent, "%. Trading disabled for today.");
      if(InpCloseOnDailyLoss) CloseEAPositions();
      return true;
   }
   return false;
}

bool CheckSpreadAtrOK(const double atr)
{
   MqlTick t; if(!SymbolInfoTick(g_symbol, t)) return false;
   double spread_pts = (t.ask - t.bid) / _Point;
   if(InpMaxSpreadPoints>0 && spread_pts > InpMaxSpreadPoints)
   {
      PrintFormat("[SKIP] Spread %.1f pts > max %d", spread_pts, InpMaxSpreadPoints);
      return false;
   }
   if(InpMaxATRPoints>0.0)
   {
      double atr_pts = atr / _Point;
      if(atr_pts > InpMaxATRPoints)
      {
         PrintFormat("[SKIP] ATR %.1f pts > max %.1f pts", atr_pts, InpMaxATRPoints);
         return false;
      }
   }
   return true;
}

int CountAllOpenPositions()
{
   return (int)PositionsTotal();
}

bool HasAnyPositionForSymbol(const string sym)
{
   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      string psym = PositionGetString(POSITION_SYMBOL);
      if(psym==sym) return true;
   }
   return false;
}

int CountEAPositions()
{
   int count=0;
   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(magic==InpMagic) count++;
   }
   return count;
}

void CloseEAPositions()
{
   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      long   mgc = (long)PositionGetInteger(POSITION_MAGIC);
      long   type= (long)PositionGetInteger(POSITION_TYPE);
      double vol = PositionGetDouble(POSITION_VOLUME);
      if(mgc!=InpMagic) continue;
      if(type==POSITION_TYPE_BUY)
         trade.PositionClose(sym);
      else if(type==POSITION_TYPE_SELL)
         trade.PositionClose(sym);
   }
}

bool CheckKillSwitch()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_start_equity<=0) return false;
   double ddpct = (g_start_equity - eq) / g_start_equity * 100.0;
   if(ddpct >= InpKillSwitchDDPercent)
   {
      if(!g_trading_disabled)
      {
         g_trading_disabled = true;
         Print("[KILL] Drawdown ", DoubleToString(ddpct,2), "% >= ", InpKillSwitchDDPercent, "%. Trading disabled.");
         if(InpCloseOnKillSwitch) CloseEAPositions();
      }
      return true;
   }
   return false;
}

bool CalcLotsForRisk(const string sym, const double risk_money, const double entry_price, const double sl_price, double &lots, const double cap_scale=1.0)
{
   lots = 0.0;
   double ticksize = 0, tickvalue = 0, minlot=0, maxlot=0, lotstep=0;
   if(!SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE, ticksize)) return false;
   if(!SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE, tickvalue)) return false;
   if(!SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN, minlot)) return false;
   if(!SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX, maxlot)) return false;
   if(!SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP, lotstep)) return false;
   double delta = MathAbs(entry_price - sl_price);
   if(delta<=0 || ticksize<=0 || tickvalue<=0) return false;
   double ticks = delta / ticksize;
   double risk_per_lot = ticks * tickvalue; // currency per 1.00 lot
   if(risk_per_lot<=0) return false;
   double raw_lots = risk_money / risk_per_lot;
   if(raw_lots<=0) { lots=0; return true; }
   // snap to step without exceeding target risk
   if(lotstep>0)
      raw_lots = MathFloor(raw_lots/lotstep) * lotstep;
   lots = raw_lots;
   // clamp
   if(lots>maxlot) lots=maxlot;
   if(lots<minlot)
   {
      if(InpAllowTradeIfBelowMinLot)
      {
         double eq = AccountInfoDouble(ACCOUNT_EQUITY);
         double riskpct_minlot = (risk_per_lot * minlot) / eq * 100.0;
         double cap = SymbolIsXAU(sym) ? InpMaxRiskPctWhenForcingMinLot_XAU : InpMaxRiskPctWhenForcingMinLot;
         // scale cap downward only (never raise above baseline)
         double scale = MathMin(1.0, cap_scale);
         cap *= scale;
         if(riskpct_minlot > cap)
         {
            PrintFormat("[SKIP] Min-lot risk %.2f%% > cap %.2f%% on %s", riskpct_minlot, cap, sym);
            lots = 0.0; // too risky
         }
         else
         {
            lots = minlot; // accept min lot under cap
         }
      }
      else
         lots = 0.0; // skip trade
   }
   // normalize to lot step digits
   int step_digits = 0;
   if(lotstep>0) step_digits = (int)MathRound(MathLog10(1.0/lotstep));
   lots = NormalizeDouble(lots, MathMax(0, step_digits));
   return true;
}

void ManageTrailing()
{
   if(!InpUseTrailing) return;
   MqlTick t; if(!SymbolInfoTick(g_symbol,t)) return;
   double atr; if(!GetATR(1, atr)) return;
   // apply master adjustments to trailing distance (wider SL under stress)
   double rf, slm, cdm; GetAdjustments(rf, slm, cdm);
   for(int i=PositionsTotal()-1; i>=0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      string psym = PositionGetString(POSITION_SYMBOL);
      if(psym!=g_symbol) continue; // only manage current chart symbol to avoid multi-symbol side effects
      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      if(magic!=InpMagic) continue;
      long  type  = (long)PositionGetInteger(POSITION_TYPE);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double desired_sl;
      if(type==POSITION_TYPE_BUY)
      {
         desired_sl = t.bid - atr * InpTrailATRMultiplier * slm;
         if(sl==0 || desired_sl>sl)
            trade.PositionModify(psym, desired_sl, tp);
      }
      else if(type==POSITION_TYPE_SELL)
      {
         desired_sl = t.ask + atr * InpTrailATRMultiplier * slm;
         if(sl==0 || desired_sl<sl)
            trade.PositionModify(psym, desired_sl, tp);
      }
   }
}

bool NewBarOnSignalTF()
{
   datetime bt = iTime(g_symbol, InpSignalTF, 0);
   if(bt==0) return false;
   if(bt!=g_last_bar_time)
   {
      g_last_bar_time = bt;
      return true;
   }
   return false;
}

bool GetSignal(bool &buySignal, bool &sellSignal)
{
   buySignal=false; sellSignal=false;
   double rsi; if(!GetRSI(1, rsi)) return false;
   double sma=0, close1=0;
   if(InpUseTrendFilter)
   {
      if(!GetSMA(1, sma)) return false;
      double tmp[]; if(CopyClose(g_symbol, InpSignalTF, 1, 1, tmp)!=1) return false; close1=tmp[0];
   }
   bool upTrend = !InpUseTrendFilter || (close1 > sma);
   bool dnTrend = !InpUseTrendFilter || (close1 < sma);
   if(InpAllowLong && upTrend && rsi <= InpRSILow) buySignal=true;
   if(InpAllowShort && dnTrend && rsi >= InpRSIHigh) sellSignal=true;
   return true;
}

void TryEnter()
{
   if(g_trading_disabled) return;
   if(g_daily_blocked) { Print("[INFO] Daily loss limit active; trading blocked."); return; }
   if(CountAllOpenPositions() >= InpMaxOpenPositions)
   {
      Print("[INFO] Max open positions cap reached: ", InpMaxOpenPositions);
      return;
   }
   if(HasAnyPositionForSymbol(g_symbol))
      return; // only one position per symbol

   bool buySig=false, sellSig=false;
   if(!GetSignal(buySig, sellSig)) return;
   if(!buySig && !sellSig) return;

   MqlTick t; if(!SymbolInfoTick(g_symbol, t)) return;
   double atr; if(!GetATR(1, atr)) return;
   if(!CheckSpreadAtrOK(atr)) return; // skip on wide spreads or extreme ATR
   // read master adjustments
   double rf=1.0, slm=1.0, cdm=1.0; GetAdjustments(rf, slm, cdm);
   double risk_money = AccountInfoDouble(ACCOUNT_EQUITY) * (InpRiskPercent/100.0);
   risk_money *= rf; // scale risk dynamically (news/vol/equity)
   // cooldown by bars since last trade (scaled by cooldown_mult)
   int effCooldown = EffectiveCooldownBars();
   if(effCooldown>0 && g_last_trade_bar_time>0)
   {
      int last_shift = iBarShift(g_symbol, InpSignalTF, g_last_trade_bar_time, false);
      if(last_shift >= 0 && last_shift < effCooldown)
      {
         Print("[INFO] Cooldown active: waiting ", effCooldown - last_shift, " more bars before next trade.");
         return;
      }
   }

   if(buySig)
   {
      double sl = t.ask - atr*(InpATRMultiplierSL * slm);
      double tp = 0.0; if(InpTP_ATR_Mult>0) tp = t.ask + atr*(InpTP_ATR_Mult * slm);
      double lots; if(!CalcLotsForRisk(g_symbol, risk_money, t.ask, sl, lots, rf)) return;
      if(lots<=0) { Print("[SKIP] Computed lots below min or invalid for BUY."); return; }
      trade.SetExpertMagicNumber(InpMagic);
      if(!trade.Buy(lots, g_symbol, t.ask, sl, tp, "CascadeGreepEA BUY"))
         Print("[ERR] Buy failed: ", _LastError);
      else
         g_last_trade_bar_time = iTime(g_symbol, InpSignalTF, 0);
   }
   else if(sellSig)
   {
      double sl = t.bid + atr*(InpATRMultiplierSL * slm);
      double tp = 0.0; if(InpTP_ATR_Mult>0) tp = t.bid - atr*(InpTP_ATR_Mult * slm);
      double lots; if(!CalcLotsForRisk(g_symbol, risk_money, t.bid, sl, lots, rf)) return;
      if(lots<=0) { Print("[SKIP] Computed lots below min or invalid for SELL."); return; }
      trade.SetExpertMagicNumber(InpMagic);
      if(!trade.Sell(lots, g_symbol, t.bid, sl, tp, "CascadeGreepEA SELL"))
         Print("[ERR] Sell failed: ", _LastError);
      else
         g_last_trade_bar_time = iTime(g_symbol, InpSignalTF, 0);
   }
}

//==================== Master Adjustments (Global Variables) ====================
double ReadGVDouble(const string name, const double defv)
{
   if(!GlobalVariableCheck(name)) return defv;
   return GlobalVariableGet(name);
}

void GetAdjustments(double &risk_mult, double &sl_mult, double &cooldown_mult)
{
   risk_mult=1.0; sl_mult=1.0; cooldown_mult=1.0;
   if(!InpUseMasterAdjust) return;
   string base = InpGVNamespaceEA + "/";
   string sym = g_symbol;
   risk_mult     = ReadGVDouble(base+"risk_mult/"+sym, 1.0);
   sl_mult       = ReadGVDouble(base+"sl_mult/"+sym, 1.0);
   cooldown_mult = ReadGVDouble(base+"cooldown_mult/"+sym, 1.0);
}

int EffectiveCooldownBars()
{
   double rf, sm, cm; GetAdjustments(rf, sm, cm);
   int baseBars = InpMinBarsBetweenTrades;
   int eff = (int)MathCeil(baseBars * cm);
   if(eff<0) eff=0;
   return eff;
}

//==================== MT5 Events ====================
int OnInit()
{
   g_symbol       = _Symbol;
   g_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_day_key      = TodayKey();
   g_day_equity_start = g_start_equity;
   g_daily_blocked = false;

   hATR = iATR(g_symbol, InpSignalTF, InpATRPeriod);
   if(hATR==INVALID_HANDLE) { Print("[FATAL] ATR handle failed."); return INIT_FAILED; }
   hRSI = iRSI(g_symbol, InpSignalTF, InpRSIPeriod, PRICE_CLOSE);
   if(hRSI==INVALID_HANDLE) { Print("[FATAL] RSI handle failed."); return INIT_FAILED; }
   if(InpUseTrendFilter)
   {
      hSMA = iMA(g_symbol, InpSignalTF, InpSMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
      if(hSMA==INVALID_HANDLE) { Print("[FATAL] SMA handle failed."); return INIT_FAILED; }
   }
   trade.SetDeviationInPoints(InpMaxSlippagePoints);
   Print("[INIT] CascadeGreepEA on ", g_symbol, ", start equity=", g_start_equity);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(hATR!=INVALID_HANDLE) IndicatorRelease(hATR);
   if(hRSI!=INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hSMA!=INVALID_HANDLE) IndicatorRelease(hSMA);
}

void OnTick()
{
   DailyResetIfNeeded();
   if(CheckKillSwitch()) return;
   if(CheckDailyLossLimit()) return;
   ManageTrailing();
   if(NewBarOnSignalTF())
      TryEnter();
}

//+------------------------------------------------------------------+
