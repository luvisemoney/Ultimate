#property strict
#include "../Include/CMarketModelFeatures.mqh"

input string BuildOutputDirectory="DualEA\\model_build\\universal_h1_logistic_v1";
input string TrainingSymbols="EURUSD,GBPUSD,USDCHF,USDJPY,USDCAD,AUDUSD,NZDUSD,EURGBP,EURJPY,GBPJPY,XAUUSD,XAGUSD,XAUEUR,AUS200,GER40,NAS100,UK100,US30,US500,BRENT,WTI,BTCUSD,ETHUSD";
input int DecisionStrideBars=1;
input int TrainingEpochs=300;
input double LearningRate=0.08;
input double L2Penalty=0.01;
input datetime TrainingStart=D'2024.01.01';
input datetime TrainingEnd=D'2026.07.01';
input datetime ValidationEnd=D'2026.09.01';
input datetime TestEnd=D'2026.10.01';

#define MODEL_FEATURES 12
#define ROW_FEATURES 16
struct STrainingRow
{
   int symbol_index;
   datetime time;
   datetime target_end;
   int direction;
   int split;
   int label;
   double net_return;
   double entry_spread;
   double exit_spread;
   double x[ROW_FEATURES];
};
STrainingRow rows[];
string training_symbols[],rejected_symbols[];
double means[],scales[],weights[],effective_weights[];
double effective_intercept=0;
int symbol_counts[],symbol_positives[];
double intercept=0.0;
int counts[3],positives[3];
bool trained=false;

double Logistic(double score)
{
   if(score>=0.0) return 1.0/(1.0+MathExp(-MathMin(score,700.0)));
   double e=MathExp(MathMax(score,-700.0));
   return e/(1.0+e);
}
double Prediction(const STrainingRow &row)
{
   double score=effective_intercept;
   for(int j=0;j<ROW_FEATURES;j++)
   {
      int feature=j<MODEL_FEATURES ? j : MODEL_FEATURES+4*row.symbol_index+j-MODEL_FEATURES;
      score+=effective_weights[feature]*row.x[j];
   }
   return Logistic(score);
}
void RefreshEffectiveWeights()
{
   effective_intercept=intercept;
   for(int j=0;j<ArraySize(weights);j++)
   {
      effective_weights[j]=weights[j]/scales[j];
      effective_intercept-=weights[j]*means[j]/scales[j];
   }
}
string Number(double value) { return DoubleToString(value,16); }
string VectorJSON(const double &values[])
{
   string result="[";
   for(int j=0;j<ArraySize(values);j++) { if(j) result+=","; result+=Number(values[j]); }
   return result+"]";
}
string SplitName(int split) { return split==0 ? "train" : (split==1 ? "validation" : "test"); }
bool WriteText(string name,string content)
{
   int h=FileOpen(BuildOutputDirectory+"\\"+name,FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   if(h==INVALID_HANDLE) { Print("[MODEL-TRAIN FAIL] Cannot write ",name," error=",GetLastError()); return false; }
   FileWriteString(h,content);
   FileFlush(h);
   FileClose(h);
   return true;
}

bool LoadRealRows()
{
   string requested[];
   int requested_count=StringSplit(TrainingSymbols,',',requested);
   int used=0;
   ArrayResize(rows,0);
   ArrayResize(training_symbols,0);
   ArrayResize(rejected_symbols,0);
   ArrayInitialize(counts,0);
   ArrayInitialize(positives,0);
   for(int symbol_slot=0;symbol_slot<requested_count;symbol_slot++)
   {
      string symbol=requested[symbol_slot];
      StringTrimLeft(symbol);StringTrimRight(symbol);
      if(symbol=="") continue;
      bool duplicate=false;
      for(int k=0;k<ArraySize(training_symbols);k++) if(training_symbols[k]==symbol) duplicate=true;
      if(duplicate) continue;
      MqlRates rates[];
      ArraySetAsSeries(rates,false);
      int n=0;
      if(SymbolSelect(symbol,true))
      {
         // The first cross-symbol request can initiate asynchronous history loading.
         for(int retry=0;retry<12;retry++)
         {
            n=CopyRates(symbol,PERIOD_H1,TrainingStart,TestEnd-1,rates);
            if(n>=1500) break;
            Sleep(250);
         }
      }
      double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      int local_counts[3],local_positive[3];
      ArrayInitialize(local_counts,0);ArrayInitialize(local_positive,0);
      int start=used;
      int accepted_index=ArraySize(training_symbols);
      if(n>=1500 && point>0)
      {
         ArrayResize(rows,used+n*2);
         for(int d=15;d+4<n;d+=DecisionStrideBars)
         {
            datetime decision=rates[d].time,end=rates[d+4].time;
            if(decision<TrainingStart || end>=TestEnd) continue;
            bool continuous=true;
            for(int k=d;k<d+4;k++) if(rates[k+1].time-rates[k].time!=3600) continuous=false;
            if(!continuous || rates[d].open<=0 || rates[d+4].open<=0 || rates[d].spread<0 || rates[d+4].spread<0) continue;
            int split=decision<TrainingEnd ? 0 : (decision<ValidationEnd ? 1 : 2);
            datetime boundary=split==0 ? TrainingEnd : (split==1 ? ValidationEnd : TestEnd);
            if(end>=boundary) continue;
            for(int direction=0;direction<2;direction++)
            {
               double f[];
               if(!MarketModelFeaturesFromRates(rates,d-1,direction,point,decision,f) || ArraySize(f)!=MODEL_FEATURES) continue;
               double entry_bid=rates[d].open,exit_bid=rates[d+4].open;
               double entry_ask=entry_bid+rates[d].spread*point,exit_ask=exit_bid+rates[d+4].spread*point;
               if(entry_ask<=0 || exit_ask<=0) continue;
               double target=direction==0 ? MathLog(exit_bid/entry_ask) : MathLog(entry_bid/exit_ask);
               if(!MathIsValidNumber(target)) continue;
               rows[used].symbol_index=accepted_index;
               rows[used].time=decision;rows[used].target_end=end;
               rows[used].direction=direction;rows[used].split=split;
               rows[used].net_return=target;rows[used].label=target>0 ? 1 : 0;
               rows[used].entry_spread=rates[d].spread;rows[used].exit_spread=rates[d+4].spread;
               for(int j=0;j<MODEL_FEATURES;j++) rows[used].x[j]=f[j];
               rows[used].x[12]=1;
               rows[used].x[13]=f[0]/MathMax(f[4],1e-8);
               rows[used].x[14]=f[1]/MathMax(f[4],1e-8);
               rows[used].x[15]=f[3];
               local_counts[split]++;local_positive[split]+=rows[used].label;
               used++;
            }
         }
      }
      // Eligibility must not select the universe using held-out labels or scores.
      bool eligible=local_counts[0]>=1000 && local_positive[0]>=20 && local_counts[0]-local_positive[0]>=20;
      if(!eligible)
      {
         used=start;ArrayResize(rows,used);
         int rejected=ArraySize(rejected_symbols);ArrayResize(rejected_symbols,rejected+1);rejected_symbols[rejected]=symbol;
         PrintFormat("[MODEL-TRAIN SKIP] %s insufficient real history/class counts: bars=%d train=%d val=%d test=%d",symbol,n,local_counts[0],local_counts[1],local_counts[2]);
         continue;
      }
      ArrayResize(training_symbols,accepted_index+1);training_symbols[accepted_index]=symbol;
      ArrayResize(symbol_counts,(accepted_index+1)*3);ArrayResize(symbol_positives,(accepted_index+1)*3);
      for(int split=0;split<3;split++)
      {
         counts[split]+=local_counts[split];positives[split]+=local_positive[split];
         symbol_counts[accepted_index*3+split]=local_counts[split];symbol_positives[accepted_index*3+split]=local_positive[split];
         PrintFormat("[MODEL-TRAIN DATA] %s %s rows=%d positive=%d negative=%d",symbol,SplitName(split),local_counts[split],local_positive[split],local_counts[split]-local_positive[split]);
      }
      ArrayResize(rows,used);
   }
   string feature_names[];
   if(ArraySize(training_symbols)<2 || !UniversalModelFeatureNames(training_symbols,feature_names)) return false;
   int width=ArraySize(feature_names);
   ArrayResize(means,width);ArrayResize(scales,width);ArrayResize(weights,width);ArrayResize(effective_weights,width);
   return true;
}
void FitTrainingOnly()
{
   int width=ArraySize(weights);
   ArrayInitialize(means,0.0);ArrayInitialize(scales,0.0);ArrayInitialize(weights,0.0);
   for(int i=0;i<ArraySize(rows);i++)
      if(rows[i].split==0)
         for(int j=0;j<ROW_FEATURES;j++)
         {
            int f=j<MODEL_FEATURES ? j : MODEL_FEATURES+4*rows[i].symbol_index+j-MODEL_FEATURES;
            means[f]+=rows[i].x[j]/counts[0];
            scales[f]+=rows[i].x[j]*rows[i].x[j]/counts[0];
         }
   // E[x^2]-E[x]^2 includes the inactive per-symbol zeros exactly.
   for(int j=0;j<width;j++) {scales[j]=MathSqrt(MathMax(0.0,scales[j]-means[j]*means[j]));if(scales[j]<1e-12)scales[j]=1.0;}
   double prior=(double)positives[0]/counts[0];
   intercept=MathLog(prior/(1.0-prior));
   double gradient[];ArrayResize(gradient,width);
   for(int epoch=0;epoch<TrainingEpochs;epoch++)
   {
      RefreshEffectiveWeights();
      ArrayInitialize(gradient,0.0);
      double bias_gradient=0.0;
      for(int i=0;i<ArraySize(rows);i++)
      {
         if(rows[i].split!=0) continue;
         double error=Prediction(rows[i])-rows[i].label;
         bias_gradient+=error/counts[0];
         for(int j=0;j<ROW_FEATURES;j++)
         {
            int f=j<MODEL_FEATURES ? j : MODEL_FEATURES+4*rows[i].symbol_index+j-MODEL_FEATURES;
            gradient[f]+=error*(rows[i].x[j]/scales[f])/counts[0];
         }
      }
      for(int j=0;j<width;j++)
      {
         gradient[j]-=(means[j]/scales[j])*bias_gradient;
         weights[j]-=LearningRate*(gradient[j]+L2Penalty*weights[j]);
      }
      intercept-=LearningRate*bias_gradient;
      if(epoch%50==0) PrintFormat("[MODEL-TRAIN FIT] epoch=%d/%d real_train_rows=%d width=%d",epoch,TrainingEpochs,counts[0],width);
   }
   RefreshEffectiveWeights();
}
string MetricsJSON(int split,int symbol_index=-1)
{
   double ranked[][2];
   int expected_count=symbol_index<0 ? counts[split] : symbol_counts[symbol_index*3+split];
   int expected_positive=symbol_index<0 ? positives[split] : symbol_positives[symbol_index*3+split];
   if(expected_count==0)
      return "{\"rows\":0,\"positive\":0,\"negative\":0,\"auc\":null,\"log_loss\":null,\"constant_train_prior_log_loss\":null,\"brier_score\":null,\"accuracy\":null}";
   ArrayResize(ranked,expected_count);
   double loss=0,brier=0,baseline_loss=0,baseline_brier=0;
   int correct=0,slot=0;
   double prior=(double)positives[0]/counts[0];
   for(int i=0;i<ArraySize(rows);i++)
   {
      if(rows[i].split!=split || (symbol_index>=0 && rows[i].symbol_index!=symbol_index)) continue;
      double p=Prediction(rows[i]);
      p=MathMax(1e-12,MathMin(1.0-1e-12,p));
      int y=rows[i].label;
      loss-=y*MathLog(p)+(1-y)*MathLog(1-p);
      brier+=MathPow(p-y,2);
      baseline_loss-=y*MathLog(prior)+(1-y)*MathLog(1-prior);
      baseline_brier+=MathPow(prior-y,2);
      if((p>=0.5 ? 1 : 0)==y) correct++;
      ranked[slot][0]=p;
      ranked[slot][1]=y;
      slot++;
   }
   ArraySort(ranked);
   double positive_rank_sum=0;
   int begin=0;
   while(begin<slot)
   {
      int end=begin+1;
      while(end<slot && ranked[end][0]==ranked[begin][0]) end++;
      double average_rank=((begin+1)+end)*0.5;
      for(int k=begin;k<end;k++) if(ranked[k][1]>0.5) positive_rank_sum+=average_rank;
      begin=end;
   }
   double pos=expected_positive,neg=expected_count-expected_positive;
   double auc=pos>0 && neg>0 ? (positive_rank_sum-pos*(pos+1)/2)/(pos*neg) : 0;
   string auc_json=pos>0 && neg>0 ? Number(auc) : "null";
   PrintFormat("[MODEL-TRAIN METRICS] %s AUC=%s logloss=%.6f baseline=%.6f accuracy=%.6f",SplitName(split),auc_json,loss/slot,baseline_loss/slot,(double)correct/slot);
   return "{\"rows\":"+IntegerToString(slot)+",\"positive\":"+IntegerToString(expected_positive)+",\"negative\":"+IntegerToString(expected_count-expected_positive)+",\"auc\":"+auc_json+",\"log_loss\":"+Number(loss/slot)+",\"constant_train_prior_log_loss\":"+Number(baseline_loss/slot)+",\"constant_train_prior_brier\":"+Number(baseline_brier/slot)+",\"constant_train_prior_accuracy\":"+Number(prior>=0.5 ? pos/slot : neg/slot)+",\"brier_score\":"+Number(brier/slot)+",\"accuracy\":"+Number((double)correct/slot)+"}";
}

string StringArrayJSON(const string &values[])
{
   string output="[";
   for(int j=0;j<ArraySize(values);j++){if(j)output+=",";output+="\""+values[j]+"\"";}
   return output+"]";
}
bool SaveArtifacts()
{
   FolderCreate("DualEA");FolderCreate("DualEA\\model_build");FolderCreate(BuildOutputDirectory);
   string names[],base_names[];
   if(!UniversalModelFeatureNames(training_symbols,names)) return false;
   MarketModelFeatureNames(base_names);
   string joined_names="",joined_symbols="";
   for(int j=0;j<ArraySize(names);j++){if(j)joined_names+="|";joined_names+=names[j];}
   for(int j=0;j<ArraySize(training_symbols);j++){if(j)joined_symbols+="|";joined_symbols+=training_symbols[j];}
   string model="{\"schema\":\"market_universal_v1\",\"symbol\":\"*\",\"supported_symbols\":"+StringArrayJSON(training_symbols)+",\"rejected_symbols\":"+StringArrayJSON(rejected_symbols)+",\"timeframe\":16385,\"horizon_bars\":4,\"feature_names\":"+StringArrayJSON(names)+",\"weights\":"+VectorJSON(weights)+",\"intercept\":"+Number(intercept)+",\"scaler_mean\":"+VectorJSON(means)+",\"scaler_scale\":"+VectorJSON(scales)+",\"training_start\":\""+TimeToString(TrainingStart,TIME_DATE)+"\",\"training_end\":\""+TimeToString(TrainingEnd,TIME_DATE)+"\",\"validation_end\":\""+TimeToString(ValidationEnd,TIME_DATE)+"\",\"test_end\":\""+TimeToString(TestEnd,TIME_DATE)+"\",\"target\":\"positive_side_aware_four_bar_log_return_after_recorded_spread\",\"commission\":0,\"slippage\":0,\"decision_stride_bars\":"+IntegerToString(DecisionStrideBars)+",\"epochs\":"+IntegerToString(TrainingEpochs)+",\"learning_rate\":"+Number(LearningRate)+",\"l2\":"+Number(L2Penalty)+"}";
   if(!WriteText("model_data.json",model)) return false;
   string metrics="{\"train\":"+MetricsJSON(0)+",\"validation\":"+MetricsJSON(1)+",\"test\":"+MetricsJSON(2)+",\"per_symbol\":{";
   for(int s=0;s<ArraySize(training_symbols);s++)
   {
      if(s)metrics+=",";
      metrics+="\""+training_symbols[s]+"\":{\"train\":"+MetricsJSON(0,s)+",\"validation\":"+MetricsJSON(1,s)+",\"test\":"+MetricsJSON(2,s)+"}";
   }
   metrics+="},\"selection\":\"fixed_hyperparameters_no_validation_or_test_selection\",\"training_data\":\"broker_H1_OHLC_and_recorded_spread\",\"purge\":\"target_end_before_split_boundary\",\"supported_symbols\":"+StringArrayJSON(training_symbols)+",\"rejected_symbols\":"+StringArrayJSON(rejected_symbols)+"}";
   if(!WriteText("metrics.json",metrics)) return false;
   string ini="version=1\nfeature_contract=market_universal_v1\ntrained_symbol=*\nsupported_symbols="+joined_symbols+"\ntrained_timeframe=16385\nprediction_horizon_bars=4\ntraining_start="+TimeToString(TrainingStart,TIME_DATE)+"\ntraining_end="+TimeToString(TrainingEnd,TIME_DATE)+"\nvalidation_end="+TimeToString(ValidationEnd,TIME_DATE)+"\ntest_end="+TimeToString(TestEnd,TIME_DATE)+"\nfeature_count="+IntegerToString(ArraySize(names))+"\nfeature_names="+joined_names+"\nscaler_mean=";
   for(int j=0;j<ArraySize(means);j++){if(j)ini+="|";ini+=Number(means[j]);}
   ini+="\nscaler_scale=";
   for(int j=0;j<ArraySize(scales);j++){if(j)ini+="|";ini+=Number(scales[j]);}
   ini+="\ninput_name=model_input\noutput_name=probability\nlabel_mode=future_side_aware_return\n";
   if(!WriteText("onnx_config.ini",ini)) return false;
   int dataset=FileOpen(BuildOutputDirectory+"\\dataset.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   int parity=FileOpen(BuildOutputDirectory+"\\parity_samples.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(dataset==INVALID_HANDLE || parity==INVALID_HANDLE){if(dataset!=INVALID_HANDLE)FileClose(dataset);if(parity!=INVALID_HANDLE)FileClose(parity);return false;}
   string header="decision_time,target_end,split,symbol,direction,label,net_log_return,entry_spread_points,exit_spread_points";
   for(int j=0;j<MODEL_FEATURES;j++)header+=","+base_names[j];
   header+=",active_symbol_flag,active_ret1,active_ret3,active_zscore";
   FileWriteString(dataset,header+"\r\n");
   string parity_header="split,decision_time,symbol,direction,expected_probability";
   for(int j=0;j<ArraySize(names);j++)parity_header+=","+names[j];
   FileWriteString(parity,parity_header+"\r\n");
   int selected[];ArrayResize(selected,ArraySize(training_symbols)*3);ArrayInitialize(selected,0);
   for(int i=0;i<ArraySize(rows);i++)
   {
      string symbol=training_symbols[rows[i].symbol_index];
      string line=TimeToString(rows[i].time,TIME_DATE|TIME_MINUTES)+","+TimeToString(rows[i].target_end,TIME_DATE|TIME_MINUTES)+","+SplitName(rows[i].split)+","+symbol+","+IntegerToString(rows[i].direction)+","+IntegerToString(rows[i].label)+","+Number(rows[i].net_return)+","+Number(rows[i].entry_spread)+","+Number(rows[i].exit_spread);
      for(int j=0;j<ROW_FEATURES;j++)line+=","+Number(rows[i].x[j]);
      FileWriteString(dataset,line+"\r\n");
      int group=rows[i].symbol_index*3+rows[i].split;
      if(selected[group]<8)
      {
         string sample=SplitName(rows[i].split)+","+TimeToString(rows[i].time,TIME_DATE|TIME_MINUTES)+","+symbol+","+IntegerToString(rows[i].direction)+","+Number(Prediction(rows[i]));
         for(int j=0;j<ArraySize(names);j++)
         {
            double value=0;
            if(j<MODEL_FEATURES)value=rows[i].x[j];
            else if((j-MODEL_FEATURES)/4==rows[i].symbol_index)value=rows[i].x[MODEL_FEATURES+(j-MODEL_FEATURES)%4];
            sample+=","+Number(value);
         }
         FileWriteString(parity,sample+"\r\n");selected[group]++;
      }
   }
   FileFlush(dataset);FileClose(dataset);FileFlush(parity);FileClose(parity);
   return true;
}
int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER) || _Period!=PERIOD_H1) {Print("[MODEL-TRAIN FAIL] Run only in H1 Strategy Tester.");return INIT_FAILED;}
   if(!(TrainingStart<TrainingEnd && TrainingEnd<ValidationEnd && ValidationEnd<TestEnd && TestEnd<=TimeCurrent()) ||
      TrainingStart%86400!=0 || TrainingEnd%86400!=0 || ValidationEnd%86400!=0 || TestEnd%86400!=0)
   {
      Print("[MODEL-TRAIN FAIL] Date boundaries must be ordered midnight dates, with TestEnd no later than tester time.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(DecisionStrideBars<1 || DecisionStrideBars>24 || TrainingEpochs<1 || TrainingEpochs>2000 ||
      !MathIsValidNumber(LearningRate) || !MathIsValidNumber(L2Penalty) ||
      LearningRate<=0 || LearningRate>1 || L2Penalty<0) return INIT_PARAMETERS_INCORRECT;
   if(!LoadRealRows()) {Print("[MODEL-TRAIN FAIL] Real history/class-count requirements were not met.");return INIT_FAILED;}
   FitTrainingOnly();
   if(!MathIsValidNumber(intercept)) return INIT_FAILED;
   for(int j=0;j<ArraySize(weights);j++)
      if(!MathIsValidNumber(weights[j]) || !MathIsValidNumber(means[j]) || !MathIsValidNumber(scales[j]) || scales[j]<=0)
      {
         Print("[MODEL-TRAIN FAIL] Invalid fitted coefficient/scaler at ",j);
         return INIT_FAILED;
      }
   if(!SaveArtifacts()) return INIT_FAILED;
   trained=true;
   PrintFormat("[MODEL-TRAIN RESULT] rows=%d train=%d validation=%d test=%d output=%s",ArraySize(rows),counts[0],counts[1],counts[2],BuildOutputDirectory);
   return INIT_SUCCEEDED;
}
void OnTick() {}
double OnTester() { return trained ? ArraySize(rows) : -1; }
