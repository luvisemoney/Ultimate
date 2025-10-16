#ifndef __DUALEA_POLICY_HTTP_BRIDGE_MQH__
#define __DUALEA_POLICY_HTTP_BRIDGE_MQH__

#include <Files/File.mqh>
#include "LogMiddleware.mqh"

class CPolicyHttpBridge
{
private:
   string   m_policy_file;     // where EA reads policy from (Common Files path allowed)
   int      m_reload_secs;     // minimum interval between checks
   datetime m_last_check;
   long     m_last_size;

public:
   CPolicyHttpBridge(): m_policy_file(""), m_reload_secs(10), m_last_check(0), m_last_size(-1) {}

   void Configure(const string policy_file, const int reload_secs)
   {
      m_policy_file = policy_file;
      m_reload_secs = (reload_secs>0? reload_secs:10);
      m_last_check  = 0;
      m_last_size   = -1;
   }

   // Returns true if the on-disk policy file size changed since last check
   bool UpdateIfStale()
   {
      datetime now = TimeCurrent();
      if(m_policy_file=="") return false;
      if(m_last_check!=0 && (now - m_last_check) < m_reload_secs) return false;
      m_last_check = now;

      // Check file in Common first
      int h = FileOpen(m_policy_file, FILE_READ|FILE_TXT|FILE_COMMON);
      if(h == INVALID_HANDLE)
      {
         // Fall back to user Files
         h = FileOpen(m_policy_file, FILE_READ|FILE_TXT);
         if(h == INVALID_HANDLE)
         {
            // File absent is not an error; simply no update
            return false;
         }
      }

      long sz = (long)FileSize(h);
      FileClose(h);
      if(sz != m_last_size)
      {
         m_last_size = sz;
         LOG(StringFormat("Policy file changed, size=%ld", sz));
         return true;
      }
      return false;
   }

   // Pull policy JSON from HTTP endpoint and write to file. Requires MT5 WebRequest whitelist.
   bool Pull(const string url)
   {
      if(m_policy_file=="") return false;
      string headers = "Content-Type: application/json\r\n";
      char data[]; ArrayResize(data, 0);
      char result[]; string result_headers;
      int status = WebRequest("GET", url, headers, 5000, data, result, result_headers);
      if(status==200 || status==201)
      {
         string body = CharArrayToString(result, 0, -1);
         int h = FileOpen(m_policy_file, FILE_WRITE|FILE_TXT|FILE_COMMON);
         if(h == INVALID_HANDLE)
         {
            h = FileOpen(m_policy_file, FILE_WRITE|FILE_TXT);
         }
         if(h == INVALID_HANDLE)
         {
            LOG(StringFormat("PolicyHttpBridge: Cannot open %s for write, error=%d", m_policy_file, GetLastError()));
            return false;
         }
         FileWriteString(h, body);
         FileClose(h);
         LOG(StringFormat("Policy pull success: %s (len=%d)", url, StringLen(body)));
         // Force stale so UpdateIfStale will report change on next call
         m_last_size = -1;
         return true;
      }
      if(status==-1)
      {
         LOG(StringFormat("Policy pull failed: %s (error=%d). Ensure URL is whitelisted in MT5 WebRequest.", url, GetLastError()));
      }
      else
      {
         LOG(StringFormat("Policy pull HTTP status: %d for %s", status, url));
      }
      return false;
   }
};

#endif // __DUALEA_POLICY_HTTP_BRIDGE_MQH__
