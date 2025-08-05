//+------------------------------------------------------------------+
//|                                      ManualRiskIntegration.mq5    |
//|                        Copyright 2025, Your Company Name          |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property script_show_inputs
#property strict

// Input parameters
input string InpEAPath = "Experts\\EscapeEA_Enhanced.mq5";  // Path to EA file
input bool   InpBackupOriginal = true;                     // Create backup

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Create backup if requested
   if(InpBackupOriginal)
   {
      string backupPath = InpEAPath + ".bak";
      if(FileCopy(InpEAPath, 0, backupPath, FILE_REWRITE))
      {
         Print("Created backup: ", backupPath);
      }
      else
      {
         Print("Warning: Failed to create backup file");
      }
   }
   
   // Open the EA file
   int fileHandle = FileOpen(InpEAPath, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(fileHandle == INVALID_HANDLE)
   {
      Print("Failed to open EA file: ", GetLastError());
      return;
   }
   
   // Read the entire file
   string fileContent = "";
   while(!FileIsEnding(fileHandle))
   {
      fileContent += FileReadString(fileHandle) + "\n";
   }
   
   // 1. Add includes after the last include
   int lastIncludePos = StringFind(fileContent, "#include \"Escape/SecurityManager.mqh\"");
   if(lastIncludePos != -1)
   {
      int insertPos = StringFind(fileContent, "\n", lastIncludePos) + 1;
      if(insertPos > 0)
      {
         fileContent = StringSubstr(fileContent, 0, insertPos) + 
                     "#include <Experts/EscapeEA_RiskIntegration.mqh>\n" +
                     "#include <Experts/Risk/RiskManager.mqh>\n" +
                     StringSubstr(fileContent, insertPos);
      }
   }
   
   // 2. Add initialization to OnInit()
   int initPos = StringFind(fileContent, "int OnInit()");
   if(initPos != -1)
   {
      int openBrace = StringFind(fileContent, "{", initPos) + 1;
      if(openBrace > 0)
      {
         fileContent = StringSubstr(fileContent, 0, openBrace + 1) +
                     "\n   // Initialize risk management system\n   if(!InitializeRiskManagement())\n   {\n      Print(\"Failed to initialize risk management system\");\n      return INIT_FAILED;\n   }\n\n" +
                     StringSubstr(fileContent, openBrace + 1);
      }
   }
   
   // 3. Add deinitialization to OnDeinit()
   int deinitPos = StringFind(fileContent, "void OnDeinit");
   if(deinitPos != -1)
   {
      int deinitOpenBrace = StringFind(fileContent, "{", deinitPos) + 1;
      if(deinitOpenBrace > 0)
      {
         fileContent = StringSubstr(fileContent, 0, deinitOpenBrace + 1) +
                     "\n   // Deinitialize risk management system\n   if(CEscapeEARiskIntegration::Instance() != NULL)\n      CEscapeEARiskIntegration::Instance().Deinitialize();\n\n" +
                     StringSubstr(fileContent, deinitOpenBrace + 1);
      }
   }
   
   // 4. Add update to OnTick()
   int tickPos = StringFind(fileContent, "void OnTick()");
   if(tickPos != -1)
   {
      int tickOpenBrace = StringFind(fileContent, "{", tickPos) + 1;
      if(tickOpenBrace > 0)
      {
         fileContent = StringSubstr(fileContent, 0, tickOpenBrace + 1) +
                     "\n   // Update risk management system\n   UpdateRiskManagement();\n\n" +
                     StringSubstr(fileContent, tickOpenBrace + 1);
      }
   }
   
   // 5. Add position size validation before opening a position
   int tradePos = StringFind(fileContent, "trade.Buy(");
   if(tradePos == -1) tradePos = StringFind(fileContent, "trade.Sell(");
   
   if(tradePos != -1)
   {
      int ifPos = StringFindRev(fileContent, "if(", tradePos);
      if(ifPos != -1)
      {
         fileContent = StringSubstr(fileContent, 0, ifPos) +
                     "   // Check risk management before opening a position\n   double positionSize = 0.0;\n   if(!CanOpenPosition(_Symbol, ORDER_TYPE_BUY, SymbolInfoDouble(_Symbol, SYMBOL_ASK), \n                      stopLoss, takeProfit, positionSize))\n   {\n      Print(\"Risk management check failed - position not opened\");\n      return;\n   }\n\n" +
                     StringSubstr(fileContent, ifPos);
      }
   }
   
   // Write the modified content back to the file
   FileSeek(fileHandle, 0, SEEK_SET);
   FileWriteString(fileHandle, fileContent);
   FileClose(fileHandle);
   
   Print("Risk management integration completed successfully");
   Print("Please compile the EA to check for any errors");
}

//+------------------------------------------------------------------+
//| Find the last occurrence of a substring                          |
//+------------------------------------------------------------------+
int StringFindRev(const string str, const string find, int start=0)
{
   int pos = -1;
   int currentPos = 0;
   
   while((currentPos = StringFind(str, find, start)) != -1)
   {
      pos = currentPos;
      start = currentPos + 1;
   }
   
   return pos;
}
