//+------------------------------------------------------------------+
//| HashMap.mqh - Simple HashMap implementation for EscapeEA         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, EscapeEA"
#property link      "https://www.escapeea.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Template class for key-value pairs                               |
//+------------------------------------------------------------------+
template<typename TKey,typename TValue>
class CKeyValuePair
  {
public:
   TKey              key;
   TValue            value;
   
                     CKeyValuePair() {}
                     CKeyValuePair(TKey k, TValue v): key(k), value(v) {}
  };

//+------------------------------------------------------------------+
//| HashMap class                                                    |
//+------------------------------------------------------------------+
template<typename TKey,typename TValue>
class CHashMap
  {
private:
   CKeyValuePair<TKey,TValue> m_items[];
   
   // Find the index of a key in the array
   int               FindIndex(TKey key) const
     {
      for(int i = 0; i < ArraySize(m_items); i++)
         if(m_items[i].key == key)
            return i;
      return -1;
     }
   
public:
   // Constructor
                     CHashMap() { ArrayResize(m_items, 0); }
   
   // Destructor
                    ~CHashMap() { ArrayFree(m_items); }
   
   // Add or update a key-value pair
   void              Add(TKey key, TValue value)
     {
      int index = FindIndex(key);
      if(index >= 0)
         m_items[index].value = value;
      else
        {
         int size = ArraySize(m_items);
         ArrayResize(m_items, size + 1);
         m_items[size] = CKeyValuePair<TKey,TValue>(key, value);
        }
     }
   
   // Check if a key exists
   bool              ContainsKey(TKey key) const
     {
      return (FindIndex(key) >= 0);
     }
   
   // Try to get a value by key
   bool              TryGetValue(TKey key, TValue &value) const
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
   bool              Remove(TKey key)
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

//+------------------------------------------------------------------+
//| Specialization for string keys                                   |
//+------------------------------------------------------------------+
template<typename TValue>
class CHashMap<string,TValue> : public CHashMap<ulong,TValue>
  {
private:
   static ulong      StringHash(const string str)
     {
      ulong hash = 5381;
      int len = StringLen(str);
      for(int i = 0; i < len; i++)
         hash = ((hash << 5) + hash) + str[i];
      return hash;
     }
   
public:
   // Add or update a key-value pair with string key
   void              Add(string key, TValue value)
     {
      CHashMap<ulong,TValue>::Add(StringHash(key), value);
     }
   
   // Check if a string key exists
   bool              ContainsKey(string key) const
     {
      return CHashMap<ulong,TValue>::ContainsKey(StringHash(key));
     }
   
   // Try to get a value by string key
   bool              TryGetValue(string key, TValue &value) const
     {
      return CHashMap<ulong,TValue>::TryGetValue(StringHash(key), value);
     }
   
   // Remove a key-value pair by string key
   bool              Remove(string key)
     {
      return CHashMap<ulong,TValue>::Remove(StringHash(key));
     }
  };
