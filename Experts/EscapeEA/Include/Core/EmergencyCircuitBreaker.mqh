//+------------------------------------------------------------------+
//| EmergencyCircuitBreaker.mqh - PRODUCTION HARDENED SAFETY SYSTEM |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA - JAILBREAK HARDENED"
#property link      "https://www.escapeea.com"
#property version   "3.00"

#include "..\Common\Enums.mqh"
#include "..\Common\Structs.mqh"
#include "..\Common\Constants.mqh"

//+------------------------------------------------------------------+
//| EMERGENCY CIRCUIT BREAKER - MAXIMUM SECURITY IMPLEMENTATION     |
//+------------------------------------------------------------------+
class CEmergencyCircuitBreaker
{
private:
   // CRITICAL SAFETY PARAMETERS
   double            m_maxDailyLoss;           // Maximum daily loss (hard limit)
   double            m_maxDrawdown;            // Maximum drawdown (hard limit)
   double            m_maxPositionSize;        // Maximum position size (hard limit)
   int               m_maxOpenPositions;       // Maximum open positions (hard limit)
   double            m_marginCallLevel;        // Margin call protection level
   
   // RUNTIME MONITORING
   double            m_startingBalance;        // Starting balance for the day
   double            m_peakEquity;             // Peak equity reached
   datetime          m_lastResetTime;          // Last daily reset time
   bool              m_emergencyTriggered;     // Emergency state flag
   string            m_emergencyReason;        // Reason for emergency stop
   
   // SAFETY COUNTERS
   int               m_consecutiveLosses;      // Consecutive losing trades
   int               m_tradesInLastHour;       // Trades executed in last hour
   datetime          m_lastTradeTime;          // Last trade execution time
   
   // VALIDATION METHODS
   bool              ValidateAccountSafety();
   bool              ValidatePositionLimits();
   bool              ValidateMarginSafety();
   bool              ValidateDrawdownLimits();
   bool              ValidateTradingFrequency();
   
   // EMERGENCY ACTIONS
   void              TriggerEmergencyStop(const string reason);
   void              CloseAllPositionsEmergency();
   void              DisableAllTrading();
   void              LogEmergencyEvent(const string reason);
   
public:
   // CONSTRUCTOR WITH MANDATORY SAFETY LIMITS
                     CEmergencyCircuitBreaker(double maxDailyLoss = 2.0,     // 2% max daily loss
                                            double maxDrawdown = 5.0,       // 5% max drawdown
                                            double maxPositionSize = 1.0,   // 1 lot max position
                                            int maxOpenPositions = 3,       // 3 max open positions
                                            double marginCallLevel = 200.0); // 200% margin level
                    ~CEmergencyCircuitBreaker();
   
   // SAFETY VALIDATION METHODS
   bool              IsTradingAllowed();
   bool              IsPositionSizeAllowed(double lotSize);
   bool              IsNewPositionAllowed();
   bool              IsAccountSafe();
   
   // MONITORING METHODS
   void              UpdateDailyReset();
   void              RecordTrade(double lotSize, double profit);
   void              UpdateEquityPeak();
   
   // EMERGENCY CONTROLS
   bool              IsEmergencyTriggered() const { return m_emergencyTriggered; }
   string            GetEmergencyReason() const { return m_emergencyReason; }
   void              ResetEmergencyState();
   
   // GETTERS FOR MONITORING
   double            GetCurrentDrawdown();
   double            GetDailyPnL();
   int               GetConsecutiveLosses() const { return m_consecutiveLosses; }
   int               GetTradesInLastHour() const { return m_tradesInLastHour; }
};

//+------------------------------------------------------------------+
//| CONSTRUCTOR - INITIALIZE SAFETY SYSTEMS                         |
//+------------------------------------------------------------------+
CEmergencyCircuitBreaker::CEmergencyCircuitBreaker(double maxDailyLoss = 2.0,
                                                  double maxDrawdown = 5.0,
                                                  double maxPositionSize = 1.0,
                                                  int maxOpenPositions = 3,
                                                  double marginCallLevel = 200.0) :
   m_maxDailyLoss(MathMax(0.5, MathMin(maxDailyLoss, 10.0))),        // Clamp between 0.5% and 10%
   m_maxDrawdown(MathMax(1.0, MathMin(maxDrawdown, 20.0))),          // Clamp between 1% and 20%
   m_maxPositionSize(MathMax(0.01, MathMin(maxPositionSize, 10.0))), // Clamp between 0.01 and 10 lots
   m_maxOpenPositions(MathMax(1, MathMin(maxOpenPositions, 10))),    // Clamp between 1 and 10 positions
   m_marginCallLevel(MathMax(100.0, MathMin(marginCallLevel, 1000.0))), // Clamp between 100% and 1000%
   m_startingBalance(AccountInfoDouble(ACCOUNT_BALANCE)),
   m_peakEquity(AccountInfoDouble(ACCOUNT_EQUITY)),
   m_lastResetTime(TimeCurrent()),
   m_emergencyTriggered(false),
   m_emergencyReason(""),
   m_consecutiveLosses(0),
   m_tradesInLastHour(0),
   m_lastTradeTime(0)
{
   Print("SAFETY: Emergency Circuit Breaker initialized with limits:");
   Print("  Max Daily Loss: ", m_maxDailyLoss, "%");
   Print("  Max Drawdown: ", m_maxDrawdown, "%");
   Print("  Max Position Size: ", m_maxPositionSize, " lots");
   Print("  Max Open Positions: ", m_maxOpenPositions);
   Print("  Margin Call Level: ", m_marginCallLevel, "%");
   
   // Perform initial safety check
   if(!ValidateAccountSafety())
   {
      TriggerEmergencyStop("Initial account safety validation failed");
   }
}

//+------------------------------------------------------------------+
//| DESTRUCTOR - CLEANUP SAFETY SYSTEMS                             |
//+------------------------------------------------------------------+
CEmergencyCircuitBreaker::~CEmergencyCircuitBreaker()
{
   if(m_emergencyTriggered)
   {
      Print("SAFETY: Circuit breaker destroyed while emergency was active: ", m_emergencyReason);
   }
   else
   {
      Print("SAFETY: Circuit breaker destroyed - no emergency state");
   }
}

//+------------------------------------------------------------------+
//| CHECK IF TRADING IS ALLOWED - MASTER SAFETY GATE               |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::IsTradingAllowed()
{
   // If emergency already triggered, no trading allowed
   if(m_emergencyTriggered)
   {
      return false;
   }
   
   // Perform daily reset if needed
   UpdateDailyReset();
   
   // Run all safety validations
   if(!ValidateAccountSafety())
   {
      TriggerEmergencyStop("Account safety validation failed");
      return false;
   }
   
   if(!ValidatePositionLimits())
   {
      TriggerEmergencyStop("Position limits exceeded");
      return false;
   }
   
   if(!ValidateMarginSafety())
   {
      TriggerEmergencyStop("Margin safety limits exceeded");
      return false;
   }
   
   if(!ValidateDrawdownLimits())
   {
      TriggerEmergencyStop("Drawdown limits exceeded");
      return false;
   }
   
   if(!ValidateTradingFrequency())
   {
      TriggerEmergencyStop("Trading frequency limits exceeded");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| VALIDATE POSITION SIZE AGAINST LIMITS                           |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::IsPositionSizeAllowed(double lotSize)
{
   if(m_emergencyTriggered)
      return false;
      
   // Check against maximum position size
   if(lotSize > m_maxPositionSize)
   {
      Print("SAFETY: Position size ", lotSize, " exceeds maximum ", m_maxPositionSize);
      return false;
   }
   
   // Check against minimum position size
   if(lotSize < 0.01)
   {
      Print("SAFETY: Position size ", lotSize, " below minimum 0.01");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| CHECK IF NEW POSITION CAN BE OPENED                             |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::IsNewPositionAllowed()
{
   if(m_emergencyTriggered)
      return false;
      
   // Check current number of open positions
   int currentPositions = PositionsTotal();
   if(currentPositions >= m_maxOpenPositions)
   {
      Print("SAFETY: Cannot open new position. Current: ", currentPositions, " Max: ", m_maxOpenPositions);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| VALIDATE ACCOUNT SAFETY                                         |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::ValidateAccountSafety()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Check for negative balance
   if(balance <= 0)
   {
      Print("SAFETY: Account balance is zero or negative: ", balance);
      return false;
   }
   
   // Check for negative equity
   if(equity <= 0)
   {
      Print("SAFETY: Account equity is zero or negative: ", equity);
      return false;
   }
   
   // Check if equity is significantly below balance (potential margin call)
   if(equity < balance * 0.5) // 50% equity threshold
   {
      Print("SAFETY: Equity (", equity, ") is less than 50% of balance (", balance, ")");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| VALIDATE POSITION LIMITS                                        |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::ValidatePositionLimits()
{
   int currentPositions = PositionsTotal();
   
   // Check maximum open positions
   if(currentPositions > m_maxOpenPositions)
   {
      Print("SAFETY: Too many open positions: ", currentPositions, " > ", m_maxOpenPositions);
      return false;
   }
   
   // Check individual position sizes
   for(int i = 0; i < currentPositions; i++)
   {
      if(PositionGetTicket(i) > 0)
      {
         double volume = PositionGetDouble(POSITION_VOLUME);
         if(volume > m_maxPositionSize)
         {
            Print("SAFETY: Position size ", volume, " exceeds maximum ", m_maxPositionSize);
            return false;
         }
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| VALIDATE MARGIN SAFETY                                          |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::ValidateMarginSafety()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   
   // If no margin used, we're safe
   if(margin <= 0)
      return true;
      
   double marginLevel = (equity / margin) * 100.0;
   
   // Check margin level against our safety threshold
   if(marginLevel < m_marginCallLevel)
   {
      Print("SAFETY: Margin level ", marginLevel, "% below safety threshold ", m_marginCallLevel, "%");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| VALIDATE DRAWDOWN LIMITS                                        |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::ValidateDrawdownLimits()
{
   double currentDrawdown = GetCurrentDrawdown();
   
   // Check against maximum drawdown
   if(currentDrawdown > m_maxDrawdown)
   {
      Print("SAFETY: Current drawdown ", currentDrawdown, "% exceeds maximum ", m_maxDrawdown, "%");
      return false;
   }
   
   // Check daily P&L
   double dailyPnL = GetDailyPnL();
   double dailyLossPercent = (dailyPnL < 0) ? (MathAbs(dailyPnL) / m_startingBalance) * 100.0 : 0.0;
   
   if(dailyLossPercent > m_maxDailyLoss)
   {
      Print("SAFETY: Daily loss ", dailyLossPercent, "% exceeds maximum ", m_maxDailyLoss, "%");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| VALIDATE TRADING FREQUENCY                                      |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::ValidateTradingFrequency()
{
   datetime currentTime = TimeCurrent();
   
   // Update trades in last hour counter
   if(currentTime - m_lastTradeTime > 3600) // More than 1 hour since last trade
   {
      m_tradesInLastHour = 0;
   }
   
   // Check if too many trades in the last hour
   if(m_tradesInLastHour >= 20) // Maximum 20 trades per hour
   {
      Print("SAFETY: Too many trades in last hour: ", m_tradesInLastHour);
      return false;
   }
   
   // Check minimum time between trades (prevent rapid-fire trading)
   if(currentTime - m_lastTradeTime < 30) // Minimum 30 seconds between trades
   {
      Print("SAFETY: Trade too soon after last trade (", currentTime - m_lastTradeTime, " seconds)");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| TRIGGER EMERGENCY STOP                                          |
//+------------------------------------------------------------------+
void CEmergencyCircuitBreaker::TriggerEmergencyStop(const string reason)
{
   if(m_emergencyTriggered)
      return; // Already triggered
      
   m_emergencyTriggered = true;
   m_emergencyReason = reason;
   
   Print("🚨 EMERGENCY CIRCUIT BREAKER TRIGGERED: ", reason);
   
   // Log emergency event
   LogEmergencyEvent(reason);
   
   // Close all positions immediately
   CloseAllPositionsEmergency();
   
   // Disable all trading
   DisableAllTrading();
   
   // Send alert
   Alert("EMERGENCY STOP: ", reason);
   
   // Update chart comment
   Comment("🚨 EMERGENCY STOP: ", reason);
}

//+------------------------------------------------------------------+
//| CLOSE ALL POSITIONS IN EMERGENCY                                |
//+------------------------------------------------------------------+
void CEmergencyCircuitBreaker::CloseAllPositionsEmergency()
{
   Print("EMERGENCY: Closing all positions immediately");
   
   int totalPositions = PositionsTotal();
   for(int i = totalPositions - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         CTrade trade;
         if(!trade.PositionClose(ticket))
         {
            Print("EMERGENCY: Failed to close position ", ticket, " Error: ", GetLastError());
         }
         else
         {
            Print("EMERGENCY: Closed position ", ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| DISABLE ALL TRADING SYSTEMS                                     |
//+------------------------------------------------------------------+
void CEmergencyCircuitBreaker::DisableAllTrading()
{
   Print("EMERGENCY: Disabling all trading systems");
   
   // Set global variable to disable trading
   GlobalVariableSet("EscapeEA_TradingDisabled", 1);
   
   // Remove expert advisor
   ExpertRemove();
}

//+------------------------------------------------------------------+
//| LOG EMERGENCY EVENT                                             |
//+------------------------------------------------------------------+
void CEmergencyCircuitBreaker::LogEmergencyEvent(const string reason)
{
   string filename = "Emergency_Log_" + TimeToString(TimeCurrent(), TIME_DATE) + ".log";
   int handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_COMMON, ",", CP_UTF8);
   
   if(handle != INVALID_HANDLE)
   {
      FileWrite(handle, "EMERGENCY CIRCUIT BREAKER TRIGGERED");
      FileWrite(handle, "Timestamp: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
      FileWrite(handle, "Reason: ", reason);
      FileWrite(handle, "Account Balance: ", AccountInfoDouble(ACCOUNT_BALANCE));
      FileWrite(handle, "Account Equity: ", AccountInfoDouble(ACCOUNT_EQUITY));
      FileWrite(handle, "Current Drawdown: ", GetCurrentDrawdown(), "%");
      FileWrite(handle, "Daily P&L: ", GetDailyPnL());
      FileWrite(handle, "Open Positions: ", PositionsTotal());
      FileWrite(handle, "Consecutive Losses: ", m_consecutiveLosses);
      FileWrite(handle, "Trades in Last Hour: ", m_tradesInLastHour);
      FileClose(handle);
   }
}

//+------------------------------------------------------------------+
//| UPDATE DAILY RESET                                              |
//+------------------------------------------------------------------+
void CEmergencyCircuitBreaker::UpdateDailyReset()
{
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   // Check if it's a new day
   MqlDateTime lastResetDt;
   TimeToStruct(m_lastResetTime, lastResetDt);
   
   if(dt.day != lastResetDt.day || dt.mon != lastResetDt.mon || dt.year != lastResetDt.year)
   {
      // Reset daily counters
      m_startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_consecutiveLosses = 0;
      m_tradesInLastHour = 0;
      m_lastResetTime = currentTime;
      
      Print("SAFETY: Daily reset performed. Starting balance: ", m_startingBalance);
   }
}

//+------------------------------------------------------------------+
//| RECORD TRADE FOR MONITORING                                     |
//+------------------------------------------------------------------+
void CEmergencyCircuitBreaker::RecordTrade(double lotSize, double profit)
{
   datetime currentTime = TimeCurrent();
   
   // Update trade frequency counter
   if(currentTime - m_lastTradeTime <= 3600) // Within last hour
   {
      m_tradesInLastHour++;
   }
   else
   {
      m_tradesInLastHour = 1; // Reset counter
   }
   
   m_lastTradeTime = currentTime;
   
   // Update consecutive losses counter
   if(profit < 0)
   {
      m_consecutiveLosses++;
   }
   else
   {
      m_consecutiveLosses = 0; // Reset on winning trade
   }
   
   // Check for excessive consecutive losses
   if(m_consecutiveLosses >= 5)
   {
      TriggerEmergencyStop("Excessive consecutive losses: " + IntegerToString(m_consecutiveLosses));
   }
   
   Print("SAFETY: Trade recorded - Lot Size: ", lotSize, " Profit: ", profit, " Consecutive Losses: ", m_consecutiveLosses);
}

//+------------------------------------------------------------------+
//| UPDATE EQUITY PEAK                                              |
//+------------------------------------------------------------------+
void CEmergencyCircuitBreaker::UpdateEquityPeak()
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentEquity > m_peakEquity)
   {
      m_peakEquity = currentEquity;
   }
}

//+------------------------------------------------------------------+
//| GET CURRENT DRAWDOWN PERCENTAGE                                 |
//+------------------------------------------------------------------+
double CEmergencyCircuitBreaker::GetCurrentDrawdown()
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(m_peakEquity <= 0)
      return 0.0;
      
   double drawdown = ((m_peakEquity - currentEquity) / m_peakEquity) * 100.0;
   return MathMax(0.0, drawdown);
}

//+------------------------------------------------------------------+
//| GET DAILY P&L                                                   |
//+------------------------------------------------------------------+
double CEmergencyCircuitBreaker::GetDailyPnL()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   return currentBalance - m_startingBalance;
}

//+------------------------------------------------------------------+
//| RESET EMERGENCY STATE (MANUAL OVERRIDE)                         |
//+------------------------------------------------------------------+
void CEmergencyCircuitBreaker::ResetEmergencyState()
{
   Print("SAFETY: Emergency state reset manually");
   m_emergencyTriggered = false;
   m_emergencyReason = "";
   
   // Clear global disable flag
   GlobalVariableDel("EscapeEA_TradingDisabled");
}

//+------------------------------------------------------------------+
//| CHECK IF ACCOUNT IS SAFE                                        |
//+------------------------------------------------------------------+
bool CEmergencyCircuitBreaker::IsAccountSafe()
{
   return !m_emergencyTriggered && 
          ValidateAccountSafety() && 
          ValidateMarginSafety() && 
          ValidateDrawdownLimits();
}