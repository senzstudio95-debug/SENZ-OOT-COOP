param([int]$Port)
$ErrorActionPreference='Stop'
$base=Split-Path $PSScriptRoot -Parent
function Assert($ok,$message){if(-not $ok){throw $message};Write-Host ('PASS '+$message)}
function Module([string]$name){
 New-Module -Name $name -ArgumentList $base -ScriptBlock {
  param($base)
  $script:cfg=[pscustomobject]@{};$Root=Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid());$Engine=Join-Path $Root 'engine'
  function Get-RunningGame {return @()}
  function Read-Config {return $script:cfg}
  function Write-Config($c){$script:cfg=$c}
  function Get-Node($Object,[string]$Path,$Default){foreach($name in $Path.Split('.')){if($null -eq $Object -or -not $Object.PSObject.Properties[$name]){return $Default};$Object=$Object.$name};return $Object}
  function Set-Node($Object,[string]$Path,$Value){$Parts=$Path.Split('.');for($i=0;$i -lt $Parts.Length-1;$i++){if(-not $Object.PSObject.Properties[$Parts[$i]]){$Object|Add-Member -NotePropertyName $Parts[$i] -NotePropertyValue ([pscustomobject]@{})};$Object=$Object.($Parts[$i])};$Object|Add-Member -NotePropertyName $Parts[-1] -NotePropertyValue $Value -Force}
  . (Join-Path $base 'Coop.ps1');. (Join-Path $base 'Lobby.ps1')
 }
}
function Wait-Ready($m){$stop=(Get-Date).AddSeconds(5);do{$ready=&$m{Complete-CoopLobby};if($ready){return};Start-Sleep -Milliseconds 25}while((Get-Date) -lt $stop);throw 'Lobby timed out'}
function Send($c,$p){$b=[Text.Encoding]::UTF8.GetBytes(($p|ConvertTo-Json -Depth 20 -Compress)+[char]0);$c.GetStream().Write($b,0,$b.Length)}
function Receive($c){$stop=(Get-Date).AddSeconds(3);$s='';do{while($c.Available -gt 0){$b=New-Object byte[] 65536;$n=$c.GetStream().Read($b,0,$b.Length);$s += [Text.Encoding]::UTF8.GetString($b,0,$n)};if($s.Contains([char]0)){return @($s.Split([char]0)|Where-Object{$_}|ForEach-Object{$_|ConvertFrom-Json})};Start-Sleep -Milliseconds 15}while((Get-Date)-lt $stop);throw 'No game packets'}
$hostMod=Module 'HostTest';$guestMod=Module 'GuestTest';$wrong=Module 'WrongTest';$native=$null;$guestNative=$null
try{
 $code='SENZ-1122334455667788'
 &$hostMod {param($c,$p)Begin-CoopLobby Host $c '127.0.0.1' $p} $code $Port;Wait-Ready $hostMod
 Assert (&$hostMod{$script:LobbyReady}) 'host room confirmed'
 &$guestMod {param($c,$p)Begin-CoopLobby Ivan $c '127.0.0.1' $p} ' 1122334455667788 ' $Port;Wait-Ready $guestMod
 Assert (&$guestMod{$script:LobbyReady}) 'guest joined normalized invite code'
 &$hostMod {Read-Lobby};Assert ((&$hostMod{@($script:LobbyClients|Where-Object online).Count}) -eq 2) 'two players visible'
 $id=&$hostMod{$script:LobbyOwnId};$local=&$hostMod{$script:Lobby.LocalPort}
 $native=[Net.Sockets.TcpClient]::new('127.0.0.1',$local)
 $state=@{name='Sen';color=@{r=45;g=180;b=65};clientVersion='961c151d2e87f2686a955a9be24d316f1362bf21';teamId='senz-duo';online=$true;isSaveLoaded=$true;sceneNum=1}
 Send $native @{type='HANDSHAKE';clientId=$id;clientState=$state;roomId=$code;roomState=@{ownerClientId=$id}}
 $packets=Receive $native
 Assert (@($packets|Where-Object type -eq ALL_CLIENT_STATE).Count -eq 1) 'native receives identity snapshot'
 Assert (@($packets|Where-Object type -eq UPDATE_ROOM_STATE).Count -eq 1) 'native receives room settings'
 Start-Sleep -Milliseconds 100
 &$guestMod {Read-Lobby}
 Assert ((&$guestMod{@($script:LobbyClients|Where-Object{$_.clientId -eq $script:LobbyOwner})[0].isSaveLoaded})) 'guest applies incremental host state'
 $gid=&$guestMod{$script:LobbyOwnId};$gport=&$guestMod{$script:Lobby.LocalPort}
 $guestNative=[Net.Sockets.TcpClient]::new('127.0.0.1',$gport)
 Send $guestNative @{type='HANDSHAKE';clientId=$gid;clientState=$state;roomId=$code;roomState=@{ownerClientId=$id}}
 [void](Receive $guestNative)
 Send $native @{type='PLAYER_UPDATE';clientId=$id;data='transport-test'}
 $forwarded=@(Receive $guestNative)
 Assert (@($forwarded|Where-Object{$_.type -eq 'PLAYER_UPDATE' -and $_.data -eq 'transport-test'}).Count -eq 1) 'gameplay packet forwarded host to guest'
 Send $guestNative @{type='PLAYER_UPDATE';clientId=$gid;data='return-test'}
 $back=@();$limit=(Get-Date).AddSeconds(3)
 do{$back+=@(Receive $native)}while(@($back|Where-Object{$_.type -eq 'PLAYER_UPDATE' -and $_.data -eq 'return-test'}).Count -eq 0 -and (Get-Date) -lt $limit)
 Assert (@($back|Where-Object{$_.type -eq 'PLAYER_UPDATE' -and $_.data -eq 'return-test'}).Count -eq 1) 'gameplay packet forwarded guest to host'
 $guestNative.Close();$guestNative=$null
 Assert (&$hostMod{$script:Lobby.Connected -and $script:Lobby.GameConnected}) 'persistent relay survives game attach'
 Start-Sleep -Seconds 32
 Assert (&$hostMod{$script:Lobby.Connected -and $script:Lobby.GameConnected}) 'connection remains after old 30-second cutoff'
 $native.Close();$native=$null;Start-Sleep -Milliseconds 100
 &$guestMod {Read-Lobby;Assert-LobbyReady}
 Assert (&$hostMod{$script:Lobby.Connected}) 'host lobby stays online after game exits'
 &$guestMod {Close-Lobby}
 &$guestMod {param($c,$p)Begin-CoopLobby Ivan $c '127.0.0.1' $p} $code $Port;Wait-Ready $guestMod
 Assert (&$guestMod{$script:LobbyReady}) 'guest can rejoin same host'
 &$wrong {param($p)Begin-CoopLobby Ivan 'SENZ-FFFFFFFFFFFFFFFF' '127.0.0.1' $p} $Port
 $rejected=$false;try{Wait-Ready $wrong}catch{$rejected=$_.Exception.Message -like '*tiada host aktif*'}
 Assert $rejected 'wrong/nonexistent host rejected, not fake success'
 &$hostMod {Close-Lobby};Start-Sleep -Milliseconds 100
 $offline=$false;try{&$guestMod {Read-Lobby;Assert-LobbyReady}}catch{$offline=$_.Exception.Message -like '*Host offline*'}
 Assert $offline 'disconnected host detected'
}finally{if($guestNative){$guestNative.Close()};if($native){$native.Close()};foreach($m in @($hostMod,$guestMod,$wrong)){&$m{Close-Lobby}}}
