// InstrumentProfile.mqh
// Provides lightweight symbol metadata access and simple cost/slippage estimations.
// Notes:
// - Commission is not directly exposed by MQL5 symbol properties. We support a user-configured
//   per-lot commission (account currency) to enable meaningful commission guards.
// - Slippage is estimated using a default value (points) for market orders. Pending orders assume 0.

#include <Trade/SymbolInfo.mqh>

class CInstrumentProfile
{
private:
   string   m_symbol;
   double   m_commission_per_lot_money;   // account currency per lot (round-turn or per-side as user defines)
   int      m_default_slippage_points;    // default assumed slippage (points) for market orders

public:
   CInstrumentProfile(const string symbol="", const double commission_per_lot_money=0.0, const int default_slippage_points=20)
   {
      m_symbol = (symbol=="" ? _Symbol : symbol);
      m_commission_per_lot_money = commission_per_lot_money;
      m_default_slippage_points  = default_slippage_points;
   }

   void UpdateSymbol(const string symbol)
   {
      if(symbol!="") m_symbol = symbol;
   }

   void SetCommissionPerLotMoney(const double money)
   {
      m_commission_per_lot_money = (money>0.0 ? money : 0.0);
   }

   void SetDefaultSlippagePoints(const int pts)
   {
      m_default_slippage_points = (pts>0 ? pts : 0);
   }

   // Normalize volume to broker step/min/max
   double NormalizeVolume(const double lots) const
   {
      double vmin=0.0, vmax=0.0, vstep=0.0;
      SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN, vmin);
      SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX, vmax);
      SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP, vstep);
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
      if(norm < vmin || norm > vmax) norm = vmin;
      return norm;
   }

   // Estimate commission in account currency for given lots (uses user-configured per-lot commission).
   double EstimateCommissionMoney(const double lots) const
   {
      if(m_commission_per_lot_money<=0.0 || lots<=0.0) return 0.0;
      return m_commission_per_lot_money * lots;
   }

   // Estimate slippage in points for the given order type.
   int EstimateSlippagePoints(const ENUM_ORDER_TYPE ot) const
   {
      // Assume market orders may incur default slippage; pending assumed 0 until triggered
      if(ot==ORDER_TYPE_BUY || ot==ORDER_TYPE_SELL)
         return m_default_slippage_points;
      return 0;
   }

   // Convenience: current spread in points
   double CurrentSpreadPoints() const
   {
      double b=0.0, a=0.0; SymbolInfoDouble(m_symbol, SYMBOL_BID, b); SymbolInfoDouble(m_symbol, SYMBOL_ASK, a);
      if(a<=0.0 || b<=0.0) return 0.0;
      double pt=0.0; SymbolInfoDouble(m_symbol, SYMBOL_POINT, pt);
      if(pt<=0.0) return 0.0;
      return (a-b)/pt;
   }
};
