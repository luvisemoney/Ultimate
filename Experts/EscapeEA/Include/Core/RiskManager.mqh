//+------------------------------------------------------------------+
//| RiskManager.mqh - Risk management for EscapeEA                   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"
#include <Trade\AccountInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>

//+------------------------------------------------------------------+
//| Risk Manager Class                                               |
//+------------------------------------------------------------------+
class CRiskManager
  {
private:
   double            m_riskPercent;      // Risk per trade (% of balance)
   double            m_maxDrawdown;      // Maximum allowed drawdown (%)
   double            m_maxDailyLoss;     // Maximum daily loss (%)
   double            m_maxPositionSize;  // Maximum position size in lots
   int               m_maxOpenTrades;    // Maximum number of open trades
   string            m_symbol;           // Symbol for position sizing
   
   // Private methods
   double            CalculateLotSize(double stopLossPips);
   bool              CheckDailyLossLimit();
   bool              CheckDrawdownLimit();
   
public:
   // Constructor/destructor
                     CRiskManager(string symbol, double riskPercent, double maxDrawdown, 
                                double maxDailyLoss, double maxPositionSize, int maxOpenTrades);
   
   // Risk calculation methods
   double            CalculatePositionSize(double stopLossPips);
   bool              IsTradeAllowed();
   
   // Getters
   double            RiskPercent() const { return m_riskPercent; }
   double            MaxDrawdown() const { return m_maxDrawdown; }
   double            MaxDailyLoss() const { return m_maxDailyLoss; }
   double            MaxPositionSize() const { return m_maxPositionSize; }
   int               MaxOpenTrades() const { return m_maxOpenTrades; }
   
   // Setters
   void              SetRiskPercent(double percent) { m_riskPercent = MathMin(percent, MAX_RISK_PERCENT); }
   void              SetMaxDrawdown(double drawdown) { m_maxDrawdown = drawdown; }
   void              SetMaxDailyLoss(double loss) { m_maxDailyLoss = loss; }
   void              SetMaxPositionSize(double lots) { m_maxPositionSize = lots; }
   void              SetMaxOpenTrades(int maxTrades) { m_maxOpenTrades = maxTrades; }
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager(string symbol, double riskPercent, double maxDrawdown, 
                          double maxDailyLoss, double maxPositionSize, int maxOpenTrades) :
   m_symbol(symbol),
   m_riskPercent(MathMin(riskPercent, MAX_RISK_PERCENT)),
   m_maxDrawdown(maxDrawdown),
   m_maxDailyLoss(maxDailyLoss),
   m_maxPositionSize(maxPositionSize),
   m_maxOpenTrades(maxOpenTrades)
  {
  }

//+------------------------------------------------------------------+
//| Calculate position size based on risk parameters                 |
//+------------------------------------------------------------------+
double CRiskManager::CalculatePositionSize(double stopLossPips)
  {
   // Check for valid stop loss
   if(stopLossPips <= 0)
     {
      Print("Invalid stop loss value for position sizing");
      return 0.0;
     }
   
   // Get account information
   CAccountInfo account;
   double balance = account.Balance();
   double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   
   // Calculate position size in lots
   double riskAmount = balance * (m_riskPercent / 100.0);
   double pipValue = (tickValue / tickSize) * point;
   double lotSize = NormalizeDouble(riskAmount / (stopLossPips * pipValue), 2);
   
   // Apply lot step
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // Apply min/max lot size constraints
   lotSize = MathMax(minLot, MathMin(lotSize, MathMin(m_maxPositionSize, maxLot)));
   
   return lotSize;
  }

//+------------------------------------------------------------------+
//| Check if trading is allowed based on risk parameters             |
//+------------------------------------------------------------------+
bool CRiskManager::IsTradeAllowed()
  {
   // Check if market is open
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
     {
      Print("Trading is not allowed in terminal settings");
      return false;
     }
   
   // Check if trading is allowed for the symbol
   if(!SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL)
     {
      Print("Trading is not allowed for ", m_symbol);
      return false;
     }
   
   // Check maximum open trades
   CPositionInfo position;
   int openPositions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(position.SelectByIndex(i))
         if(position.Symbol() == m_symbol)
            openPositions++;
   
   if(openPositions >= m_maxOpenTrades)
     {
      Print("Maximum number of open positions (", m_maxOpenTrades, ") reached");
      return false;
     }
   
   // Check daily loss limit
   if(!CheckDailyLossLimit())
     {
      Print("Daily loss limit reached");
      return false;
     }
   
   // Check drawdown limit
   if(!CheckDrawdownLimit())
     {
      Print("Maximum drawdown limit reached");
      return false;
     }
   
   return true;
  }

//+------------------------------------------------------------------+
//| Check if daily loss limit is not exceeded                        |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDailyLossLimit()
  {
   if(m_maxDailyLoss <= 0)
      return true; // No daily loss limit set
   
   CAccountInfo account;
   double dailyProfit = account.InfoDouble(ACCOUNT_PROFIT);
   
   // Get today's date at 00:00
   MqlDateTime today;
   TimeToStruct(TimeCurrent(), today);
   today.hour = 0;
   today.min = 0;
   today.sec = 0;
   datetime todayStart = StructToTime(today);
   
   // Get today's closed positions from history
   CDealInfo dealInfo;
   double dailyClosedProfit = 0;
   
   // Check if we have positions closed today
   if(HistorySelect(todayStart, TimeCurrent()))
     {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
           {
            dealInfo.Ticket(ticket);
            if(dealInfo.Symbol() == m_symbol && 
               dealInfo.DealType() == DEAL_TYPE_BALANCE)
              {
               dailyClosedProfit += dealInfo.Profit();
              }
           }
        }
     }
   
   // Calculate total daily profit/loss
   double totalDailyProfit = dailyProfit + dailyClosedProfit;
   double balance = account.Balance();
   double dailyLossPercent = MathAbs(totalDailyProfit) / balance * 100.0;
   
   return (dailyLossPercent <= m_maxDailyLoss);
  }

//+------------------------------------------------------------------+
//| Check if drawdown limit is not exceeded                          |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDrawdownLimit()
  {
   if(m_maxDrawdown <= 0)
      return true; // No drawdown limit set
   
   CAccountInfo account;
   double balance = account.Balance();
   double equity = account.Equity();
   
   if(balance <= 0)
      return false;
   
   double drawdownPercent = (1.0 - (equity / balance)) * 100.0;
   
   return (drawdownPercent <= m_maxDrawdown);
  }
