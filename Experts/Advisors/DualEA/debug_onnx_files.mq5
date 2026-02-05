//+------------------------------------------------------------------+
//| Debug script to test ONNX file access                              |
//+------------------------------------------------------------------+
#property script_show_inputs
#property copyright "Debug ONNX Files"

input string TestPath = "signal_model.onnx";

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   string terminal_data = TerminalInfoString(TERMINAL_DATA_PATH);
   string libraries_path = terminal_data + "\\MQL5\\Libraries\\";
   
   string model_path = libraries_path + TestPath;
   string ini_path = libraries_path + "onnx_config.ini";
   
   Print("Terminal Data Path: ", terminal_data);
   Print("Libraries Path: ", libraries_path);
   Print("Model Path: ", model_path);
   Print("INI Path: ", ini_path);
   
   // Test file existence
   bool model_exists = FileIsExist(model_path);
   bool ini_exists = FileIsExist(ini_path);
   
   Print("Model file exists: ", model_exists ? "YES" : "NO");
   Print("INI file exists: ", ini_exists ? "YES" : "NO");
   
   // Test opening INI file
   if(ini_exists)
   {
      int handle = FileOpen(ini_path, FILE_READ|FILE_TXT);
      if(handle != INVALID_HANDLE)
      {
         Print("INI file opened successfully");
         string line = FileReadString(handle);
         Print("First line: ", line);
         FileClose(handle);
      }
      else
      {
         Print("Failed to open INI file, error: ", GetLastError());
         
         // Try with different flags
         handle = FileOpen(ini_path, FILE_READ|FILE_TXT|FILE_ANSI);
         if(handle != INVALID_HANDLE)
         {
            Print("INI file opened with ANSI flag");
            FileClose(handle);
         }
         else
         {
            Print("Failed to open INI file with ANSI flag, error: ", GetLastError());
         }
      }
   }
}
