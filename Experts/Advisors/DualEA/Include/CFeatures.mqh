//+------------------------------------------------------------------+
//| CFeatures.mqh - Feature Extraction Class                           |
//| Simple feature container for gate system                         |
//+------------------------------------------------------------------+
#ifndef CFEATURES_MQH
#define CFEATURES_MQH

//+------------------------------------------------------------------+
//| Features Class                                                     |
//+------------------------------------------------------------------+
class CFeatures
{
public:
   double   values[];
   string   names[];
   int      count;
   datetime timestamp;
   string   symbol;
   int      timeframe;
   
   CFeatures() 
   {
      count = 0;
      timestamp = 0;
      symbol = "";
      timeframe = 0;
   }
   
   void Init(int size, const string &sym, int tf)
   {
      ArrayResize(values, size);
      ArrayResize(names, size);
      ArrayInitialize(values, 0.0);
      count = 0;
      timestamp = TimeCurrent();
      symbol = sym;
      timeframe = tf;
   }
   
   void Add(const string &name, double value)
   {
      if(count < ArraySize(values))
      {
         names[count] = name;
         values[count] = value;
         count++;
      }
   }
   
   void Reset()
   {
      count = 0;
      ArrayInitialize(values, 0.0);
   }
   
   double Get(const string &name) const
   {
      for(int i = 0; i < count; i++)
      {
         if(names[i] == name)
            return values[i];
      }
      return 0.0;
   }
};

#endif // CFEATURES_MQH
