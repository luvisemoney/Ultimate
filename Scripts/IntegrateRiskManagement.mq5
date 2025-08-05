//+------------------------------------------------------------------+
//|                                         IntegrateRiskManagement.mq5 |
//|                        Copyright 2025, Your Company Name          |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Company Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"
#property script_show_inputs
#property strict

// Input parameters for the integration
input string   InpEAPath = "Experts\\EscapeEA_Enhanced.mq5";  // Path to EA file
input bool     InpBackupOriginal = true;                     // Create backup of original file

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   // Define the changes to be made
   string changes = "";
   
   // 1. Add includes at the top of the file
   changes += "#include <Experts/EscapeEA_RiskIntegration.mqh>\n";
   
   // 2. Add risk management initialization to OnInit()
   changes += "   // Initialize risk management system\n";
   changes += "   if(!InitializeRiskManagement())\n";
   changes += "   {\n";
   changes += "      Print(\"Failed to initialize risk management system\");\n";
   changes += "      return INIT_FAILED;\n";
   changes += "   }\n\n";
   
   // 3. Add risk management update to OnTick()
   changes += "   // Update risk management system\n";
   changes += "   UpdateRiskManagement();\n\n";
   
   // 4. Add risk management validation before opening a position
   changes += "   // Check risk management before opening a position\n";
   changes += "   double positionSize = 0.0;\n";
   changes += "   if(!CanOpenPosition(_Symbol, signalType, price, stopLoss, takeProfit, positionSize))\n";
   changes += "   {\n";
   changes += "      Print(\"Risk management check failed - position not opened\");\n";
   changes += "      return;\n";
   changes += "   }\n\n";
   
   // 5. Add position metrics update after opening a position
   changes += "   // Update position metrics after opening\n";
   changes += "   UpdatePositionMetrics(_Symbol, position.volume, position.price_open, currentPrice);\n\n";
   
   // 6. Add risk management deinitialization to OnDeinit()
   changes += "   // Deinitialize risk management system\n";
   changes += "   if(CEscapeEARiskIntegration::Instance() != NULL)\n";
   changes += "      CEscapeEARiskIntegration::Instance().Deinitialize();\n\n";
   
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
   
   // Apply changes to the EA file
   int fileHandle = FileOpen(InpEAPath, FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(fileHandle != INVALID_HANDLE)
   {
      // Read the entire file
      string fileContent = "";
      while(!FileIsEnding(fileHandle))
      {
         fileContent += FileReadString(fileHandle) + "\n";
      }
      
      // Insert the changes
      // 1. Add includes after the last include
      int lastIncludePos = StringFind(fileContent, "#include", 0);
      if(lastIncludePos != -1)
      {
         // Find the end of the last include
         int insertPos = StringFind(fileContent, "\n", lastIncludePos) + 1;
         if(insertPos > 0)
         {
            fileContent = StringSubstr(fileContent, 0, insertPos) + 
                         "#include <Experts/EscapeEA_RiskIntegration.mqh>\n" +
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
      
      // 3. Add update to OnTick()
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
      
      // 4. Add position validation before opening a position
      int openPosPos = StringFind(fileContent, "if(trade.Buy(") > 0 ? 
                     StringFind(fileContent, "if(trade.Buy(") : 
                     StringFind(fileContent, "if(trade.Sell(");
      
      if(openPosPos != -1)
      {
         int ifStart = StringFindRev(fileContent, "if(", openPosPos);
         if(ifStart != -1)
         {
            fileContent = StringSubstr(fileContent, 0, ifStart) +
                         "   // Check risk management before opening a position\n   double positionSize = 0.0;\n   if(!CanOpenPosition(_Symbol, signalType, price, stopLoss, takeProfit, positionSize))\n   {\n      Print(\"Risk management check failed - position not opened\");\n      return;\n   }\n\n" +
                         StringSubstr(fileContent, ifStart);
         }
      }
      
      // 5. Add position metrics update after opening
      int tradeSuccessPos = StringFind(fileContent, "if(trade.ResultRetcode() == TRADE_RETCODE_DONE)");
      if(tradeSuccessPos != -1)
      {
         int openBracePos = StringFind(fileContent, "{", tradeSuccessPos) + 1;
         if(openBracePos > 0)
         {
            fileContent = StringSubstr(fileContent, 0, openBracePos + 1) +
                         "\n      // Update position metrics after opening\n      UpdatePositionMetrics(_Symbol, position.volume, position.price_open, currentPrice);\n\n" +
                         StringSubstr(fileContent, openBracePos + 1);
         }
      }
      
      // 6. Add deinitialization to OnDeinit()
      int deinitPos = StringFind(fileContent, "void OnDeinit(");
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
      
      // Write the modified content back to the file
      FileSeek(fileHandle, 0, SEEK_SET);
      FileWriteString(fileHandle, fileContent);
      
      FileClose(fileHandle);
      
      Print("Successfully integrated risk management into ", InpEAPath);
      Print("Please review the changes and test thoroughly before using in live trading.");
   }
   else
   {
      Print("Failed to open EA file: ", GetLastError());
   }
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
