param([string]$Bundle=(Join-Path $PSScriptRoot 'artifacts\universal'))
$ErrorActionPreference='Stop'
$model=Get-Content -LiteralPath (Join-Path $Bundle 'model_data.json') -Raw | ConvertFrom-Json
$code=@"
using System;
using System.IO;
using System.Globalization;
using System.Collections.Generic;
public class UniversalAuditResult {
 public long Rows; public long[] Counts=new long[3]; public long[] Positive=new long[3];
 public double[] Mean; public double[] Scale; public string FirstDecision; public string LastDecision;
}
public static class UniversalDatasetAudit {
 public static UniversalAuditResult Run(string path,string start,string train,string validation,string test,string[] symbols) {
  var culture=CultureInfo.InvariantCulture;
  var boundaries=new DateTime[]{DateTime.ParseExact(train,"yyyy.MM.dd",culture),DateTime.ParseExact(validation,"yyyy.MM.dd",culture),DateTime.ParseExact(test,"yyyy.MM.dd",culture)};
  var firstAllowed=DateTime.ParseExact(start,"yyyy.MM.dd",culture);
  var index=new Dictionary<string,int>(StringComparer.OrdinalIgnoreCase);
  for(int i=0;i<symbols.Length;i++)index.Add(symbols[i],i);
  int width=12+4*symbols.Length; var result=new UniversalAuditResult();
  var sums=new double[width];var squares=new double[width];
  string previous="";int mask=0;DateTime first=DateTime.MaxValue,last=DateTime.MinValue;
  using(var reader=new StreamReader(path)) {
   var header=reader.ReadLine(); if(header==null || header.Split(',').Length!=25)throw new Exception("Unexpected dataset schema");
   string line;
   while((line=reader.ReadLine())!=null) {
    if(line.Length==0)continue;var fields=line.Split(',');if(fields.Length!=25)throw new Exception("Malformed row");
    var time=DateTime.ParseExact(fields[0],"yyyy.MM.dd HH:mm",culture);
    var end=DateTime.ParseExact(fields[1],"yyyy.MM.dd HH:mm",culture);
    int split=fields[2]=="train"?0:fields[2]=="validation"?1:fields[2]=="test"?2:-1;
    if(split<0 || time<firstAllowed || (end-time).TotalHours!=4 || end>=boundaries[split] ||
      (split>0 && time<boundaries[split-1]) || time>=boundaries[split])throw new Exception("Split overlap or invalid horizon");
    int symbol=index[fields[3]],direction=int.Parse(fields[4],culture),label=int.Parse(fields[5],culture);
    double outcome=double.Parse(fields[6],culture);
    if(direction<0 || direction>1 || label!=(outcome>0?1:0) || double.IsNaN(outcome) || double.IsInfinity(outcome))throw new Exception("Invalid observed outcome");
    for(int j=7;j<9;j++)if(double.Parse(fields[j],culture)<0)throw new Exception("Negative spread");
    string key=fields[3]+"|"+fields[0];
    if(key!=previous) {if(previous!="" && mask!=3)throw new Exception("Unpaired directions");previous=key;mask=0;}
    if((mask&(1<<direction))!=0)throw new Exception("Duplicated direction");mask|=1<<direction;
    double[] x=new double[16];
    for(int j=0;j<16;j++){x[j]=double.Parse(fields[9+j],culture);if(double.IsNaN(x[j]) || double.IsInfinity(x[j]))throw new Exception("Nonfinite feature");}
    double denom=Math.Max(x[4],1e-8);
    if(Math.Abs(x[12]-1)>1e-10 || Math.Abs(x[13]-x[0]/denom)>1e-7 || Math.Abs(x[14]-x[1]/denom)>1e-7 || Math.Abs(x[15]-x[3])>1e-10)throw new Exception("Symbol feature contract mismatch");
    if(split==0)for(int j=0;j<16;j++){int f=j<12?j:12+4*symbol+j-12;sums[f]+=x[j];squares[f]+=x[j]*x[j];}
    result.Rows++;result.Counts[split]++;result.Positive[split]+=label;
    if(time<first)first=time;if(time>last)last=time;
   }
  }
  if(mask!=3 || result.Rows==0 || result.Counts[0]==0)throw new Exception("Incomplete dataset");
  result.Mean=new double[width];result.Scale=new double[width];
  for(int j=0;j<width;j++){result.Mean[j]=sums[j]/result.Counts[0];double v=squares[j]/result.Counts[0]-result.Mean[j]*result.Mean[j];result.Scale[j]=Math.Sqrt(Math.Max(0,v));if(result.Scale[j]<1e-12)result.Scale[j]=1;}
  result.FirstDecision=first.ToString("yyyy.MM.dd HH:mm");result.LastDecision=last.ToString("yyyy.MM.dd HH:mm");return result;
 }
}
"@
if(!('UniversalDatasetAudit' -as [type])){Add-Type -TypeDefinition $code}
$result=[UniversalDatasetAudit]::Run((Join-Path $Bundle 'dataset.csv'),$model.training_start,$model.training_end,$model.validation_end,$model.test_end,[string[]]$model.supported_symbols)
$errorMax=0.0
for($j=0;$j -lt $result.Mean.Length;$j++){
 $errorMax=[Math]::Max($errorMax,[Math]::Abs($result.Mean[$j]-[double]$model.scaler_mean[$j]))
 $errorMax=[Math]::Max($errorMax,[Math]::Abs($result.Scale[$j]-[double]$model.scaler_scale[$j]))
}
if($errorMax -gt 0.0000001){throw ('Scaler differs from training-only recomputation: '+$errorMax)}
$report=[ordered]@{status='PASS';rows=$result.Rows;split_counts=$result.Counts;positive_counts=$result.Positive;first_decision=$result.FirstDecision;last_decision=$result.LastDecision;scaler_max_error=$errorMax;model_sha256=(Get-FileHash (Join-Path $Bundle 'signal_model.onnx') -Algorithm SHA256).Hash.ToLowerInvariant();checks=@('finite observed outcomes','real target labels','four-hour horizons','paired directions','chronological purged splits','symbol interaction features','training-only scaler recomputation')}
[IO.File]::WriteAllText((Join-Path $Bundle 'dataset_audit.json'),($report|ConvertTo-Json -Depth 5))
Write-Output ($report|ConvertTo-Json -Depth 5 -Compress)