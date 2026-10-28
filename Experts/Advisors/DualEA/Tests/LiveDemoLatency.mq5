#property strict
// Observation build of the real EA. Keep all state in this portable terminal.
#define DUALEA_RUNTIME_STORAGE_MQH
#define DUALEA_FILE_COMMON 0
#define DUALEA_DATABASE_COMMON 0
#define DUALEA_TICK_PROFILING
#define OnInit ObservedEAInit
#define OnTick ObservedEATick
#define OnTimer ObservedEATimer
#define OnDeinit ObservedEADeinit
#include "../PaperEA/PaperEA_v2.mq5"
#undef OnInit
#undef OnTick
#undef OnTimer
#undef OnDeinit

input int ObservationSeconds=180;
ulong observation_started=0,last_callback=0;
double durations[];
int observed=0,over_warning=0,over_critical=0,timer_samples=0,disconnected_samples=0;
double maximum_gap_ms=0,maximum_timer_ms=0,ping_min_ms=DBL_MAX,ping_max_ms=0;
int ping_samples=0;
bool observation_initialized=false,observation_complete=false;

int OnInit()
{
   string observation_path=TerminalInfoString(TERMINAL_DATA_PATH);
   StringToLower(observation_path);
   if(StringFind(observation_path,"\\dualea\\tests\\tester\\runtime")<0)
   {
      Print("[LIVE-OBSERVE REJECT] This observer may run only in its isolated portable runtime.");
      return INIT_FAILED;
   }
   PrintFormat("[LIVE-OBSERVE CONFIG] tester=%d account_mode=%d live=%d shadow=%d autotrading=%d seconds=%d",
      (int)MQLInfoInteger(MQL_TESTER),(int)AccountInfoInteger(ACCOUNT_TRADE_MODE),(int)LiveTradingEnabled,(int)ShadowMode,(int)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED),ObservationSeconds);
   // Refuse to run with unsafe settings, including if preset loading failed.
   if(MQLInfoInteger(MQL_TESTER) || AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO ||
      LiveTradingEnabled || !ShadowMode || ObservationSeconds<30 || ObservationSeconds>86400 ||
      TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Print("[LIVE-OBSERVE REJECT] Requires DEMO, ShadowMode=true, LiveTradingEnabled=false, terminal autotrading disabled, 30..86400 seconds.");
      TerminalClose(1);
      return INIT_FAILED;
   }
   int result=ObservedEAInit();
   if(result!=INIT_SUCCEEDED) return result;
   observation_initialized=true;
   observation_started=GetMicrosecondCount();
   // Preserve the EA's configured timer cadence for representative observation.
   Print("[LIVE-OBSERVE START] demo=true execution=DISABLED symbol=",_Symbol," seconds=",ObservationSeconds);
   return INIT_SUCCEEDED;
}

void OnTick()
{
   const ulong started=GetMicrosecondCount();
   if(last_callback>0) maximum_gap_ms=MathMax(maximum_gap_ms,(double)(started-last_callback)/1000.0);
   last_callback=started;
   ObservedEATick();
   const double elapsed=(double)(GetMicrosecondCount()-started)/1000.0;
   if(observed>=1000000){Print("[LIVE-OBSERVE REJECT] sample capacity exceeded");TerminalClose(1);return;}
   if(ArrayResize(durations,observed+1,16384)!=observed+1){Print("[LIVE-OBSERVE REJECT] allocation failed");TerminalClose(1);return;}
   durations[observed++]=elapsed;
   if(elapsed>10) over_warning++;
   if(elapsed>50) over_critical++;
}

void OnTimer()
{
   const ulong started=GetMicrosecondCount();
   ObservedEATimer();
   maximum_timer_ms=MathMax(maximum_timer_ms,(double)(GetMicrosecondCount()-started)/1000.0);
   timer_samples++;
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)) disconnected_samples++;
   else
   {
      const long ping=TerminalInfoInteger(TERMINAL_PING_LAST);
      if(ping>0){double ms=(double)ping/1000.0;ping_min_ms=MathMin(ping_min_ms,ms);ping_max_ms=MathMax(ping_max_ms,ms);ping_samples++;}
   }
   if(GetMicrosecondCount()-observation_started>=(ulong)ObservationSeconds*1000000)
   {observation_complete=true;TerminalClose(0);}
}

void OnDeinit(const int reason)
{
   if(!observation_initialized) return;
   const double seconds=(double)(GetMicrosecondCount()-observation_started)/1000000.0;
   int csv=FileOpen("live-demo-durations.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(csv!=INVALID_HANDLE){FileWrite(csv,"callback","handler_ms");for(int i=0;i<observed;i++) FileWrite(csv,i+1,DoubleToString(durations[i],6));FileClose(csv);}
   ArraySort(durations);
   double p50=0,p95=0,p99=0,maximum=0;
   if(observed>0){p50=durations[(int)MathCeil(observed*0.50)-1];p95=durations[(int)MathCeil(observed*0.95)-1];p99=durations[(int)MathCeil(observed*0.99)-1];maximum=durations[observed-1];}
   const string result=StringFormat("{\"complete\":%s,\"demo\":true,\"execution_disabled\":true,\"symbol\":\"%s\",\"elapsed_seconds\":%.3f,\"handler_samples\":%d,\"p50_ms\":%.6f,\"p95_ms\":%.6f,\"p99_ms\":%.6f,\"max_handler_ms\":%.6f,\"warning_exceedances\":%d,\"critical_exceedances\":%d,\"max_callback_gap_ms\":%.3f,\"timer_samples\":%d,\"max_timer_ms\":%.3f,\"disconnected_timer_samples\":%d,\"ping_samples\":%d,\"last_known_ping_min_ms\":%.3f,\"last_known_ping_max_ms\":%.3f,\"feed_delivery_latency\":\"UNMEASURED\",\"deinit_reason\":%d}",
      observation_complete?"true":"false",_Symbol,seconds,observed,p50,p95,p99,maximum,over_warning,over_critical,maximum_gap_ms,timer_samples,maximum_timer_ms,disconnected_samples,ping_samples,ping_samples>0?ping_min_ms:0,ping_max_ms,reason);
   int file=FileOpen("live-demo-summary.json",FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(file!=INVALID_HANDLE){FileWriteString(file,result);FileClose(file);}
   Print("[LIVE-OBSERVE RESULT] ",result);
   ObservedEADeinit(reason);
}
