//+------------------------------------------------------------------+
//| StringMap.mqh - Simple string-to-ulong map for EscapeEA          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Key-Value pair for string keys and ulong values                  |
//+------------------------------------------------------------------+
class CStringULongPair
  {
public:
   string            key;
   ulong             value;
   
                     CStringULongPair() {}
                     CStringULongPair(string k, ulong v): key(k), value(v) {}
  };

//+------------------------------------------------------------------+
//| StringMap class for string keys and ulong values                 |
//+------------------------------------------------------------------+
class CStringMap
  {
private:
   CStringULongPair  m_items[];
   
   // Find the index of a key in the array
   int               FindIndex(const string key) const
     {
      for(int i = 0; i < ArraySize(m_items); i++)
         if(m_items[i].key == key)
            return i;
      return -1;
     }
   
public:
   // Constructor
                     CStringMap() { ArrayResize(m_items, 0); }
   
   // Destructor
                    ~CStringMap() { ArrayFree(m_items); }
   
   // Add or update a key-value pair
   void              Add(const string key, const ulong value)
     {
      int index = FindIndex(key);
      if(index >= 0)
         m_items[index].value = value;
      else
        {
         int size = ArraySize(m_items);
         ArrayResize(m_items, size + 1);
         m_items[size] = CStringULongPair(key, value);
        }
     }
   
   // Check if a key exists
   bool              ContainsKey(const string key) const
     {
      return (FindIndex(key) >= 0);
     }
   
   // Try to get a value by key
   bool              TryGetValue(const string key, ulong &value) const
     {
      int index = FindIndex(key);
      if(index >= 0)
        {
         value = m_items[index].value;
         return true;
        }
      return false;
     }
   
   // Remove a key-value pair by key
   bool              Remove(const string key)
     {
      int index = FindIndex(key);
      if(index >= 0)
        {
         int size = ArraySize(m_items);
         if(index < size - 1)
            m_items[index] = m_items[size - 1];
         ArrayResize(m_items, size - 1);
         return true;
        }
      return false;
     }
   
   // Clear all items
   void              Clear()
     {
      ArrayFree(m_items);
      ArrayResize(m_items, 0);
     }
   
   // Get the number of items
   int               Count() const
     {
      return ArraySize(m_items);
     }
  };

