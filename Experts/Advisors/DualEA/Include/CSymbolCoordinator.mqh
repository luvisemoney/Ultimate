//+------------------------------------------------------------------+
//| CSymbolCoordinator.mqh - Multi-Symbol Trade Coordinator          |
//| Prevents over-correlated positions across symbols                 |
//+------------------------------------------------------------------+
#ifndef CSYMBOLCOORDINATOR_MQH
#define CSYMBOLCOORDINATOR_MQH

//+------------------------------------------------------------------+
//| Symbol Coordinator Class                                          |
//+------------------------------------------------------------------+
class CSymbolCoordinator
{
private:
   struct SSymbolRisk
   {
      string symbol;
      double risk_pct;
      datetime last_trade;
   };
   
   SSymbolRisk      m_symbol_risks[];
   int              m_symbol_count;
   double           m_max_total_risk;
   bool             m_enabled;
   
public:
   CSymbolCoordinator()
   {
      m_symbol_count = 0;
      m_max_total_risk = 10.0;
      m_enabled = true;
      ArrayResize(m_symbol_risks, 0);
   }
   
   ~CSymbolCoordinator()
   {
      ArrayResize(m_symbol_risks, 0);
   }
   
   bool Initialize(double max_total_risk_pct = 10.0)
   {
      m_max_total_risk = max_total_risk_pct;
      Print("[SymbolCoordinator] Initialized with max risk: " + DoubleToString(max_total_risk_pct, 1) + "%");
      return true;
   }
   
   void Shutdown()
   {
      ArrayResize(m_symbol_risks, 0);
      m_symbol_count = 0;
   }
   
   bool ShouldTrade(ENUM_ORDER_TYPE direction, double risk_pct, string &reason)
   {
      if(!m_enabled)
         return true;
      
      // Check total risk across all symbols
      double total_risk = 0.0;
      for(int i = 0; i < m_symbol_count; i++)
         total_risk += m_symbol_risks[i].risk_pct;
      
      if(total_risk + risk_pct > m_max_total_risk)
      {
         reason = "Total risk limit exceeded: " + DoubleToString(total_risk + risk_pct, 2) + "% > " + DoubleToString(m_max_total_risk, 1) + "%";
         return false;
      }
      
      return true;
   }
   
   void RecordTrade(ENUM_ORDER_TYPE direction, double size, double risk_pct)
   {
      if(!m_enabled) return;
      
      string symbol = Symbol();
      
      // Find existing entry
      for(int i = 0; i < m_symbol_count; i++)
      {
         if(m_symbol_risks[i].symbol == symbol)
         {
            m_symbol_risks[i].risk_pct += risk_pct;
            m_symbol_risks[i].last_trade = TimeCurrent();
            return;
         }
      }
      
      // Add new entry
      int idx = m_symbol_count;
      ArrayResize(m_symbol_risks, idx + 1);
      m_symbol_risks[idx].symbol = symbol;
      m_symbol_risks[idx].risk_pct = risk_pct;
      m_symbol_risks[idx].last_trade = TimeCurrent();
      m_symbol_count++;
   }
   
   void RecordClose(double pnl, double risk_released)
   {
      if(!m_enabled) return;
      
      string symbol = Symbol();
      
      for(int i = 0; i < m_symbol_count; i++)
      {
         if(m_symbol_risks[i].symbol == symbol)
         {
            m_symbol_risks[i].risk_pct = MathMax(0.0, m_symbol_risks[i].risk_pct - risk_released);
            return;
         }
      }
   }
   
   double GetTotalRisk()
   {
      double total = 0.0;
      for(int i = 0; i < m_symbol_count; i++)
         total += m_symbol_risks[i].risk_pct;
      return total;
   }
   
   void SetEnabled(bool enabled) { m_enabled = enabled; }
   bool IsEnabled() const { return m_enabled; }
};

// Global instance for P0-P5 integration
CSymbolCoordinator* g_symbol_coordinator = NULL;

//+------------------------------------------------------------------+
//| Initialize Symbol Coordinator                                     |
//+------------------------------------------------------------------+
bool InitializeSymbolCoordinator(double max_total_risk_pct = 10.0)
{
   if(g_symbol_coordinator == NULL)
   {
      g_symbol_coordinator = new CSymbolCoordinator();
   }
   return g_symbol_coordinator.Initialize(max_total_risk_pct);
}

//+------------------------------------------------------------------+
//| Shutdown Symbol Coordinator                                       |
//+------------------------------------------------------------------+
void ShutdownSymbolCoordinator()
{
   if(g_symbol_coordinator != NULL)
   {
      g_symbol_coordinator.Shutdown();
      delete g_symbol_coordinator;
      g_symbol_coordinator = NULL;
   }
}

#endif // CSYMBOLCOORDINATOR_MQH
