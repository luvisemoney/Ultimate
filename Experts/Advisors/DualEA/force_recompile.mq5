//+------------------------------------------------------------------+
//| force_recompile.mq5 |
//| Force IDE to recompile and refresh cache |
//+------------------------------------------------------------------+
#property copyright "Test"
#property link ""
#property version "1.00"

#include "Include\GateManager.mqh"

//+------------------------------------------------------------------+
//| Test the fixed callback signature |
//+------------------------------------------------------------------+
void TestCallbackSignature()
{
   // This should compile fine now with the fixed pointer syntax
   TradingSignal test_signal;
   test_signal.Init();
   test_signal.price = 1.2345;
   
   // Test the callback signature
   SetGateSanitizeTelemetryCallback(NULL);
   
   Print("Callback signature test passed!");
}

//+------------------------------------------------------------------+
//| Script program start function |
//+------------------------------------------------------------------+
void OnStart()
{
   TestCallbackSignature();
   Print("Force recompile test completed successfully!");
}
//+------------------------------------------------------------------+
