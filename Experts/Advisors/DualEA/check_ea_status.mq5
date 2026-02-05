//+------------------------------------------------------------------+
//| EA Status Check Script                                       |
//+------------------------------------------------------------------+
#property script_show_inputs

input string CheckFile = "DualEA\\onnx_config.ini";

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   string common_root = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\";
   string rel = CheckFile;
   
   Print("=== EA Status Check (FILE_COMMON) ===");
   Print("Common Files Root: ", common_root);
   Print("Relative Check File: ", rel);
   Print("Absolute Check File: ", common_root + rel);
   
   bool exists = FileIsExist(rel, true);
   Print("File Exists (COMMON): ", exists ? "YES" : "NO");
   
   if(exists)
   {
      int handle = FileOpen(rel, FILE_READ|FILE_TXT|FILE_COMMON);
      Print("Open TXT+COMMON: ", handle != INVALID_HANDLE ? "SUCCESS" : "FAILED");
      if(handle != INVALID_HANDLE)
      {
         string first_line = FileReadString(handle);
         Print("First 80 chars: ", StringSubstr(first_line, 0, 80));
         FileClose(handle);
      }
      else
      {
         Print("Last Error: ", GetLastError());
      }
   }
   else
   {
      Print("ERROR: File not found in Common Files sandbox. Deploy using deploy_onnx_to_common.bat");
   }
   
   Print("=== Check Complete ===");
}
