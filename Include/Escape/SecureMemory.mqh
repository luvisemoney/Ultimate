//+------------------------------------------------------------------+
//|                                              SecureMemory.mqh     |
//|                                          Copyright 2025, EscapeEA |
//|                                             https://www.escapeea.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.10"  // Added RAII support and error context
#property strict

#include "RAII.mqh"

//+------------------------------------------------------------------+
//| RAII wrapper for dynamic memory allocation                       |
//+------------------------------------------------------------------+
template<typename T>
class CSafePtr {
private:
   T* m_ptr;
   
   // Prevent copying
   CSafePtr(const CSafePtr&);
   void operator=(const CSafePtr&);
   
public:
   // Default constructor
   CSafePtr() : m_ptr(NULL) {}
   
   // Constructor with allocation
   CSafePtr(T* ptr) : m_ptr(ptr) {}
   
   // Destructor
   ~CSafePtr() {
      SafeDelete(m_ptr);
   }
   
   // Get the raw pointer
   T* Get() const {
      return m_ptr;
   }
   
   // Release ownership
   T* Release() {
      T* ptr = m_ptr;
      m_ptr = NULL;
      return ptr;
   }
   
   // Reset the pointer
   void Reset(T* ptr = NULL) {
      if(m_ptr != ptr) {
         SafeDelete(m_ptr);
         m_ptr = ptr;
      }
   }
   
   // Dereference operators
   T* operator->() const {
      return m_ptr;
   }
   
   T& operator*() const {
      return *m_ptr;
   }
   
   // Boolean check
   bool IsValid() const {
      return m_ptr != NULL;
   }
};

//+------------------------------------------------------------------+
//| Safely delete an object and nullify the pointer                  |
//+------------------------------------------------------------------+
template<typename T>
void SafeDelete(T* &ptr, const string context = "") {
   if(CheckPointer(ptr) == POINTER_DYNAMIC) {
      string typeName = typename(T);
      delete ptr;
      ptr = NULL;
      
      // Log the deletion if context is provided
      if(context != "") {
         PrintFormat("[%s] Safely deleted %s object", context, typeName);
      }
   }
}

//+------------------------------------------------------------------+
//| RAII wrapper for secure string clearing                          |
//+------------------------------------------------------------------+
class CSecureString {
private:
   string m_str;
   
   // Prevent copying
   CSecureString(const CSecureString&);
   void operator=(const CSecureString&);
   
public:
   CSecureString(const string str) {
      m_str = str;
   }
   ~CSecureString() {
      // Overwrite the string with zeros before clearing
      uchar array[];
      StringToCharArray(m_str, array, 0, -1, CP_ACP);
      ArrayInitialize(array, 0);
      m_str = "";
   }
   
   // Get the string value
   string Get() const {
      return m_str;
   }
   
   // Get string value
   string ToString() const {
      return m_str;
   }
};

//+------------------------------------------------------------------+
//| RAII wrapper for secure array clearing                           |
//+------------------------------------------------------------------+
template<typename T>
class CSecureArray {
private:
   T &m_array[];
   
   // Prevent copying
   CSecureArray(const CSecureArray&);
   void operator=(const CSecureArray&);
   
public:
   CSecureArray(T &array[]) { 
      ArrayCopy(m_array, array);
   }
   
   ~CSecureArray() {
      SecureArrayClear(m_array, "CSecureArray");
   }
};

//+------------------------------------------------------------------+
//| Safe memory management functions                                 |
//+------------------------------------------------------------------+

//--- Safe delete for arrays
template<typename T>
void SafeArrayDelete(T &array[]) {
   for(int i = 0; i < ArraySize(array); i++) {
      if(CheckPointer(array[i]) == POINTER_DYNAMIC) {
         delete array[i];
         array[i] = NULL;
      }
   }
   ArrayFree(array);
}

//--- Safe string copy with length checking
bool SafeStringCopy(string &dest, const string source, const int max_length) {
   int src_len = StringLen(source);
   if(src_len >= max_length) {
      Print("Error: String too long in SafeStringCopy");
      return false;
   }
   
   // Clear destination
   dest = "";
   
   // Copy source to destination
   if(src_len > 0) {
      dest = source;
   }
   
   return true;
}

//--- Secure memory zeroing
template<typename T>
void SecureZeroMemory(T &data[], uint size) {
   if(size > 0 && size <= ArraySize(data)) {
      for(uint i = 0; i < size; i++) {
         data[i] = (T)0;
      }
   }
}

//--- Memory allocation with null check
template<typename T>
T* SafeNew() {
   T *ptr = new T();
   if(ptr == NULL) {
      Print("Fatal Error: Memory allocation failed for ", typename(T));
      ExpertRemove();
   }
   return ptr;
}
