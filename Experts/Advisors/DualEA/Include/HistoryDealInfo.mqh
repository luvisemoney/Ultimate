//+------------------------------------------------------------------+
//| HistoryDealInfo.mqh - MQL5 Deal History Info Wrapper             |
//+------------------------------------------------------------------+
#ifndef __HISTORYDEALINFO_MQH__
#define __HISTORYDEALINFO_MQH__

// Wrapper class for accessing deal history in MQL5
class CHistoryDealInfo
  {
private:
   ulong   m_ticket;
   bool    m_valid;

public:
   CHistoryDealInfo() : m_ticket(0), m_valid(false) {}
   CHistoryDealInfo(ulong ticket) { Select(ticket); }

   bool Select(ulong ticket)
     {
      m_ticket = ticket;
      m_valid = HistoryDealSelect(ticket);
      return m_valid;
     }

   bool IsValid() const { return m_valid; }
   ulong Ticket() const { return m_ticket; }

   // Accessors for standard deal properties (use exact ENUM types)
   long    GetInteger(const ENUM_DEAL_PROPERTY_INTEGER property) const
     {
      if(!m_valid) return 0;
      long v = 0;
      if(HistoryDealGetInteger(m_ticket, property, v)) return v;
      return 0;
     }
   double  GetDouble(const ENUM_DEAL_PROPERTY_DOUBLE property) const
     {
      if(!m_valid) return 0.0;
      double v = 0.0;
      if(HistoryDealGetDouble(m_ticket, property, v)) return v;
      return 0.0;
     }
   string  GetString(const ENUM_DEAL_PROPERTY_STRING property) const
     {
      if(!m_valid) return "";
      string s = "";
      if(HistoryDealGetString(m_ticket, property, s)) return s;
      return "";
     }

   // Convenience methods for common properties
   ulong   Deal()        const { return m_ticket; }
   ulong   Order()       const { return GetInteger(DEAL_ORDER); }
   string  Symbol()      const { return GetString(DEAL_SYMBOL); }
   double  Volume()      const { return GetDouble(DEAL_VOLUME); }
   double  Price()       const { return GetDouble(DEAL_PRICE); }
   double  Profit()      const { return GetDouble(DEAL_PROFIT); }
   long    Type()        const { return GetInteger(DEAL_TYPE); }
   datetime Time()       const { return (datetime)GetInteger(DEAL_TIME); }
   long    Entry()       const { return GetInteger(DEAL_ENTRY); }
   long    Magic()       const { return GetInteger(DEAL_MAGIC); }
   long    Reason()      const { return GetInteger(DEAL_REASON); }
   long    PositionID()  const { return GetInteger(DEAL_POSITION_ID); }
   string  Comment()     const { return GetString(DEAL_COMMENT); }
  };

#endif // __HISTORYDEALINFO_MQH__
