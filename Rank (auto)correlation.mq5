//------------------------------------------------------------------
#property copyright "www.forex-tsd.com"
#property link      "www.forex-tsd.com"
//------------------------------------------------------------------
#property indicator_separate_window
#property indicator_buffers   9
#property indicator_plots     8

#property indicator_label1  "Spearman levels"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  clrLimeGreen,clrPaleVioletRed
#property indicator_label2  "Spearman  level up"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLimeGreen
#property indicator_style2  STYLE_DOT
#property indicator_label3  "Spearman  middle level"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrSilver
#property indicator_style3  STYLE_DOT
#property indicator_label4  "Spearman  level down"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrPaleVioletRed
#property indicator_style4  STYLE_DOT
#property indicator_label5  "Spearman"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrDimGray
#property indicator_width5  2
#property indicator_label6  "Smoothed Spearman"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrDeepSkyBlue
#property indicator_width6  2
#property indicator_label7  "Buy signal"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrLimeGreen
#property indicator_width7  2
#property indicator_label8  "Sell signal"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrTomato
#property indicator_width8  2
#property indicator_minimum  -1
#property indicator_maximum  +1

enum enPrices
{
   pr_close,      // Close
   pr_open,       // Open
   pr_high,       // High
   pr_low,        // Low
   pr_median,     // Median
   pr_typical,    // Typical
   pr_weighted,   // Weighted
   pr_average,    // Average (high+low+open+close)/4
   pr_medianb,    // Average median body (open+close)/2
   pr_tbiased,    // Trend biased price
   pr_tbiased2,   // Trend biased (extreme) price
   pr_haclose,    // Heiken ashi close
   pr_haopen ,    // Heiken ashi open
   pr_hahigh,     // Heiken ashi high
   pr_halow,      // Heiken ashi low
   pr_hamedian,   // Heiken ashi median
   pr_hatypical,  // Heiken ashi typical
   pr_haweighted, // Heiken ashi weighted
   pr_haaverage,  // Heiken ashi average
   pr_hamedianb,  // Heiken ashi median body
   pr_hatbiased,  // Heiken ashi trend biased price
   pr_hatbiased2  // Heiken ashi trend biased (extreme) price
};

enum enCorrType
{
   cor_spe,  // Spearman rank correlation
   cor_pea   // Pearson rank correlation
};
input int        Rank        = 32;       // Rank period
input enCorrType CorType     = cor_spe;  // Correlation type
input enPrices   Price       = pr_close; // Price to use
input  int       flLookBack     = 25;       // Floating levels look back period (<0 for fixed levels, 0 to use rank period)
input  bool      UsePercentiles = true;     // Use percentile based floating levels
input  double    flLevelUp      = 90;       // Floating levels up level %
input  double    flLevelDown    = 10;       // Floating levels down level %
input  int       SmoothPeriod   = 5;        // EMA smoothing period (0/1 to disable)
input  bool      alertsOn       = false;    // Enable alerts
input  bool      alertsOnCurrent= false;    // Alert on current (open) bar
input  bool      alertsNotify   = false;    // Send push notification
input  bool      alertsEmail    = false;    // Send email notification
input  bool      alertsSound    = false;    // Play alert sound
input  string    alertsSoundFile= "alert.wav"; // Sound file name

//
//
//
//
//

double sr[],signal[],levelup[],levelmi[],leveldn[],fill1[],fill2[],arrowUp[],arrowDn[];
double percentileBuffer[];
datetime lastAlertBuy=0;
datetime lastAlertSell=0;

//------------------------------------------------------------------
//
//------------------------------------------------------------------
//
//
//
//

int OnInit()
{
   SetIndexBuffer(0,fill1  ,INDICATOR_DATA);
   SetIndexBuffer(1,fill2  ,INDICATOR_DATA);
   SetIndexBuffer(2,levelup,INDICATOR_DATA);
   SetIndexBuffer(3,levelmi,INDICATOR_DATA);
   SetIndexBuffer(4,leveldn,INDICATOR_DATA);
   SetIndexBuffer(5,sr     ,INDICATOR_DATA);
   SetIndexBuffer(6,signal ,INDICATOR_DATA);
   SetIndexBuffer(7,arrowUp,INDICATOR_DATA);
   SetIndexBuffer(8,arrowDn,INDICATOR_DATA);

   PlotIndexSetInteger(5,PLOT_DRAW_BEGIN,SmoothPeriod);
   PlotIndexSetInteger(6,PLOT_ARROW,233);
   PlotIndexSetInteger(7,PLOT_ARROW,234);
   PlotIndexSetDouble(6,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetDouble(7,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   SetIndexEmptyValue(7,EMPTY_VALUE);
   SetIndexEmptyValue(8,EMPTY_VALUE);

   lastAlertBuy  = 0;
   lastAlertSell = 0;

   IndicatorSetString(INDICATOR_SHORTNAME,getCorrelationName(CorType)+" rank (auto)correlation ("+(string)Rank+","+(string)flLookBack+")");
   return(0);
}

//------------------------------------------------------------------
//
//------------------------------------------------------------------
//
//
//
//

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[])
{
   if (Bars(_Symbol,_Period)<rates_total) return(-1);

   //
   //
   //
   //
   //
   
   int flperiod = flLookBack; if (flperiod==0) flperiod = Rank;
   for (int i=(int)MathMax(prev_calculated-1,0); i<rates_total && !IsStopped(); i++)
   {
      sr[i] = iCorrelation(CorType,getPrice(Price,open,close,high,low,i,rates_total),Rank,i,rates_total);
      signal[i] = sr[i];
      arrowUp[i] = EMPTY_VALUE;
      arrowDn[i] = EMPTY_VALUE;

      if (flperiod>0)
      {
         int lookback = (int)MathMin(flperiod,i+1);
         if (UsePercentiles && lookback>1)
         {
            ArrayResize(percentileBuffer,lookback);
            for (int k=0; k<lookback; k++) percentileBuffer[k] = sr[i-k];
            ArraySort(percentileBuffer,WHOLE_ARRAY,0,MODE_ASCEND);
            levelup[i] = GetPercentile(percentileBuffer,lookback,flLevelUp/100.0);
            leveldn[i] = GetPercentile(percentileBuffer,lookback,flLevelDown/100.0);
            levelmi[i] = GetPercentile(percentileBuffer,lookback,0.5);
         }
         else
         {
            double min = sr[i];
            double max = sr[i];
            for (int k=1; k<flperiod && (i-k)>=0; k++)
            {
               min = MathMin(sr[i-k],min);
               max = MathMax(sr[i-k],max);
            }
            double range = max-min;
            levelup[i] = min+flLevelUp*range/100.0;
            leveldn[i] = min+flLevelDown*range/100.0;
            levelmi[i] = min+0.5*range;
         }
      }
      else
      {
         levelup[i] = 2*flLevelUp  /100.0-1;
         leveldn[i] = 2*flLevelDown/100.0-1; 
         levelmi[i] = (levelup[i]+leveldn[i])*0.5;
      }       
      if (SmoothPeriod>1)
      {
         if (i>0)
               signal[i] = signal[i-1] + 2.0/(SmoothPeriod+1.0)*(sr[i]-signal[i-1]);
         else  signal[i] = sr[i];
      }

      fill1[i] = fill2[i] = sr[i];
      if (sr[i]>levelup[i]) fill2[i] = levelup[i];
      if (sr[i]<leveldn[i]) fill2[i] = leveldn[i];

      if (i>0)
      {
         bool crossUp   = (signal[i-1]<=leveldn[i-1] && signal[i]>leveldn[i]);
         bool crossDown = (signal[i-1]>=levelup[i-1] && signal[i]<levelup[i]);
         bool lastBar   = (i==rates_total-1);
         bool allowAlert = alertsOnCurrent || !lastBar;

         if (crossUp)
         {
            arrowUp[i] = leveldn[i];
            if (allowAlert && (alertsOn || alertsNotify || alertsEmail || alertsSound) && prev_calculated>0 && lastAlertBuy!=time[i])
            {
               DoSignalAlert(true,time[i],signal[i]);
               lastAlertBuy = time[i];
            }
         }
         if (crossDown)
         {
            arrowDn[i] = levelup[i];
            if (allowAlert && (alertsOn || alertsNotify || alertsEmail || alertsSound) && prev_calculated>0 && lastAlertSell!=time[i])
            {
               DoSignalAlert(false,time[i],signal[i]);
               lastAlertSell = time[i];
            }
         }
      }
   }
   return(rates_total);
}

//------------------------------------------------------------------
//
//------------------------------------------------------------------
//
//
//
//
//
//

#define priceInstances 1
double workHa[][priceInstances*4];
double getPrice(int tprice, const double& open[], const double& close[], const double& high[], const double& low[], int i,int _bars, int instanceNo=0)
{
  if (tprice>=pr_haclose)
   {
      if (ArrayRange(workHa,0)!= _bars) ArrayResize(workHa,_bars); int r=i; instanceNo*=4;
         
         //
         //
         //
         //
         //
         
         double haOpen;
         if (r>0)
                haOpen  = (workHa[r-1][instanceNo+2] + workHa[r-1][instanceNo+3])/2.0;
         else   haOpen  = (open[i]+close[i])/2;
         double haClose = (open[i] + high[i] + low[i] + close[i]) / 4.0;
         double haHigh  = MathMax(high[i], MathMax(haOpen,haClose));
         double haLow   = MathMin(low[i] , MathMin(haOpen,haClose));

         if(haOpen  <haClose) { workHa[r][instanceNo+0] = haLow;  workHa[r][instanceNo+1] = haHigh; } 
         else                 { workHa[r][instanceNo+0] = haHigh; workHa[r][instanceNo+1] = haLow;  } 
                                workHa[r][instanceNo+2] = haOpen;
                                workHa[r][instanceNo+3] = haClose;
         //
         //
         //
         //
         //
         
         switch (tprice)
         {
            case pr_haclose:     return(haClose);
            case pr_haopen:      return(haOpen);
            case pr_hahigh:      return(haHigh);
            case pr_halow:       return(haLow);
            case pr_hamedian:    return((haHigh+haLow)/2.0);
            case pr_hamedianb:   return((haOpen+haClose)/2.0);
            case pr_hatypical:   return((haHigh+haLow+haClose)/3.0);
            case pr_haweighted:  return((haHigh+haLow+haClose+haClose)/4.0);
            case pr_haaverage:   return((haHigh+haLow+haClose+haOpen)/4.0);
            case pr_hatbiased:
               if (haClose>haOpen)
                     return((haHigh+haClose)/2.0);
               else  return((haLow+haClose)/2.0);        
            case pr_hatbiased2:
               if (haClose>haOpen)  return(haHigh);
               if (haClose<haOpen)  return(haLow);
                                    return(haClose);        
         }
   }
   
   //
   //
   //
   //
   //
   
   switch (tprice)
   {
      case pr_close:     return(close[i]);
      case pr_open:      return(open[i]);
      case pr_high:      return(high[i]);
      case pr_low:       return(low[i]);
      case pr_median:    return((high[i]+low[i])/2.0);
      case pr_medianb:   return((open[i]+close[i])/2.0);
      case pr_typical:   return((high[i]+low[i]+close[i])/3.0);
      case pr_weighted:  return((high[i]+low[i]+close[i]+close[i])/4.0);
      case pr_average:   return((high[i]+low[i]+close[i]+open[i])/4.0);
      case pr_tbiased:   
               if (close[i]>open[i])
                     return((high[i]+close[i])/2.0);
               else  return((low[i]+close[i])/2.0);        
      case pr_tbiased2:   
               if (close[i]>open[i]) return(high[i]);
               if (close[i]<open[i]) return(low[i]);
                                     return(close[i]);        
   }
   return(0);
}

  
//------------------------------------------------------------------
//                                                                  
//------------------------------------------------------------------
//
//
//
//
//

string getCorrelationName(int mode)
{
   switch (mode)
   {
      case cor_pea  : return("Pearson");
      case cor_spe  : return("Spearman");
      default       : return("");
   }
}
#define correlationInstances 4
double iCorrelation(int mode, double price, double length, int r, int bars, int instanceNo=0)
{
   switch (mode)
   {
      case cor_pea  : return(iPearson(price,(int)length,r,bars,instanceNo));
      case cor_spe  : return(iSpearman(price,(int)length,r,bars,instanceNo));
      default       : return(price);
   }
}

//
//
//
//
//

double workPearson[][correlationInstances];
double iPearson(double value, int period, int i, int bars, int instanceNo=0)
{
   if (ArrayRange(workPearson,0)!=bars) ArrayResize(workPearson,bars); workPearson[i][instanceNo]=value;
   
   //
   //
   //
   //
   //
   
   double SumXY=0; double SumXX=0; double SumYY=0; double SumY=0; double SumX=0;         
   for(int k=0; k<period && (i-k)>=0; k++)
   {
      double val = workPearson[i-k][instanceNo];
             SumX  += val;  
             SumY  += k;  
             SumXX += val*val;
             SumYY += k*k;         
             SumXY += val*k; 
   }
   double SXY    =  period*SumXY-SumY*SumX; 
   double SXXYY  = (period*SumXX-SumX*SumX)*(period*SumYY-SumY*SumY);
   double result = (SXXYY!=0) ? -SXY/(MathSqrt(MathAbs(SXXYY))) : 0;
   return(result);
}

//
//
//
//
//

double workSpearman[][correlationInstances];
double iSpearman(double value, int period, int i, int bars, int instanceNo=0)
{
   if (ArrayRange(workSpearman,0)!=bars) ArrayResize(workSpearman,bars); workSpearman[i][instanceNo]=value;

   //
   //
   //
   //
   //
      
   double total=0; 
   double data[]; ArrayResize(data, period); ArrayInitialize(data,0);
      for (int k=0; k<period && (i-k)>=0; k++) data[k] = workSpearman[i-k][instanceNo];
      for (int k=0; k<period; k++) { int max = ArrayMaximum(data); total += (max-k)*(max-k); data[max] = 0; }
        return(1.0-6.0*total/(period*(period*period-1.0)));
}

//
//
//
//
//

double GetPercentile(double &values[], int count, double percent)
{
   if (count<=0)
      return(0.0);
   if (percent<=0.0)
      return(values[0]);
   if (percent>=1.0)
      return(values[count-1]);
   double position = percent*(count-1);
   int indexLow = (int)MathFloor(position);
   int indexHigh = (int)MathCeil(position);
   double value = values[indexLow];
   if (indexHigh>indexLow)
      value += (values[indexHigh]-values[indexLow])*(position-indexLow);
   return(value);
}

//
//
//
//
//

void DoSignalAlert(bool isBuy, datetime barTime, double value)
{
   string direction = isBuy ? "buy" : "sell";
   string message   = StringFormat("%s %s signal from %s rank correlation on %s (%.3f)",
                                   _Symbol,
                                   direction,
                                   getCorrelationName(CorType),
                                   TimeToString(barTime,TIME_DATE|TIME_MINUTES),
                                   value);

   if (alertsOn)
      Alert(message);
   if (alertsNotify)
      SendNotification(message);
   if (alertsEmail)
      SendMail("Rank correlation signal",message);
   if (alertsSound && alertsSoundFile!="")
      PlaySound(alertsSoundFile);
}
