//+------------------------------------------------------------------+
//|                                          FixEscapeEA.mq5          |
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
   
   // 1. Fix include paths
   fileContent = CustomStringReplace(fileContent, "#include \"Escape/", "#include <Escape/");
   
   // 2. Add missing enums
   int lastIncludePos = StringFind(fileContent, "#include");
   lastIncludePos = StringFind(fileContent, "#include", lastIncludePos + 1);
   lastIncludePos = StringFind(fileContent, "#include", lastIncludePos + 1);
   
   if(lastIncludePos != -1)
   {
      int insertPos = StringFind(fileContent, "\n", lastIncludePos) + 1;
      if(insertPos > 0)
      {
         string enumsToAdd = "\n// Scaling profiles for position management\n";
         enumsToAdd += "enum ENUM_SCALING_PROFILE {\n";
         enumsToAdd += "   SCALING_NONE,      // No scaling\n";
         enumsToAdd += "   SCALING_AGGRESSIVE,// Aggressive scaling\n";
         enumsToAdd += "   SCALING_CONSERVATIVE // Conservative scaling\n";
         enumsToAdd += "};\n\n";
         
         enumsToAdd += "// Exit profiles for position management\n";
         enumsToAdd += "enum ENUM_EXIT_PROFILE {\n";
         enumsToAdd += "   EXIT_AGGRESSIVE,   // Aggressive exit (tighter stops)\n";
         enumsToAdd += "   EXIT_BALANCED,     // Balanced exit\n";
         enumsToAdd += "   EXIT_CONSERVATIVE  // Conservative exit (wider stops)\n";
         enumsToAdd += "};\n\n";
         
         fileContent = StringSubstr(fileContent, 0, insertPos) + enumsToAdd + StringSubstr(fileContent, insertPos);
      }
   }
   
   // 3. Fix global variables
   int globalVarsPos = StringFind(fileContent, "// Global variables");
   if(globalVarsPos == -1) globalVarsPos = StringFind(fileContent, "//--- Global variables");
   
   if(globalVarsPos != -1)
   {
      int endVarsPos = StringFind(fileContent, "//+", globalVarsPos);
      if(endVarsPos == -1) endVarsPos = StringLen(fileContent);
      
      string globalVars = "// Global variables\n";
      globalVars += "CRiskManager* ExtRiskManager = NULL;\n";
      globalVars += "CTradeExecutor* ExtTradeExecutor = NULL;\n";
      globalVars += "CPaperTrading* ExtPaperTrading = NULL;\n";
      globalVars += "CEnhancedSecurity* ExtSecurity = NULL;\n";
      globalVars += "CPositionManager* ExtPositionManager = NULL;\n";
      globalVars += "CSecurityManager* ExtSecurityManager = NULL;\n";
      
      fileContent = StringSubstr(fileContent, 0, globalVarsPos) + globalVars + StringSubstr(fileContent, endVarsPos);
   }
   
   // 4. Remove duplicate ManagePositions function
   int managePos1 = StringFind(fileContent, "void ManagePositions()");
   if(managePos1 != -1)
   {
      int managePos2 = StringFind(fileContent, "void ManagePositions()", managePos1 + 1);
      if(managePos2 != -1)
      {
         // Find the end of the first ManagePositions function
         int endPos1 = StringFind(fileContent, "}", managePos1);
         while(StringFind(fileContent, "{", managePos1) < endPos1 && endPos1 != -1)
         {
            endPos1 = StringFind(fileContent, "}", endPos1 + 1);
         }
         
         if(endPos1 != -1)
         {
            // Remove the first occurrence
            fileContent = StringSubstr(fileContent, 0, managePos1) + 
                         StringSubstr(fileContent, endPos1 + 1);
         }
      }
   }
   
   // 5. Fix code in global scope (simple check)
   int lastBrace = StringFind(fileContent, "//+------------------------------------------------------------------+", 
                             StringFind(fileContent, "void OnDeinit"));
   if(lastBrace != -1)
   {
      string afterLastBrace = StringSubstr(fileContent, lastBrace);
      if(StringFind(afterLastBrace, "if(") != -1 || 
         StringFind(afterLastBrace, "for(") != -1 ||
         StringFind(afterLastBrace, "while(") != -1 ||
         StringFind(afterLastBrace, "return") != -1)
      {
         // Move all code after last function into OnDeinit
         int onDeinitPos = StringFind(fileContent, "void OnDeinit");
         int onDeinitEnd = StringFind(fileContent, "}", onDeinitPos) + 1;
         
         if(onDeinitPos != -1 && onDeinitEnd != -1)
         {
            string beforeDeinit = StringSubstr(fileContent, 0, onDeinitEnd - 1);
            string afterDeinit = StringSubstr(fileContent, onDeinitEnd);
            string codeToMove = StringSubstr(afterDeinit, 0, StringFind(afterDeinit, "//+"));
            
            fileContent = beforeDeinit + "\n   // Moved from global scope\n" + codeToMove + "\n}" + 
                         StringSubstr(afterDeinit, StringFind(afterDeinit, "//+"));
         }
      }
   }
   
   // Write the modified content back to the file
   FileSeek(fileHandle, 0, SEEK_SET);
   FileWriteString(fileHandle, fileContent);
   FileClose(fileHandle);
   
   Print("EA file has been processed. Please compile to check for any remaining errors.");
   Print("1. Fixed include paths");
   Print("2. Added missing enums");
   Print("3. Fixed global variables");
   Print("4. Removed duplicate ManagePositions function");
   Print("5. Moved code from global scope into OnDeinit");
}

//+------------------------------------------------------------------+
//| Helper function to replace all occurrences of a string           |
//+------------------------------------------------------------------+
string CustomStringReplace(const string str, const string find, const string replacement)
{
   string result = "";
   int pos = 0, lastPos = 0;
   
   while((pos = StringFind(str, find, lastPos)) != -1)
   {
      result += StringSubstr(str, lastPos, pos - lastPos) + replacement;
      lastPos = pos + StringLen(find);
   }
   
   result += StringSubstr(str, lastPos);
   return result;
}
