//+------------------------------------------------------------------+
//|                                                       LiveEA.mq5 |
//|                          DualEA Live Trading Expert - Clean     |
//+------------------------------------------------------------------+
#property copyright "DualEA Team"
#property version   "2.00"
#property strict

// Core includes
#include "..\\Include\\IStrategy.mqh"
#include "..\\Include\\TradeManager.mqh"
#include "../Include/Telemetry.mqh"
#include "..\\Include\\Strategies\\Registry.mqh"
#include "LiveEA_StrategyBridge.mqh"

// Enums
enum LogLevel { LOG_ERROR=0, LOG_WARN=1, LOG_INFO=2, LOG_DEBUG=3 };

// Input parameters
input long   MagicNumber        = 123456;
input int    Verbosity          = 1;
input bool   NoConstraintsMode  = false;
input double BaseLotSize        = 0.01;
input bool   TelemetryEnabled   = true;
input double SpreadMaxPoints    = 20.0;
input int    MaxTradesPerDay    = 10;
input int    MaxOpenPositions   = 5;

// Global variables
CTelemetry* g_telemetry = NULL;
CLiveEAStrategyBridge* g_strategy_bridge = NULL;
int g_trades_today = 0;
datetime g_last_trade_day = 0;
bool g_eval_busy = false;

// Utility functions
bool ShouldLog(const int level) { return (Verbosity >= level); }

double CurrentSpreadPoints()
{
    double bid, ask;
    SymbolInfoDouble(_Symbol, SYMBOL_BID, bid);
    SymbolInfoDouble(_Symbol, SYMBOL_ASK, ask);
    return (ask > 0 && bid > 0) ? (ask - bid) / _Point : 0.0;
}

// Gating functions
bool SpreadAllowed() { return (SpreadMaxPoints <= 0) || (CurrentSpreadPoints() <= SpreadMaxPoints); }
bool DailyTradeAllowed() { return (MaxTradesPerDay <= 0) || (g_trades_today < MaxTradesPerDay); }
bool PositionLimitAllowed() { return (MaxOpenPositions <= 0) || (PositionsTotal() < MaxOpenPositions); }

bool PassesAllGates()
{
    if(NoConstraintsMode) return true;
    return SpreadAllowed() && DailyTradeAllowed() && PositionLimitAllowed();
}

// Core trading function
void ProcessTrade(const TradeOrder &order)
{
    if(g_eval_busy) return;
    g_eval_busy = true;
    
    if(!PassesAllGates())
    {
        g_eval_busy = false;
        return;
    }
    
    CTradeManager tm(_Symbol, BaseLotSize, (int)MagicNumber);
    bool success = tm.ExecuteOrder(order);
    
    if(success)
    {
        g_trades_today++;
        g_last_trade_day = TimeCurrent();
        if(ShouldLog(LOG_INFO))
            PrintFormat("[EXEC] %s executed successfully", order.strategy_name);
    }
    
    g_eval_busy = false;
}

// EA event handlers
int OnInit()
{
    if(TelemetryEnabled)
        g_telemetry = new CTelemetry(_Symbol, "live", 1000, (int)_Period);
    
    g_strategy_bridge = new CLiveEAStrategyBridge(_Symbol, _Period);
    if(g_strategy_bridge)
        g_strategy_bridge.Initialize();
    
    // Reset daily counters
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int today = dt.year * 10000 + dt.mon * 100 + dt.day;
    MqlDateTime last_dt;
    TimeToStruct(g_last_trade_day, last_dt);
    int last_day = last_dt.year * 10000 + last_dt.mon * 100 + last_dt.day;
    
    if(today != last_day) g_trades_today = 0;
    
    if(ShouldLog(LOG_INFO))
        PrintFormat("LiveEA initialized: Symbol=%s, Magic=%d", _Symbol, MagicNumber);
    
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    if(g_telemetry) { delete g_telemetry; g_telemetry = NULL; }
    if(g_strategy_bridge) { delete g_strategy_bridge; g_strategy_bridge = NULL; }
}

void OnTick()
{
    if(!g_strategy_bridge) return;
    
    // Check for trade signals
    TradeOrder order = g_strategy_bridge.CheckAllSignals();
    if(order.action != ACTION_NONE)
        ProcessTrade(order);
}

void OnTimer()
{
    if(g_telemetry) (*g_telemetry).Flush();
}
