//+------------------------------------------------------------------+
//|                                                      PaperEA.mq5 |
//|                                  Copyright 2025, Windsurf, Inc. |
//|                                              https://windsurf.ai |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Windsurf, Inc."
#property link      "https://windsurf.ai"
#property version   "1.00"

// --- Core Interfaces & Data Structures
#include "..\Include\IStrategy.mqh"

// --- Core Services
#include "..\Include\KnowledgeBase.mqh"
#include "..\Include\TradeManager.mqh"

// --- Standard Libraries
#include <Arrays/ArrayObj.mqh> // Include for CArrayObj

// --- Strategy Implementations
#include "..\Include\Strategies\BollAveragesStrategy.mqh"
#include "..\Include\Strategies\MeanReversionBBStrategy.mqh"

// --- Input Parameters
input double LotSize = 0.01;
input int    MagicNumber = 12345;
input double StopLossPips = 150;
input double TakeProfitPips = 300;
// Trailing stop defaults (used if a strategy does not set trailing fields)
input bool   TrailEnabled = true;
// 0=fixed points, 2=ATR
input int    TrailType = 0;
input int    TrailActivationPoints = 30;
input int    TrailDistancePoints   = 20;
input int    TrailStepPoints       = 5;
// ATR defaults (used when TrailType==2 or a strategy selects ATR)
input int    TrailATRPeriod        = 14;
input double TrailATRMultiplier    = 2.0;
// Logging controls
input bool   DebugTrailing = false;
input bool   KBDebugInit   = true;

// --- Globals
CKnowledgeBase*         g_kb = NULL;
CTradeManager*          g_trade_manager = NULL;
CArrayObj*              g_strategies; // Array to hold all strategy objects

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // --- Create objects
   g_kb = new CKnowledgeBase();
   g_trade_manager = new CTradeManager(_Symbol, LotSize, MagicNumber);
   g_strategies = new CArrayObj();

   // --- Add strategies to the array
   IStrategy* boll_averages = new CBollAveragesStrategy(_Symbol, _Period);
   g_strategies.Add(boll_averages);

   IStrategy* mean_reversion = new CMeanReversionBBStrategy(_Symbol, _Period);
   g_strategies.Add(mean_reversion);

   // --- Validate objects
   if(CheckPointer(g_kb) == POINTER_INVALID || CheckPointer(g_trade_manager) == POINTER_INVALID || CheckPointer(g_strategies) == POINTER_INVALID)
     {
      Print("Error creating one or more required objects");
      return(INIT_FAILED);
     }

   // Optional: write an init event to confirm KB writing
   if(KBDebugInit)
     {
      (*g_kb).LogTrade("INIT", 0, 0, 0);
     }

   Print("PaperEA Initialized Successfully");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // --- Destroy objects
   if(CheckPointer(g_kb) != POINTER_INVALID) delete(g_kb);
   if(CheckPointer(g_trade_manager) != POINTER_INVALID) delete(g_trade_manager);
   if(CheckPointer(g_strategies) != POINTER_INVALID)
     {
      for(int i = 0; i < g_strategies.Total(); i++)
        {
         IStrategy* strategy = (IStrategy*)g_strategies.At(i);
         if(CheckPointer(strategy) != POINTER_INVALID) delete(strategy);
        }
      delete(g_strategies);
     }
   Print("PaperEA Deinitialized");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Always update trailing stops for open positions managed by our magic number
   if(CheckPointer(g_trade_manager)!=POINTER_INVALID)
     {
      (*g_trade_manager).UpdateTrailingStops();
     }
//--- Iterate through each strategy
   for(int i = 0; i < g_strategies.Total(); i++)
     {
      // Safely cast to the interface pointer
      IStrategy* strategy = (IStrategy*)g_strategies.At(i);
      if(CheckPointer(strategy) == POINTER_INVALID)
        {
         Print("Error: Could not cast strategy at index ", i);
         continue;
        }

      // Refresh strategy data (e.g., update indicator values)
      (*strategy).Refresh();

      // Check for a trade signal
      TradeOrder order = (*strategy).CheckSignal();

      // If a signal is returned, process it
      if(order.action != ACTION_NONE)
        {
         // To keep it simple, only allow one position at a time
         if(PositionsTotal() > 0) 
           {
            return;
           }

         // If strategy did not provide trailing settings, apply defaults from inputs
         if(TrailEnabled && !order.trailing_enabled)
           {
            order.trailing_enabled          = true;
            order.trailing_type             = (uchar)TrailType;
            order.trail_activation_points   = TrailActivationPoints;
            order.trail_distance_points     = TrailDistancePoints;
            order.trail_step_points         = TrailStepPoints;
            // ATR params always set so strategies can opt-in by setting trailing_type=TRAIL_ATR
            order.atr_period                = TrailATRPeriod;
            order.atr_multiplier            = TrailATRMultiplier;
           }

         // Execute the trade
         bool result = (*g_trade_manager).ExecuteOrder(order);
         
         // Log the outcome
         if(result)
            {
             // Configure trailing according to the strategy's order policy
             (*g_trade_manager).ConfigureTrailing(order);

             // Event log
             (*g_kb).LogTrade(order.strategy_name, (int)(*g_trade_manager).ResultRetcode(), (*g_trade_manager).ResultDeal(), (*g_trade_manager).ResultOrder());

             // Full record log
             TradeRecord rec;
             rec.timestamp    = TimeCurrent();
             rec.symbol       = _Symbol;
             rec.type         = order.order_type;
             rec.entry_price  = (*g_trade_manager).ResultPrice();
             rec.stop_loss    = order.stop_loss;
             rec.take_profit  = order.take_profit;
             rec.close_price  = 0.0;
             rec.profit       = 0.0;
             rec.strategy_id  = order.strategy_name;
             (*g_kb).WriteRecord(rec);
             PrintFormat("Trade executed by %s. Deal: %d, Order: %d", order.strategy_name, (*g_trade_manager).ResultDeal(), (*g_trade_manager).ResultOrder());
             return; // Exit after processing one trade
            }
         else
           {
            PrintFormat("Trade failed for %s. Error: %d", order.strategy_name, GetLastError());
           }
        }
     }
  }
//+------------------------------------------------------------------+
