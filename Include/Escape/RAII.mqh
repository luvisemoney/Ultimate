//+------------------------------------------------------------------+
//|                                                   RAII.mqh        |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"
#property strict

#include <Object.mqh>

//+------------------------------------------------------------------+
//| RAII wrapper for file handles                                    |
//+------------------------------------------------------------------+
class CFileRAII {
private:
   int              m_handle;  // File handle (MQL5 FileOpen returns int)
   
   // Prevent copying
   CFileRAII(const CFileRAII&);
   void operator=(const CFileRAII&);
   
public:
   CFileRAII(const string filename, const int flags, const int delimiter = '\t', const int codepage = CP_ACP) {
      // FileOpen returns int according to MQL5 documentation
      m_handle = (int)FileOpen(filename, flags, delimiter, codepage);
   }
   
   ~CFileRAII() {
      if(m_handle != INVALID_HANDLE) {
         FileClose(m_handle);
      }
   }
   
   // Check if file was opened successfully
   bool IsValid() const {
      return m_handle != INVALID_HANDLE;
   }
   
   // Get the file handle
   int GetHandle() const {
      return m_handle;
   }
   
   // Get the file handle as long if needed
   long GetHandleAsLong() const {
      return (long)m_handle;
   }
   
   // Check if handle is valid
   bool IsHandleValid() const {
      return m_handle != INVALID_HANDLE;
   }
};

//+------------------------------------------------------------------+
//| RAII wrapper for indicators                                      |
//+------------------------------------------------------------------+
class CIndicatorRAII {
private:
   int m_handle;
   
   // Prevent copying
   CIndicatorRAII(const CIndicatorRAII&);
   void operator=(const CIndicatorRAII&);
   
public:
   // Constructor for indicators with up to 8 parameters (MQL5 limit for iCustom)
   CIndicatorRAII(const string symbol, const ENUM_TIMEFRAMES timeframe, const string name, 
                 const int param1=0, const int param2=0, const int param3=0, const int param4=0,
                 const int param5=0, const int param6=0, const int param7=0, const int param8=0) {
      m_handle = iCustom(symbol, timeframe, name, param1, param2, param3, param4, param5, param6, param7, param8);
   }
   
   ~CIndicatorRAII() {
      if(m_handle != INVALID_HANDLE) {
         IndicatorRelease(m_handle);
      }
   }
   
   // Check if indicator was created successfully
   bool IsValid() const {
      return m_handle != INVALID_HANDLE;
   }
   
   // Get the indicator handle
   int GetHandle() const {
      return m_handle;
   }
};

//+------------------------------------------------------------------+
//| RAII wrapper for arrays                                          |
//+------------------------------------------------------------------+
template<typename T>
class CArrayRAII {
private:
   T m_array[];
   
   // Prevent copying
   CArrayRAII(const CArrayRAII&);
   void operator=(const CArrayRAII&);
   
public:
   CArrayRAII(int size = 0, int reserve = 0) {
      if (reserve > 0) {
         ArrayResize(m_array, 0, reserve);
      }
      if (size > 0) {
         ArrayResize(m_array, size);
      }
   }
   
   ~CArrayRAII() {
      ArrayFree(m_array);
   }
   
   // Resize the array
   int Resize(int size, int reserve = 0) {
      return ArrayResize(m_array, size, reserve);
   }
   
   // Get array size
   int Size() const {
      return ArraySize(m_array);
   }
   
   // Access array elements
   T operator[](int index) const {
      return m_array[index];
   }
   
   // Access array elements by reference
   T& operator[](int index) {
      return m_array[index];
   }
};

//+------------------------------------------------------------------+
//| RAII wrapper for critical sections                               |
//+------------------------------------------------------------------+
class CCriticalSectionRAII {
private:
   static int m_lock;
   
   // Prevent copying
   CCriticalSectionRAII(const CCriticalSectionRAII&);
   void operator=(const CCriticalSectionRAII&);
   
public:
   CCriticalSectionRAII() {
      while (true) {
         if (m_lock == 0) {
            m_lock = 1;
            break;
         }
         Sleep(1);
      }
   }
   
   ~CCriticalSectionRAII() {
      m_lock = 0;
   }
};

// Initialize static member
static int CCriticalSectionRAII::m_lock = 0;
