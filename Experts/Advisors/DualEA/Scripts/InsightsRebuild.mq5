//+------------------------------------------------------------------+
//|                                                InsightsRebuild.mq5|
//| Purpose: One-click rebuild of insights.json from features.csv      |
//| Author: Windsurf Engineering                                       |
//+------------------------------------------------------------------+
#property strict
// #property script_show_inputs // disabled for headless runs (kb_check)

#include "..\\Include\\KnowledgeBase.mqh"

input string InKBPath       = "DualEA\\knowledge_base.csv";  // FILE_COMMON path
input string InFeaturesPath = "DualEA\\features.csv";        // FILE_COMMON path
input string OutInsights    = "DualEA\\insights.json";       // FILE_COMMON path
input int    TimeoutMs      = 60000; // Timeout for rebuild in ms (default: 60s)

void OnStart()
{
   Print("InsightsRebuild: starting rebuild from features.csv ...");
   CInsightsBuilder b(InKBPath, InFeaturesPath, OutInsights, ",");
   b.SetTimeoutMs(TimeoutMs);
   bool ok = b.Build();
   string full = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + OutInsights;
   if(ok)
      PrintFormat("InsightsRebuild: success. Wrote %s", full);
   else
      PrintFormat("InsightsRebuild: FAILED. See Experts log. Intended output: %s", full);
}
