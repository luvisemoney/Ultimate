//+------------------------------------------------------------------+
//|                                                PolicyReload.mq5  |
//|                                      DualEA Utilities (Common)   |
//+------------------------------------------------------------------+
#property script_show_inputs

void OnStart()
  {
   string path = "DualEA\\policy.reload";
   // Create/overwrite the signal file in Common Files
   int h = FileOpen(path, FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_ANSI);
   if(h==INVALID_HANDLE)
     {
      PrintFormat("[PolicyReload] Failed to open %s in Common Files. err=%d", path, GetLastError());
      return;
     }
   datetime now = TimeCurrent();
   string msg = StringFormat("reload %s", TimeToString(now, TIME_DATE|TIME_SECONDS));
   FileWriteString(h, msg + "\n");
   FileClose(h);
   PrintFormat("[PolicyReload] Wrote signal at Common Files: %s", path);
  }
