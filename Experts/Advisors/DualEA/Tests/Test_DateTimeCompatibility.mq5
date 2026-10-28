#property strict
#include <Controls/DateDropList.mqh>
int checks=0,failures=0;
void Check(bool ok,string name){checks++;if(!ok){failures++;Print("[DATE FAIL] ",name);}}
int OnInit()
{
   MqlDateTime source;
   TimeToStruct(D'2024.02.29 23:58:57',source);
   CDateTime value;value.DateTime(source);
   Check(value.year==source.year && value.mon==source.mon && value.day==source.day,"date fields");
   Check(value.hour==source.hour && value.min==source.min && value.sec==source.sec,"time fields");
   Check(value.day_of_week==source.day_of_week && value.day_of_year==source.day_of_year,"calendar metadata");
   CDateTime copy;copy=value;
   Check(copy.DateTime()==D'2024.02.29 23:58:57',"derived copy remains valid");
   CDateDropList control;control.Value(source);
   Check(control.Value()==copy.DateTime(),"drop-list retains full date and time");
   PrintFormat("[DATE RESULT] checks=%d failures=%d",checks,failures);
   return failures==0?INIT_SUCCEEDED:INIT_FAILED;
}
void OnTick(){}
double OnTester(){return failures==0?checks:-failures;}
