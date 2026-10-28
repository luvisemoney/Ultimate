#property strict
#include "../Include/CMarketModelFeatures.mqh"
int g_feature_failures=0,g_feature_checks=0;
void FeatureCheck(bool passed,string label)
{
   g_feature_checks++;
   if(!passed) {g_feature_failures++;Print("[MARKET-FEATURE FAIL] ",label);}
}
int OnInit()
{
   // Synthetic values exist only to test the feature contract, never training.
   MqlRates rates[];
   ArrayResize(rates,40);
   ArraySetAsSeries(rates,false);
   for(int i=0;i<40;i++)
   {
      ZeroMemory(rates[i]);
      rates[i].time=D'2025.01.01 00:00:00'+i*3600;
      rates[i].close=0.8+0.0002*i+0.0001*MathSin(i);
      rates[i].open=rates[i].close-0.00005;
      rates[i].high=rates[i].close+0.0002;
      rates[i].low=rates[i].open-0.0002;
      rates[i].spread=7;
   }
   datetime decision=rates[21].time;
   double buy[],sell[],after[];
   FeatureCheck(MarketModelFeaturesFromRates(rates,20,0,0.00001,decision,buy),"BUY features available");
   FeatureCheck(MarketModelFeaturesFromRates(rates,20,1,0.00001,decision,sell),"SELL features available");
   FeatureCheck(ArraySize(buy)==12 && ArraySize(sell)==12,"Twelve-feature schema");
   string names[];
   MarketModelFeatureNames(names);
   FeatureCheck(ArraySize(names)==12 && names[0]=="mm_signed_logret1" && names[11]=="mm_atr14","Stable feature names/order");
   if(ArraySize(buy)==12 && ArraySize(sell)==12)
   {
      for(int i=0;i<12;i++)
      {
         bool signed_feature=(i<=3 || i==6 || i==10);
         FeatureCheck(MathAbs(sell[i]-(signed_feature ? -buy[i] : buy[i]))<1e-12,"Direction symmetry feature "+IntegerToString(i));
      }
      FeatureCheck(MathAbs(buy[0]-MathLog(rates[20].close/rates[19].close))<1e-12,"Return references completed bars");
      FeatureCheck(MathAbs(buy[7]-7*0.00001/rates[20].close)<1e-12,"Recorded spread normalization");
      for(int i=21;i<40;i++) {rates[i].close=9999;rates[i].open=1;rates[i].high=10000;rates[i].low=0.1;}
      FeatureCheck(MarketModelFeaturesFromRates(rates,20,0,0.00001,decision,after),"Future/current values ignored");
      bool identical=ArraySize(after)==12;
      for(int i=0;i<MathMin(ArraySize(after),12);i++) identical=identical && MathAbs(after[i]-buy[i])<1e-12;
      FeatureCheck(identical,"Future/current mutations do not change features");
   }
   FeatureCheck(!MarketModelFeaturesFromRates(rates,13,0,0.00001,decision,after),"Insufficient warmup rejected");
   FeatureCheck(!MarketModelFeaturesFromRates(rates,20,2,0.00001,decision,after),"Invalid direction rejected");
   FeatureCheck(!MarketModelFeaturesFromRates(rates,20,0,0.00001,rates[20].time,after),"Unclosed observation rejected");
   FeatureCheck(!MarketModelFeaturesFromRates(rates,20,0,0.00001,rates[20].time+1800,after),"Partially completed H1 observation rejected");
   FeatureCheck(!MarketModelFeaturesFromRates(rates,20,0,0.0,decision,after),"Invalid point rejected");
   string symbols[]={"USDCHF","XAUUSD#"};
   string universal_names[];
   double expanded[],reversed[];
   FeatureCheck(UniversalModelFeatureNames(symbols,universal_names),"Universal schema available");
   FeatureCheck(ArraySize(universal_names)==20 && universal_names[12]=="sym_usdchf_flag" && universal_names[19]=="sym_xauusd__zscore","Universal dimension and safe names");
   FeatureCheck(ExpandUniversalModelFeatures(buy,"USDCHF",symbols,expanded),"Known symbol expansion");
   FeatureCheck(ArraySize(expanded)==20 && expanded[12]==1.0 && expanded[16]==0.0,"Symbol one-hot identity");
   FeatureCheck(ArraySize(expanded)==20 && MathAbs(expanded[13]-buy[0]/MathMax(buy[4],1e-8))<1e-10,"Symbol-specific return normalization");
   FeatureCheck(ExpandUniversalModelFeatures(sell,"USDCHF",symbols,reversed) && MathAbs(expanded[13]+reversed[13])<1e-10 && MathAbs(expanded[15]+reversed[15])<1e-10,"Universal directional features reverse");
   FeatureCheck(ExpandUniversalModelFeatures(buy,"XAUUSD#",symbols,expanded) && expanded[12]==0.0 && expanded[16]==1.0,"Second broker symbol activates own block");
   FeatureCheck(!ExpandUniversalModelFeatures(buy,"EURUSD",symbols,expanded) && ArraySize(expanded)==0,"Unknown symbol rejected");
   FeatureCheck(!ExpandUniversalModelFeatures(buy,"XAUUSD!",symbols,expanded),"Unknown punctuation alias rejected");
   string duplicates[]={"XAUUSD#","XAUUSD!"};
   FeatureCheck(!UniversalModelFeatureNames(duplicates,universal_names) && ArraySize(universal_names)==0,"Colliding normalized symbol names rejected");
   FeatureCheck(!ExpandUniversalModelFeatures(buy,"XAUUSD#",duplicates,expanded),"Duplicate symbol schema rejected at inference");
   rates[19].close=0;
   FeatureCheck(!MarketModelFeaturesFromRates(rates,20,0,0.00001,decision,after),"Invalid history rejected");
   ArraySetAsSeries(rates,true);
   FeatureCheck(!MarketModelFeaturesFromRates(rates,20,0,0.00001,decision,after),"Reversed array contract rejected");
   PrintFormat("[MARKET-FEATURE RESULT] checks=%d failures=%d",g_feature_checks,g_feature_failures);
   return g_feature_failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick() {}
double OnTester() {return g_feature_failures==0 ? g_feature_checks : -g_feature_failures;}
