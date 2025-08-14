//+------------------------------------------------------------------+
//|                               2_Averages_with_BollingerBands.mq5 |
//|                                 Copyright 2025, Mir Mostof Kamal |
//|                              https://www.mql5.com/en/users/bokul |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Mir Mostof Kamal"
#property link      "https://www.mql5.com/en/users/bokul"
#property version   "1.00"
#property description   "mkbokul@gmail.com"
#property description   "2 Moving Averages With Bollinger Bands"
#property description   "This Indicator will be work in all time frame"
#property description   "WARNING: Use this software at your own risk."
#property description   "The creator of this script cannot be held responsible for any damage or loss. "
#property strict




#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   7

#property indicator_label1  "MA1"
#property indicator_type1   DRAW_LINE
#property indicator_color1  Blue

#property indicator_label2  "MA2"
#property indicator_type2   DRAW_LINE
#property indicator_color2  Red

#property indicator_label3  "Buy Signal"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  Lime
#property indicator_width3  2

#property indicator_label4  "Sell Signal"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  OrangeRed
#property indicator_width4  2

#property indicator_label5  "BB Upper"
#property indicator_type5   DRAW_LINE
#property indicator_color5  Yellow

#property indicator_label6  "BB Middle"
#property indicator_type6   DRAW_LINE
#property indicator_color6  Yellow

#property indicator_label7  "BB Lower"
#property indicator_type7   DRAW_LINE
#property indicator_color7  Yellow

//--- input parameters
input string MA1_Settings        = "=== MA1 Settings ===";
input int MA1_Period = 7;                          //1st MA Period:
input ENUM_MA_METHOD MA1_Method = MODE_EMA;        //1st MA Method:
input ENUM_APPLIED_PRICE MA1_Price = PRICE_CLOSE;  //1st MA Price:

input string MA2_Settings        = "=== MA2 Settings ===";
input int MA2_Period = 21;                         //2nd MA Period:
input ENUM_MA_METHOD MA2_Method = MODE_SMA;        //2nd MA Method:
input ENUM_APPLIED_PRICE MA2_Price = PRICE_CLOSE;  //2nd MA Price:

input string Alerts_Settings        = "=== Alerts Settings ===";
input bool EnableAlerts = true;                    //Alerts On/Off:
input bool EnableSound = true;                     //Email Alerts On/Off:
input bool EnableEmail = false;                    //Alerts Sound On/Off:

input string BB_Settings        = "--- Bollinger Bands Settings ---";
input bool Enable_BB = true;                       // Enable/Disable BB :
input int BB_Period = 60;                          // BB Period :
input double BB_Deviation = 2.0;                   // BB Deviation:
input int BB_Shift = 0;                            // BB Shift :
input ENUM_APPLIED_PRICE BB_Price = PRICE_CLOSE;   // BB Applied Price :

//--- buffers
double MA1_Buffer[];
double MA2_Buffer[];
double BuyArrow[];
double SellArrow[];
double BB_Upper[];
double BB_Middle[];
double BB_Lower[];

int handle_ma1, handle_ma2, handle_bb;
datetime lastAlertTime = 0;

//+-----------On In in-------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, MA1_Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, MA2_Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, BuyArrow, INDICATOR_DATA);
   PlotIndexSetInteger(2, PLOT_ARROW, 233); // Wingdings arrow code

   SetIndexBuffer(3, SellArrow, INDICATOR_DATA);
   PlotIndexSetInteger(3, PLOT_ARROW, 234); // Wingdings arrow code

   SetIndexBuffer(4, BB_Upper, INDICATOR_DATA);
   SetIndexBuffer(5, BB_Middle, INDICATOR_DATA);
   SetIndexBuffer(6, BB_Lower, INDICATOR_DATA);

   handle_ma1 = iMA(_Symbol, _Period, MA1_Period, 0, MA1_Method, MA1_Price);
   handle_ma2 = iMA(_Symbol, _Period, MA2_Period, 0, MA2_Method, MA2_Price);
   if(Enable_BB)
      handle_bb = iBands(_Symbol, _Period, BB_Period, BB_Shift, BB_Deviation, BB_Price);

   return(INIT_SUCCEEDED);
  }

//+------------ On Calculate ------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
  {
   if(rates_total < MathMax(MA1_Period, MA2_Period) + 2)
      return 0;

//--- price arrays
   double close[], high[], low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   CopyClose(_Symbol, _Period, 0, rates_total, close);
   CopyHigh(_Symbol, _Period, 0, rates_total, high);
   CopyLow(_Symbol, _Period, 0, rates_total, low);

//--- MA buffers
   CopyBuffer(handle_ma1, 0, 0, rates_total, MA1_Buffer);
   CopyBuffer(handle_ma2, 0, 0, rates_total, MA2_Buffer);

//--- BB buffers
   if(Enable_BB)
     {
      CopyBuffer(handle_bb, 1, 0, rates_total, BB_Upper);   // upper
      CopyBuffer(handle_bb, 0, 0, rates_total, BB_Middle);  // middle
      CopyBuffer(handle_bb, 2, 0, rates_total, BB_Lower);   // lower
     }

   for(int i = rates_total - 2; i >= 1; i--)
     {
      BuyArrow[i] = EMPTY_VALUE;
      SellArrow[i] = EMPTY_VALUE;

      if(MA1_Buffer[i] > MA2_Buffer[i] && MA1_Buffer[i+1] <= MA2_Buffer[i+1])
        {
         BuyArrow[i] = low[i] - 5 * _Point;
         if(i == 1 && TimeCurrent() != lastAlertTime)
           {
            TriggerAlert("BUY");
            lastAlertTime = TimeCurrent();
           }
        }
      else
         if(MA1_Buffer[i] < MA2_Buffer[i] && MA1_Buffer[i+1] >= MA2_Buffer[i+1])
           {
            SellArrow[i] = high[i] + 5 * _Point;
            if(i == 1 && TimeCurrent() != lastAlertTime)
              {
               TriggerAlert("SELL");
               lastAlertTime = TimeCurrent();
              }
           }
     }

   return(rates_total);
  }

//+-------------Alert system -----------------------------------------------------+

void TriggerAlert(string type)
  {
   string msg = StringFormat("2MA_BB: %s signal on %s %s at %s",
                             type, _Symbol,
                             PeriodToStr(_Period),
                             TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES));
   if(EnableAlerts)
      Alert(msg);
   if(EnableSound)
      PlaySound("alert.wav");
   if(EnableEmail)
      SendMail("DoubleMA Signal", msg);
  }

//+----------Period --------------------------------------------------------+

string PeriodToStr(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:
         return "M1";
      case PERIOD_M5:
         return "M5";
      case PERIOD_M15:
         return "M15";
      case PERIOD_M30:
         return "M30";
      case PERIOD_H1:
         return "H1";
      case PERIOD_H4:
         return "H4";
      case PERIOD_D1:
         return "D1";
      case PERIOD_W1:
         return "W1";
      case PERIOD_MN1:
         return "MN1";
      default:
         return IntegerToString(tf);
     }
  }

//+------------------Code finish by Mir Mostofa Kamal ------------------------------------------------+






//+------------------------------------------------------------------+
