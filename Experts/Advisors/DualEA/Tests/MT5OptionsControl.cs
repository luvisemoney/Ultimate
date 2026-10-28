using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Collections.Generic;
public class MTControl { public long Handle; public string Class; public string Text; public int Id; }
public static class MTInspect {
 public delegate bool Callback(IntPtr h,IntPtr l);
 [DllImport("user32.dll")] public static extern bool EnumWindows(Callback c,IntPtr l);
 [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h,Callback c,IntPtr l);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h,StringBuilder s,int n);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h,StringBuilder s,int n);
 [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="SendMessageW")] public static extern IntPtr SetText(IntPtr h,uint m,IntPtr w,string l);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 public static MTControl[] Inspect(int process) {
  var list=new List<MTControl>();
  EnumWindows((h,l)=> {
   uint p;GetWindowThreadProcessId(h,out p);var cls=new StringBuilder(200);GetClassName(h,cls,200);
   if(p==process && cls.ToString()=="#32770") {
    var t=new StringBuilder(200);GetWindowText(h,t,200);list.Add(new MTControl{Handle=h.ToInt64(),Class="DIALOG",Text=t.ToString()});
    EnumChildWindows(h,(c,x)=> {
     var cl=new StringBuilder(200);GetClassName(c,cl,200);var text=new StringBuilder(400);
     // Never inspect password/account editor contents.
     if(cl.ToString()=="Button")GetWindowText(c,text,400);
     list.Add(new MTControl{Handle=c.ToInt64(),Class=cl.ToString(),Text=text.ToString(),Id=GetDlgCtrlID(c)});return true;
    },IntPtr.Zero);
   }return true;
  },IntPtr.Zero);return list.ToArray();
 }
}
