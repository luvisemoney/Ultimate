#property strict
int OnInit()
{
   FolderCreate("ModelBuild");
   int file=FileOpen("ModelBuild\\broker_symbols.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(file==INVALID_HANDLE) return INIT_FAILED;
   FileWrite(file,"symbol","path","description","point","trade_mode");
   int total=SymbolsTotal(false);
   for(int i=0;i<total;i++)
   {
      string symbol=SymbolName(i,false);
      FileWrite(file,symbol,SymbolInfoString(symbol,SYMBOL_PATH),SymbolInfoString(symbol,SYMBOL_DESCRIPTION),
                DoubleToString(SymbolInfoDouble(symbol,SYMBOL_POINT),10),(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE));
   }
   FileClose(file);
   PrintFormat("[MODEL-UNIVERSE] symbols=%d exported",total);
   return total>0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick() {}
double OnTester() { return 1.0; }
