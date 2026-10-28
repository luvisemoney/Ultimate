#property strict
#include "..\Include\ModelPredictor.mqh"
#include "..\Include\PolicyHttpBridge.mqh"
void OnStart() { CModelPredictor predictor; CPolicyHttpBridge policy; Print(predictor.IsReady()); }
