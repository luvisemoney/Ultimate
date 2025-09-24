//+------------------------------------------------------------------+
//| ATR.mqh - Average True Range Indicator                           |
//+------------------------------------------------------------------+
#property copyright "2025, Windsurf Engineering"
#property link      "https://www.windsurf.ai"
#property version   "1.00"
#property strict

#include <Object.mqh>
#include <Indicators\Indicator.mqh>

//+------------------------------------------------------------------+
//| Class CiATR.                                                     |
//| Purpose: Class of the "Average True Range" indicator.            |
//|          Derives from class CIndicator.                          |
//+------------------------------------------------------------------+
class CiATR : public CIndicator
  {
protected:
   int               m_ma_period;

public:
                     CiATR(void);
                    ~CiATR(void);
   //--- methods of access to protected data
   int               MaPeriod(void)        const { return(m_ma_period); }
   //--- method of creation
   bool              Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
   //--- methods of access to indicator data
   double            Main(const int index) const;
   //--- method of identifying
   virtual int       Type(void) const { return(IND_ATR); }

protected:
   //--- methods of tuning
   virtual bool      Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[]);
   bool              Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CiATR::CiATR(void) : m_ma_period(-1)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CiATR::~CiATR(void)
  {
  }
//+------------------------------------------------------------------+
//| Create the "Average True Range" indicator                       |
//+------------------------------------------------------------------+
bool CiATR::Create(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
//--- check history
   if(!SetSymbolPeriod(symbol,period))
      return(false);
//--- create
   m_handle=iATR(symbol,period,ma_period);
//--- check result
   if(m_handle==INVALID_HANDLE)
      return(false);
//--- indicator successfully created
   if(!Initialize(symbol,period,ma_period))
     {
      //--- initialization failed
      IndicatorRelease(m_handle);
      m_handle=INVALID_HANDLE;
      //--- failed
      return(false);
     }
//--- ok
   return(true);
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with universal parameters               |
//+------------------------------------------------------------------+
bool CiATR::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int num_params,const MqlParam &params[])
  {
   return(Initialize(symbol,period,(int)params[0].integer_value));
  }
//+------------------------------------------------------------------+
//| Initialize the indicator with special parameters                 |
//+------------------------------------------------------------------+
bool CiATR::Initialize(const string symbol,const ENUM_TIMEFRAMES period,const int ma_period)
  {
   if(CreateBuffers(symbol,period,1))
     {
      //--- string of status of drawing
      m_name  ="ATR";
      m_status = "("+symbol+","+EnumToString(period)+","+IntegerToString(ma_period)+") H:"+IntegerToString(m_handle);
      //--- save settings
      m_ma_period=ma_period;
      //--- create buffers
      // Buffer type is set automatically by the framework
      //--- ok
      return(true);
     }
//--- error
   return(false);
  }
//+------------------------------------------------------------------+
//| Access to ATR buffer                                            |
//+------------------------------------------------------------------+
double CiATR::Main(const int index) const
  {
   CIndicatorBuffer *buffer=At(0);
//--- check
   if(buffer==NULL)
      return(EMPTY_VALUE);
//---
   return(buffer.At(index));
  }
