#property strict
#resource "ModelResources\\forexfactory-news.tsv" as uchar CapturedHeadlines[]
#include "../Include/CNewsSentimentStore.mqh"
int checks=0,failures=0;
void Check(bool ok,string label){checks++;if(!ok){failures++;Print("[FF-NATIVE FAIL] ",label);}}
int OnInit()
{
   int file=FileOpen("ff-headlines.tsv",FILE_WRITE|FILE_BIN);
   if(file==INVALID_HANDLE) return INIT_FAILED;
   FileWriteArray(file,CapturedHeadlines);FileClose(file);
   CNewsSentimentStore store;
   Check(store.Load("ff-headlines.tsv"),"Real browser-collected snapshot loads in native EA reader");
   file=FileOpen("ff-headlines.tsv",FILE_READ|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   FileReadString(file);
   int rows=0;string first[];
   while(!FileIsEnding(file))
   {
      string line=FileReadString(file);
      if(line=="") continue;
      string fields[];
      if(StringSplit(line,'\t',fields)!=10){failures++;break;}
      if(rows==0) ArrayCopy(first,fields);
      rows++;
   }
   FileClose(file);
   Check(rows>0 && store.Count()==rows,"Every published context row survived native schema validation");
   if(rows>0)
   {
      datetime observed=(datetime)StringToInteger(first[1]);
      double score;int evidence;string headline;
      string target=first[4];
      bool asset=StringFind(target,"SYMBOL:")==0;
      string symbol=asset?StringSubstr(target,7):"TEST";
      Check(store.Score(asset?"":target,"XXX",symbol,observed,score,evidence,headline),"Real headline context is available after observation");
      Check(MathIsValidNumber(score) && score>=-1 && score<=1,"Native context remains bounded");
      Check(!store.Score(asset?"":target,"XXX",symbol,observed-1,score,evidence,headline),"Collected headlines cannot leak before observation");
   }
   PrintFormat("[FF-NATIVE RESULT] checks=%d failures=%d rows=%d",checks,failures,rows);
   return failures==0?INIT_SUCCEEDED:INIT_FAILED;
}
void OnTick(){}
double OnTester(){return failures==0?checks:-failures;}
