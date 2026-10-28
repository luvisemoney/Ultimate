#property strict
#include "../Include/CNewsSentimentStore.mqh"
int checks=0,failures=0;
void Check(bool ok,string label){checks++;if(!ok){failures++;Print("[NEWS FAIL] ",label);}}
const string header="id\tobserved_utc\tpublished_utc\texpires_utc\ttarget\tscore\timpact\turl\theadline\tmethod\n";
void Fixture(string contents)
{
   int f=FileOpen("news-contract.tsv",FILE_WRITE|FILE_TXT|FILE_ANSI,0,CP_UTF8);
   FileWriteString(f,contents);FileClose(f);
}
int OnInit()
{
   CNewsSentimentStore store;
   const string row="a\t1000\t900\t2000\tCAD\t1.0\t0\thttps://example.org/news\tHawkish policy headline\theadline_policy_lexicon_v1\n";
   Fixture(header+row+row);
   Check(store.Load("news-contract.tsv"),"Valid timestamped snapshot");
   Check(store.Count()==1,"Duplicate source URLs cannot double-count evidence");
   double score;int count;string headline;
   Check(store.Score("CAD","CHF","CADCHF",1100,score,count,headline) && score==1,"Base currency positive tone");
   Check(store.Score("USD","CAD","USDCAD",1100,score,count,headline) && score==-1,"Quote currency direction inversion");
   Check(!store.Score("USD","CHF","USDCHF",1100,score,count,headline),"Unrelated symbol gets no evidence");
   Check(!store.Score("CAD","CHF","CADCHF",999,score,count,headline),"Future observation cannot leak into history");
   Check(!store.Score("CAD","CHF","CADCHF",2000,score,count,headline),"Expiry boundary excludes stale evidence");
   Fixture(header+"bad\t1000\t900\t2000\tCAD\t1..0\t0\thttps://example.org\tHeadline\theadline_policy_lexicon_v1\n");
   Check(!store.Load("news-contract.tsv"),"Malformed numeric score rejected");
   Check(store.Count()==1,"Malformed reload preserves last valid snapshot");
   Fixture(header+"bad\t1000\t900\t2000\tCAD\tNaN\t0\thttps://example.org\tHeadline\theadline_policy_lexicon_v1\n");
   Check(!store.Load("news-contract.tsv"),"NaN cannot become neutral zero");
   Fixture(header+"short\t1\n");
   Check(!store.Load("news-contract.tsv"),"Truncated row rejected");
   Fixture(header+"a\t1000\t1100\t2000\tCAD\t1\t0\thttps://example.org\tHeadline\theadline_policy_lexicon_v1\n");
   Check(!store.Load("news-contract.tsv"),"Publication after observation rejected");
   Fixture(header+"a\t1000\t900\t2000\tSYMBOL:XAUUSD\t-1\t0\thttps://example.org\tGold headline\theadline_policy_lexicon_v1\n");
   Check(store.Load("news-contract.tsv"),"Explicit asset target accepted");
   Check(store.Score("XAU","USD","XAUUSD",1100,score,count,headline) && score==-1,"Exact asset target applies");
   Fixture(header);
   Check(store.Load("news-contract.tsv") && store.Count()==0,"Valid empty feed clears previous context");
   PrintFormat("[NEWS RESULT] checks=%d failures=%d",checks,failures);
   return failures==0?INIT_SUCCEEDED:INIT_FAILED;
}
void OnTick(){}
double OnTester(){return failures==0?checks:-failures;}
