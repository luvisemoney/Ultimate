#ifndef DUALEA_NEWS_SENTIMENT_STORE
#define DUALEA_NEWS_SENTIMENT_STORE
#include "RuntimeStorage.mqh"

struct SHeadlineContext
{
   string id,target,url,headline,method;
   datetime observed,published,expires;
   double score;
   int impact;
};

// External headline context is separate from scheduled blackouts and ONNX.
class CNewsSentimentStore
{
private:
   SHeadlineContext m_rows[];
public:
   int Count() const {return ArraySize(m_rows);}
   bool Load(const string path,const int common_flags=0)
   {
      int file=FileOpen(path,FILE_READ|FILE_TXT|FILE_ANSI|common_flags,0,CP_UTF8);
      if(file==INVALID_HANDLE) return false;
      if(FileSize(file)>2097152){FileClose(file);return false;}
      string schema_header=FileReadString(file);
      if(StringLen(schema_header)>0 && StringGetCharacter(schema_header,0)==0xFEFF) schema_header=StringSubstr(schema_header,1);
      if(schema_header!="id\tobserved_utc\tpublished_utc\texpires_utc\ttarget\tscore\timpact\turl\theadline\tmethod")
      {FileClose(file);return false;}
      SHeadlineContext candidate[];
      bool valid=true;
      while(!FileIsEnding(file))
      {
         string line=FileReadString(file);
         if(line=="") continue;
         string fields[];
         if(StringSplit(line,'\t',fields)!=10 || ArraySize(candidate)>=1000){valid=false;break;}
         // Reject malformed numeric strings rather than coercing them to neutral.
         bool numeric=true;
         for(int c=1;c<=6;c++)
         {
            if(c==4) continue;
            if(fields[c]==""){numeric=false;break;}
            int digits=0,dots=0;
            for(int j=0;j<StringLen(fields[c]);j++)
            {
               ushort ch=StringGetCharacter(fields[c],j);
               if(ch>='0' && ch<='9'){digits++;continue;}
               if(c==5 && ch=='-' && j==0) continue;
               if(c==5 && ch=='.'){dots++;continue;}
               numeric=false;
            }
            if(digits==0 || dots>1) numeric=false;
         }
         SHeadlineContext row;
         row.id=fields[0];row.observed=(datetime)StringToInteger(fields[1]);
         row.published=(datetime)StringToInteger(fields[2]);row.expires=(datetime)StringToInteger(fields[3]);
         row.target=fields[4];StringToUpper(row.target);row.score=StringToDouble(fields[5]);
         row.impact=(int)StringToInteger(fields[6]);row.url=fields[7];row.headline=fields[8];row.method=fields[9];
         if(!numeric || row.id=="" || row.target=="" || row.published<=0 || row.observed<row.published ||
            row.expires<=row.observed || row.expires-row.published>86400 || !MathIsValidNumber(row.score) ||
            MathAbs(row.score)>1 || row.impact<0 || row.impact>3 || StringFind(row.url,"https://")!=0 ||
            row.headline=="" || row.method!="headline_policy_lexicon_v1") {valid=false;break;}
         bool duplicate=false;
         for(int i=0;i<ArraySize(candidate);i++) if(candidate[i].id==row.id && candidate[i].target==row.target) duplicate=true;
         if(duplicate) continue;
         int n=ArraySize(candidate);ArrayResize(candidate,n+1);candidate[n]=row;
      }
      FileClose(file);
      if(!valid) return false; // Retain the previous snapshot; expiry still applies.
      ArrayResize(m_rows,ArraySize(candidate));
      for(int i=0;i<ArraySize(candidate);i++) m_rows[i]=candidate[i];
      return true;
   }

   bool Score(const string base_currency,const string quote_currency,const string symbol,
              const datetime now_utc,double &score,int &evidence,string &headline)
   {
      score=0;evidence=0;headline="";
      string base=base_currency,quote=quote_currency,name=symbol;
      StringToUpper(base);StringToUpper(quote);StringToUpper(name);
      for(int i=0;i<ArraySize(m_rows);i++)
      {
         SHeadlineContext row=m_rows[i];
         if(now_utc<row.observed || now_utc<row.published || now_utc>=row.expires) continue;
         int sign=0;
         if(row.target=="SYMBOL:"+name) sign=1;
         else if(StringLen(base)==3 && StringLen(quote)==3 && base!=quote)
         {
            if(row.target==base) sign=1;
            else if(row.target==quote) sign=-1;
         }
         if(sign==0) continue;
         score+=sign*row.score;evidence++;headline=row.headline;
      }
      if(evidence>0) score/=evidence;
      return evidence>0;
   }
};
#endif
