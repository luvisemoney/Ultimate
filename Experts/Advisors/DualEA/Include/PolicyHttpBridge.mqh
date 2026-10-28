#include "RuntimeStorage.mqh"
#ifndef __DUALEA_POLICY_HTTP_BRIDGE_MQH__
#define __DUALEA_POLICY_HTTP_BRIDGE_MQH__

#include <Files/File.mqh>
#include "LogMiddleware.mqh"

class CPolicyHttpBridge
{
private:
   string m_policy_file;
   int m_reload_secs;
   datetime m_last_check;
   ulong m_last_hash;
   bool m_seen_file;
   bool m_warned_tester;
   bool m_http_blocked;
   datetime m_last_failure_log;

   bool CanRequest()
   {
      // MQL_TESTER is a runtime property, not a preprocessor symbol.
      if(MQLInfoInteger(MQL_TESTER))
      {
         if(!m_warned_tester)
         {
            LOG("Policy HTTP disabled in Strategy Tester; using the supplied policy file only.");
            m_warned_tester=true;
         }
         return false;
      }
      return !m_http_blocked;
   }
   void RequestFailed(string url,int status,int error)
   {
      if(error==4014)
      {
         if(!m_http_blocked)
            LOG(StringFormat("Policy HTTP prohibited (4014). For terminal use, allow the policy URL in Tools > Options > Expert Advisors > WebRequest: %s. File policy remains available; HTTP retries stop until EA restart.",url));
         m_http_blocked=true;
         return;
      }
      datetime now=TimeCurrent();
      if(m_last_failure_log==0 || now-m_last_failure_log>=60)
      {
         LOG(StringFormat("Policy HTTP failed: status=%d error=%d url=%s; keeping the current file policy",status,error,url));
         m_last_failure_log=now;
      }
   }
public:
   CPolicyHttpBridge() : m_policy_file(""),m_reload_secs(10),m_last_check(0),m_last_hash(0),m_seen_file(false),m_warned_tester(false),m_http_blocked(false),m_last_failure_log(0) {}
   void Configure(const string policy_file,const int reload_secs)
   {
      m_policy_file=policy_file;
      m_reload_secs=(reload_secs>0 ? reload_secs : 10);
      m_last_check=0;
      m_last_hash=0;
      m_seen_file=false;
      m_http_blocked=false;
   }
   bool VerifyAccess(const string url)
   {
      if(!CanRequest()) return false;
      string trimmed=url;
      StringTrimLeft(trimmed);
      StringTrimRight(trimmed);
      if(trimmed=="") return false;
      char data[],response[];
      string headers;
      ArrayResize(data,0);
      ResetLastError();
      int status=WebRequest("GET",trimmed,"",3000,data,response,headers);
      if(status>=200 && status<300) return true;
      RequestFailed(trimmed,status,GetLastError());
      return false;
   }
   // Fingerprint content as well as size: fixed-length risk changes must reload.
   bool UpdateIfStale()
   {
      datetime now=TimeCurrent();
      if(m_policy_file=="") return false;
      if(m_last_check!=0 && now-m_last_check<m_reload_secs) return false;
      m_last_check=now;
      int file=FileOpen(m_policy_file,FILE_READ|FILE_BIN|DUALEA_FILE_COMMON|FILE_SHARE_READ);
      if(file==INVALID_HANDLE) file=FileOpen(m_policy_file,FILE_READ|FILE_BIN|FILE_SHARE_READ);
      if(file==INVALID_HANDLE) return false;
      ulong size=FileSize(file);
      if(size==0 || size>16777216)
      {
         FileClose(file);
         return false;
      }
      uchar bytes[];
      ArrayResize(bytes,(int)size);
      uint copied=FileReadArray(file,bytes,0,(int)size);
      FileClose(file);
      if(copied!=size) return false;
      ulong hash=1469598103934665603;
      for(int i=0;i<(int)size;i++) hash=(hash^(ulong)bytes[i])*1099511628211;
      if(!m_seen_file || hash!=m_last_hash)
      {
         m_last_hash=hash;
         m_seen_file=true;
         LOG(StringFormat("Policy file content changed, size=%I64u",size));
         return true;
      }
      return false;
   }
   bool Pull(const string url)
   {
      if(m_policy_file=="" || !CanRequest()) return false;
      char data[],result[];
      string headers;
      ArrayResize(data,0);
      ResetLastError();
      int status=WebRequest("GET",url,"Accept: application/json\r\n",5000,data,result,headers);
      if(status!=200 && status!=201)
      {
         RequestFailed(url,status,GetLastError());
         return false;
      }
      string body=CharArrayToString(result,0,ArraySize(result),CP_UTF8);
      StringTrimLeft(body);
      StringTrimRight(body);
      // Reject error pages/empty responses before replacing the last good policy.
      if(StringLen(body)<2 || StringGetCharacter(body,0)!='{' || StringGetCharacter(body,StringLen(body)-1)!='}')
      {
         LOG("PolicyHttpBridge: response is not a JSON object; retaining existing policy");
         return false;
      }
      string temporary=m_policy_file+".http.tmp";
      int file=FileOpen(temporary,FILE_WRITE|FILE_BIN|DUALEA_FILE_COMMON);
      if(file==INVALID_HANDLE)
      {
         LOG(StringFormat("PolicyHttpBridge: cannot write temporary policy, error=%d",GetLastError()));
         return false;
      }
      uchar bytes[];
      int length=StringToCharArray(body,bytes,0,WHOLE_ARRAY,CP_UTF8)-1;
      uint written=FileWriteArray(file,bytes,0,length);
      FileFlush(file);
      FileClose(file);
      if(written!=(uint)length || !FileMove(temporary,DUALEA_FILE_COMMON,m_policy_file,DUALEA_FILE_COMMON|FILE_REWRITE))
      {
         LOG(StringFormat("PolicyHttpBridge: policy replacement failed, error=%d",GetLastError()));
         FileDelete(temporary,DUALEA_FILE_COMMON);
         return false;
      }
      m_seen_file=false;
      LOG(StringFormat("Policy pull succeeded: %s (%d UTF-8 bytes)",url,length));
      return true;
   }
};
#endif