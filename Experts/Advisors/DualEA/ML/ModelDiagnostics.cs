using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Globalization;
public class ModelAuditRow {
 public string split,symbol,time; public int side,label; public double p,ret;
}
public class ModelAuditStats {
 public string group; public int rows,positive,above55,above60,above70;
 public double auc,accuracy,majorityAccuracy,meanProbability,minProbability,maxProbability,logLoss,meanRecordedNetReturn;
}
public static class ModelDiagnostics {
 static double D(string s){return double.Parse(s,CultureInfo.InvariantCulture);}
 public static double Auc(List<ModelAuditRow> rows) {
  var sorted=rows.OrderBy(x=>x.p).ToArray();long pos=sorted.Count(x=>x.label==1),neg=sorted.Length-pos;
  if(pos==0 || neg==0)return double.NaN;
  double ranks=0;int i=0;
  while(i<sorted.Length){int j=i+1;while(j<sorted.Length && sorted[j].p==sorted[i].p)j++;
   double rank=(i+1+j)/2.0;for(int k=i;k<j;k++)if(sorted[k].label==1)ranks+=rank;i=j;}
  return (ranks-pos*(pos+1.0)/2)/(pos*neg);
 }
 public static ModelAuditStats Stats(string name,List<ModelAuditRow> r) {
  int pos=r.Count(x=>x.label==1);return new ModelAuditStats{group=name,rows=r.Count,positive=pos,auc=Auc(r),
   accuracy=r.Average(x=>(x.p>=.5?1:0)==x.label?1.0:0.0),majorityAccuracy=(double)Math.Max(pos,r.Count-pos)/r.Count,
   meanProbability=r.Average(x=>x.p),minProbability=r.Min(x=>x.p),maxProbability=r.Max(x=>x.p),
   above55=r.Count(x=>x.p>=.55),above60=r.Count(x=>x.p>=.6),above70=r.Count(x=>x.p>=.7),
   logLoss=r.Average(x=>-(x.label*Math.Log(Math.Max(x.p,1e-15))+(1-x.label)*Math.Log(Math.Max(1-x.p,1e-15)))),
   meanRecordedNetReturn=r.Average(x=>x.ret)};
 }
 public static ModelAuditStats[] Run(string path,string[] symbols,double[] weights,double[] mean,double[] scale,double intercept) {
  var rows=new List<ModelAuditRow>();var index=symbols.Select((s,i)=>new{s,i}).ToDictionary(x=>x.s,x=>x.i);
  using(var reader=new StreamReader(path)){reader.ReadLine();string line;
   while((line=reader.ReadLine())!=null){var f=line.Split(',');if(f.Length!=25)throw new Exception("Unexpected dataset width");
    int s=index[f[3]];double score=intercept;
    for(int j=0;j<weights.Length;j++){int local=j<12?j:(j>=12+4*s && j<16+4*s?12+j-(12+4*s):-1);
     double x=local<0?0:D(f[9+local]);score+=weights[j]*(x-mean[j])/scale[j];}
    double p=1/(1+Math.Exp(-Math.Max(-700,Math.Min(700,score))));
    rows.Add(new ModelAuditRow{time=f[0],split=f[2],symbol=f[3],side=int.Parse(f[4]),label=int.Parse(f[5]),ret=D(f[6]),p=p});
   }
  }
  var result=new List<ModelAuditStats>();
  foreach(var g in rows.GroupBy(x=>x.split))result.Add(Stats(g.Key,g.ToList()));
  foreach(var g in rows.Where(x=>x.split=="test").GroupBy(x=>x.symbol))result.Add(Stats("test/symbol/"+g.Key,g.ToList()));
  foreach(var g in rows.Where(x=>x.split=="test").GroupBy(x=>x.side))result.Add(Stats("test/side/"+g.Key,g.ToList()));
  foreach(var g in rows.Where(x=>x.split=="test").GroupBy(x=>x.time.Substring(0,10)))result.Add(Stats("test/day/"+g.Key,g.ToList()));
  var test=rows.Where(x=>x.split=="test").ToList();var rng=new Random(20261028);
  for(int repeat=0;repeat<5;repeat++){var labels=test.Select(x=>x.label).ToArray();
   for(int i=labels.Length-1;i>0;i--){int j=rng.Next(i+1);int t=labels[i];labels[i]=labels[j];labels[j]=t;}
   var shuffled=test.Select((x,i)=>new ModelAuditRow{p=x.p,label=labels[i],ret=x.ret}).ToList();
   result.Add(Stats("test/shuffle/"+repeat,shuffled));
  }
  return result.ToArray();
 }
}
