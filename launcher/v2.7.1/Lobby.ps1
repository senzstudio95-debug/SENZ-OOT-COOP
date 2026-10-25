Add-Type @'
using System;
using System.Net.Sockets;
using System.Text;
using System.Collections.Generic;
public sealed class SenzLobby : IDisposable {
 TcpClient c; StringBuilder pending=new StringBuilder();
 public bool Connected {get{return c!=null && c.Connected && !(c.Client.Poll(0,SelectMode.SelectRead)&&c.Available==0);}}
 public void Connect(string host,int port){c=new TcpClient();var a=c.BeginConnect(host,port,null,null);try{if(!a.AsyncWaitHandle.WaitOne(5000))throw new TimeoutException("Pelayan Anchor tidak dapat dicapai (5 saat).");c.EndConnect(a);c.NoDelay=true;c.GetStream().WriteTimeout=3000;}catch{Dispose();throw;}finally{a.AsyncWaitHandle.Close();}}
 public void Send(string json){byte[] b=Encoding.UTF8.GetBytes(json+"\0");c.GetStream().Write(b,0,b.Length);}
 public string[] Read(){var result=new List<string>();if(!Connected)return result.ToArray();var b=new byte[8192];int budget=1048576;while(c.Available>0&&budget>0){int n=c.GetStream().Read(b,0,Math.Min(b.Length,c.Available));if(n==0)break;budget-=n;pending.Append(Encoding.UTF8.GetString(b,0,n));if(pending.Length>4194304)throw new Exception("Respons pelayan terlalu besar.");}string s=pending.ToString();int start=0,end;while((end=s.IndexOf('\0',start))>=0){result.Add(s.Substring(start,end-start));start=end+1;}pending.Clear();pending.Append(s.Substring(start));return result.ToArray();}
 public void Dispose(){if(c!=null){c.Close();c=null;}pending.Clear();}
}
'@
$script:Lobby=$null;$script:LobbyReady=$false;$script:LobbyClients=@();$script:LobbyOwner=0;$script:LobbyOwnId=0
function Close-Lobby {
 if($script:Lobby){$script:Lobby.Dispose()};$script:Lobby=$null;$script:LobbyReady=$false
}
function Read-Lobby {
 if(-not $script:Lobby){return}
 foreach($raw in $script:Lobby.Read()){
  $p=$raw|ConvertFrom-Json
  if($p.type -eq 'ALL_CLIENT_STATE'){
   $script:LobbyClients=@($p.state)
   $self=@($p.state|Where-Object{$_.self})
   if($self.Count -eq 1){$script:LobbyOwnId=[int]$self[0].clientId}
  }
  if($p.type -eq 'UPDATE_ROOM_STATE'){$script:LobbyOwner=[int]$p.state.ownerClientId}
  if($p.type -eq 'DISABLE_ANCHOR'){throw 'Pelayan menolak sambungan Anchor.'}
 }
}
function Open-CoopLobby([string]$Role,[string]$Code,[string]$Server='anchor.hm64.org',[int]$Port=43383){
 if((Get-RunningGame).Count -gt 0){throw 'Tutup game sebelum buka bilik.'}
 $Code=$Code.Trim().ToUpperInvariant()
 if($Role -notin @('Host','Ivan') -or $Code -notmatch '^SENZ-[0-9A-F]{16}$'){throw 'Peranan atau kod bilik tidak sah.'}
 Close-Lobby
 $script:LobbyClients=@();$script:LobbyOwnId=0;$script:LobbyOwner=0
 $name=if($Role -eq 'Host'){'Sen'}else{'Ivan'}
 $color=if($Role -eq 'Host'){@{r=45;g=180;b=65}}else{@{r=230;g=35;b=40}}
 $state=@{name=$name;color=$color;clientVersion='961c151d2e87f2686a955a9be24d316f1362bf21';teamId='senz-duo';online=$true;seed=0;isSaveLoaded=$false;isGameComplete=$false;sceneNum=110;curRoomNum=-1;entranceIndex=0}
 try{
  $script:Lobby=New-Object SenzLobby;$script:Lobby.Connect($Server,$Port)
  $packet=@{type='HANDSHAKE';clientId=0;roomId=$Code;roomState=@{ownerClientId=0;pvpMode=0;showLocationsMode=1;teleportMode=1;syncItemsAndFlags=1};clientState=$state}
  $script:Lobby.Send(($packet|ConvertTo-Json -Depth 15 -Compress))
  $watch=[Diagnostics.Stopwatch]::StartNew()
  while($watch.ElapsedMilliseconds -lt 5000 -and ($script:LobbyOwnId -eq 0 -or $script:LobbyOwner -eq 0)){
   Read-Lobby
   if(-not $script:Lobby.Connected){throw 'Pelayan menutup sambungan.'}
   Start-Sleep -Milliseconds 25
  }
  if($script:LobbyOwnId -eq 0 -or $script:LobbyOwner -eq 0){throw 'Pelayan tidak mengesahkan bilik. Cuba semula.'}
  $online=@($script:LobbyClients|Where-Object{$_.online})
  if($online.Count -gt 2){throw 'Bilik sudah penuh. Dua pemain sahaja melalui launcher ini.'}
  if($Role -eq 'Host' -and $script:LobbyOwner -ne $script:LobbyOwnId){throw 'Kod bilik sudah digunakan. Jana kod baharu.'}
  if($Role -eq 'Ivan'){
   $hostPlayer=@($online|Where-Object{$_.clientId -eq $script:LobbyOwner -and -not $_.self})
   if($hostPlayer.Count -ne 1){throw 'Host tiada atau kod salah. Minta host Create Room dahulu.'}
   if($hostPlayer[0].clientVersion -ne $state.clientVersion){throw 'Versi enjin host berbeza.'}
  }
  Set-CoopProfile $Role $Code
  $cfg=Read-Config;Set-Node $cfg 'CVars.gRemote.Anchor.LastClientId' $script:LobbyOwnId;Write-Config $cfg
  $script:LobbyReady=$true
 }catch{Close-Lobby;throw}
}
function Assert-LobbyReady {
 $cfg=Read-Config
 if((Get-Node $cfg 'CVars.gRemote.Anchor.Enabled' 0) -eq 0){return}
 Read-Lobby
 if(-not $script:LobbyReady -or -not $script:Lobby -or -not $script:Lobby.Connected){throw 'Buka Create Room atau Join by Code dahulu. Pelayan belum mengesahkan sesi.'}
 $online=@($script:LobbyClients|Where-Object{$_.online})
 if($online.Count -gt 2){throw 'Bilik melebihi dua pemain. Buka bilik baharu.'}
 if((Get-Node $cfg 'Senz.CoopRole' 'Solo') -eq 'Ivan' -and @($online|Where-Object{$_.clientId -eq $script:LobbyOwner -and -not $_.self}).Count -ne 1){throw 'Host telah keluar. Minta host buka semula bilik.'}
}
