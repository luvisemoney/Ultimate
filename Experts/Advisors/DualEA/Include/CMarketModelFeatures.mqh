#ifndef DUALEA_MARKET_MODEL_FEATURES_MQH
#define DUALEA_MARKET_MODEL_FEATURES_MQH

// Version 1: completed-bar market features, oldest bar first. No indicator
// state, gate outcomes, strategy decisions, or future observations are inputs.
#define MARKET_MODEL_FEATURE_COUNT 12

void MarketModelFeatureNames(string &names[])
{
   ArrayResize(names,MARKET_MODEL_FEATURE_COUNT);
   names[0]="mm_signed_logret1";
   names[1]="mm_signed_logret3";
   names[2]="mm_signed_logret12";
   names[3]="mm_signed_zscore12";
   names[4]="mm_return_std12";
   names[5]="mm_range";
   names[6]="mm_signed_body";
   names[7]="mm_spread";
   names[8]="mm_hour_sin";
   names[9]="mm_hour_cos";
   names[10]="mm_direction";
   names[11]="mm_atr14";
}

bool MarketModelFeaturesFromRates(const MqlRates &rates[],const int closed_index,
                                 const int direction,const double point,
                                 const datetime decision_time,double &features[])
{
   ArrayResize(features,0);
   if(ArrayGetAsSeries(rates) || closed_index<14 || closed_index>=ArraySize(rates) ||
      (direction!=0 && direction!=1) || !MathIsValidNumber(point) || point<=0.0 ||
      decision_time<rates[closed_index].time+PeriodSeconds(PERIOD_H1))
      return false;

   // Only this explicit backward window is read. Later array entries may
   // contain future prices during training and must never affect features.
   for(int i=closed_index-14;i<=closed_index;i++)
   {
      if(rates[i].time<=0 || (i>closed_index-14 && rates[i].time<=rates[i-1].time) ||
         !MathIsValidNumber(rates[i].open) || !MathIsValidNumber(rates[i].high) ||
         !MathIsValidNumber(rates[i].low) || !MathIsValidNumber(rates[i].close) ||
         rates[i].open<=0.0 || rates[i].low<=0.0 || rates[i].close<=0.0 ||
         rates[i].high<rates[i].low || rates[i].high<MathMax(rates[i].open,rates[i].close) ||
         rates[i].low>MathMin(rates[i].open,rates[i].close) || rates[i].spread<0)
         return false;
   }

   double side=direction==0 ? 1.0 : -1.0;
   double last=rates[closed_index].close;
   double mean=0.0,return_mean=0.0;
   double returns[12];
   for(int i=0;i<12;i++)
   {
      int index=closed_index-i;
      mean+=rates[index].close/12.0;
      returns[i]=MathLog(rates[index].close/rates[index-1].close);
      return_mean+=returns[i]/12.0;
   }
   double price_var=0.0,return_var=0.0;
   for(int i=0;i<12;i++)
   {
      double delta=rates[closed_index-i].close-mean;
      price_var+=delta*delta/12.0;
      double return_delta=returns[i]-return_mean;
      return_var+=return_delta*return_delta/12.0;
   }
   double atr=0.0;
   for(int i=0;i<14;i++)
   {
      int index=closed_index-i;
      double previous=rates[index-1].close;
      double tr=MathMax(rates[index].high-rates[index].low,
                        MathMax(MathAbs(rates[index].high-previous),MathAbs(rates[index].low-previous)));
      atr+=tr/14.0;
   }
   MqlDateTime dt;
   if(!TimeToStruct(decision_time,dt)) return false;
   double hour_angle=2.0*3.14159265358979323846*dt.hour/24.0;
   ArrayResize(features,MARKET_MODEL_FEATURE_COUNT);
   features[0]=side*returns[0];
   features[1]=side*MathLog(last/rates[closed_index-3].close);
   features[2]=side*MathLog(last/rates[closed_index-12].close);
   features[3]=price_var>0.0 ? side*(last-mean)/MathSqrt(price_var) : 0.0;
   features[4]=MathSqrt(return_var);
   features[5]=(rates[closed_index].high-rates[closed_index].low)/last;
   features[6]=side*(last-rates[closed_index].open)/last;
   features[7]=(double)rates[closed_index].spread*point/last;
   features[8]=MathSin(hour_angle);
   features[9]=MathCos(hour_angle);
   features[10]=side;
   features[11]=atr/last;
   for(int i=0;i<MARKET_MODEL_FEATURE_COUNT;i++)
      if(!MathIsValidNumber(features[i])) { ArrayResize(features,0); return false; }
   return true;
}

bool BuildMarketModelFeatures(const string symbol,const ENUM_TIMEFRAMES tf,
                              const datetime decision_time,const int direction,
                              double &features[])
{
   ArrayResize(features,0);
   int seconds=PeriodSeconds(tf);
   if(seconds<=0 || decision_time<=0) return false;
   int decision_shift=iBarShift(symbol,tf,decision_time,false);
   if(decision_shift<0) return false;
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   int copied=CopyRates(symbol,tf,decision_shift+1,64,rates);
   if(copied<15) return false;
   int last=copied-1;
   if(rates[last].time+seconds>decision_time) return false;
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   return MarketModelFeaturesFromRates(rates,last,direction,point,decision_time,features);
}

// Broker symbols retain their identity when matching the active symbol. Only
// feature identifiers are normalized; punctuation is never silently stripped
// from a broker symbol to claim support for a different instrument.
string NormalizeUniversalModelSymbol(string symbol)
{
   StringToLower(symbol);
   string normalized="";
   for(int i=0;i<StringLen(symbol);i++)
   {
      ushort character=StringGetCharacter(symbol,i);
      if((character>='a' && character<='z') || (character>='0' && character<='9'))
         normalized+=ShortToString(character);
      else
         normalized+="_";
   }
   return normalized;
}

bool ValidateUniversalModelSymbols(const string &symbols[])
{
   int count=ArraySize(symbols);
   if(count<=0) return false;
   for(int i=0;i<count;i++)
   {
      if(symbols[i]=="") return false;
      string normalized=NormalizeUniversalModelSymbol(symbols[i]);
      for(int j=0;j<i;j++)
         if(normalized==NormalizeUniversalModelSymbol(symbols[j])) return false;
   }
   return true;
}

bool UniversalModelFeatureNames(const string &symbols[],string &names[])
{
   ArrayResize(names,0);
   if(!ValidateUniversalModelSymbols(symbols)) return false;
   MarketModelFeatureNames(names);
   int count=ArraySize(symbols);
   ArrayResize(names,MARKET_MODEL_FEATURE_COUNT+4*count);
   for(int i=0;i<count;i++)
   {
      int offset=MARKET_MODEL_FEATURE_COUNT+4*i;
      string prefix="sym_"+NormalizeUniversalModelSymbol(symbols[i]);
      names[offset]=prefix+"_flag";
      names[offset+1]=prefix+"_ret1";
      names[offset+2]=prefix+"_ret3";
      names[offset+3]=prefix+"_zscore";
   }
   return true;
}

bool ExpandUniversalModelFeatures(const double &base[],const string symbol,
                                  const string &symbols[],double &features[])
{
   ArrayResize(features,0);
   if(ArraySize(base)!=MARKET_MODEL_FEATURE_COUNT || !ValidateUniversalModelSymbols(symbols))
      return false;
   int active=-1;
   for(int i=0;i<ArraySize(symbols);i++)
      if(StringCompare(symbol,symbols[i],false)==0) {active=i;break;}
   if(active<0) return false;
   for(int i=0;i<MARKET_MODEL_FEATURE_COUNT;i++)
      if(!MathIsValidNumber(base[i])) return false;
   if(base[4]<0.0) return false;
   int count=MARKET_MODEL_FEATURE_COUNT+4*ArraySize(symbols);
   ArrayResize(features,count);
   ArrayInitialize(features,0.0);
   for(int i=0;i<MARKET_MODEL_FEATURE_COUNT;i++) features[i]=base[i];
   int offset=MARKET_MODEL_FEATURE_COUNT+4*active;
   double scale=MathMax(base[4],1e-8);
   features[offset]=1.0;
   features[offset+1]=base[0]/scale;
   features[offset+2]=base[1]/scale;
   features[offset+3]=base[3];
   for(int i=0;i<count;i++)
      if(!MathIsValidNumber(features[i])) {ArrayResize(features,0);return false;}
   return true;
}

bool UniversalModelFeaturesFromRates(const MqlRates &rates[],const int closed_index,
                                     const int direction,const double point,
                                     const datetime decision_time,const string symbol,
                                     const string &symbols[],double &features[])
{
   double base[];
   if(!MarketModelFeaturesFromRates(rates,closed_index,direction,point,decision_time,base))
   {
      ArrayResize(features,0);
      return false;
   }
   return ExpandUniversalModelFeatures(base,symbol,symbols,features);
}
#endif
