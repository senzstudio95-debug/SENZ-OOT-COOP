using System;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Windows.Forms;
static class SenzBootstrap {
 [STAThread] static int Main() {
  string root=AppDomain.CurrentDomain.BaseDirectory;
  string script=Path.Combine(root,"Launcher.ps1");
  if(!File.Exists(script)){MessageBox.Show("Ekstrak semua fail ZIP dahulu. Launcher.ps1 mesti bersama EXE.","SENZ Offline");return 2;}
  string identity;
  using(var sha=SHA256.Create()){identity=BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(root.ToLowerInvariant()))).Replace("-","");}
  bool created;
  using(var mutex=new Mutex(false,"Local\\SENZ-Offline-"+identity,out created)) {
   if(!created){MessageBox.Show("Launcher sudah dibuka. Semak taskbar atau Alt+Tab.","SENZ Offline");return 0;}
   string log=null;
   try {
    string logs=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"SENZ","logs");
    Directory.CreateDirectory(logs);
    log=Path.Combine(logs,"launcher-"+DateTime.Now.ToString("yyyyMMdd-HHmmss")+"-"+Process.GetCurrentProcess().Id+".log");
    string ps=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),"WindowsPowerShell","v1.0","powershell.exe");
    var info=new ProcessStartInfo(ps,"-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \""+script+"\"");
    info.UseShellExecute=false;info.CreateNoWindow=true;
    info.WorkingDirectory=Path.GetTempPath();
    info.RedirectStandardError=true;info.RedirectStandardOutput=true;
    object sync=new object();
    DataReceivedEventHandler record=(sender,e)=>{if(e.Data!=null){lock(sync){try{File.AppendAllText(log,e.Data+Environment.NewLine);}catch{}}}};
    using(var child=new Process()){
     child.StartInfo=info;child.OutputDataReceived+=record;child.ErrorDataReceived+=record;
     child.Start();child.BeginOutputReadLine();child.BeginErrorReadLine();
     child.WaitForExit();
     if(child.ExitCode!=0){MessageBox.Show("Launcher gagal dibuka. Log ralat:\n"+log+"\n\nHantar fail log ini untuk pemeriksaan.","SENZ Offline",MessageBoxButtons.OK,MessageBoxIcon.Error);}
     return child.ExitCode;
    }
   }catch(Exception ex){MessageBox.Show("Tidak dapat membuka launcher:\n"+ex.Message+"\n\nLog: "+log,"SENZ Offline",MessageBoxButtons.OK,MessageBoxIcon.Error);return 1;}
  }
 }
}
