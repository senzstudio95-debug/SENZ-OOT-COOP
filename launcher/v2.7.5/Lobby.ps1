if(-not ('SenzLobby' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'LobbyBridge.cs') }
$script:Lobby=$null;$script:LobbyReady=$false;$script:LobbyPending=$false
$script:LobbyClients=@();$script:LobbyOwner=0;$script:LobbyOwnId=0
function Close-Lobby {
 if($script:Lobby){$script:Lobby.Dispose()}
 $script:Lobby=$null;$script:LobbyReady=$false;$script:LobbyPending=$false
}
function Read-Lobby {
 if(-not $script:Lobby){return}
 foreach($raw in $script:Lobby.Read()){
  $p=$raw|ConvertFrom-Json
  if($p.type -eq 'ALL_CLIENT_STATE'){
   $script:LobbyClients=@($p.state)
   $self=@($p.state|Where-Object{$_.self})
   if($self.Count -eq 1){$script:LobbyOwnId=[int]$self[0].clientId;$script:Lobby.SetIdentity($script:LobbyOwnId)}
  } elseif($p.type -eq 'UPDATE_CLIENT_STATE'){
   $id=[int]$p.clientId
   $p.state | Add-Member -NotePropertyName clientId -NotePropertyValue $id -Force
   $p.state | Add-Member -NotePropertyName self -NotePropertyValue ($id -eq $script:LobbyOwnId) -Force
   $script:LobbyClients=@($script:LobbyClients|Where-Object{$_.clientId -ne $id})+@($p.state)
  } elseif($p.type -eq 'UPDATE_ROOM_STATE'){$script:LobbyOwner=[int]$p.state.ownerClientId
  } elseif($p.type -eq 'DISABLE_ANCHOR'){throw 'Pelayan menolak sambungan Anchor.'}
 }
 if($script:Lobby.Error){throw $script:Lobby.Error}
}
function Normalize-InviteCode([string]$Code) {
 $Code=($Code -replace '\s','').ToUpperInvariant()
 if($Code -match '^[0-9A-F]{16}$'){$Code='SENZ-'+$Code}
 if($Code -notmatch '^SENZ-[0-9A-F]{16}$'){throw 'Kod tidak lengkap. Tampal kod SENZ daripada host.'}
 return $Code
}
function Begin-CoopLobby([string]$Role,[string]$Code,[string]$Server='iriguchi.proxy.rlwy.net',[int]$Port=51417){
 if((Get-RunningGame).Count -gt 0){throw 'Tutup game sebelum menukar bilik.'}
 $Code=Normalize-InviteCode $Code
 if($Role -notin @('Host','Ivan')){throw 'Peranan tidak sah.'}
 Close-Lobby
 $script:LobbyClients=@();$script:LobbyOwnId=0;$script:LobbyOwner=0
 $script:LobbyRole=$Role;$script:LobbyCode=$Code
 $name=if($Role -eq 'Host'){'Sen'}else{'Ivan'}
 $color=if($Role -eq 'Host'){@{r=45;g=180;b=65}}else{@{r=230;g=35;b=40}}
 $state=@{name=$name;color=$color;clientVersion='961c151d2e87f2686a955a9be24d316f1362bf21';teamId='senz-duo';online=$true;seed=0;isSaveLoaded=$false;isGameComplete=$false;sceneNum=110;curRoomNum=-1;entranceIndex=0}
 # IDs belong to one PC and room. Never import IDs from a copied config on a different PC.
 $requestedId=0;$previous=Read-Config
 $machine=[Environment]::MachineName
 if((Get-Node $previous 'Senz.LobbyMachine' '') -eq $machine -and (Get-Node $previous 'Senz.CoopRole' '') -eq $Role -and (Get-Node $previous 'CVars.gRemote.Anchor.RoomId' '') -eq $Code){$requestedId=[int](Get-Node $previous 'CVars.gRemote.Anchor.LastClientId' 0)}
 $packet=@{type='HANDSHAKE';clientId=$requestedId;roomId=$Code;roomState=@{ownerClientId=0;pvpMode=0;showLocationsMode=1;teleportMode=1;syncItemsAndFlags=1};clientState=$state}
 $idle=@{type='UPDATE_CLIENT_STATE';clientId=$requestedId;state=$state}
 $script:Lobby=New-Object SenzLobby
 $script:Lobby.Start($Server,$Port,($packet|ConvertTo-Json -Depth 15 -Compress),($idle|ConvertTo-Json -Depth 15 -Compress))
 $script:LobbyPending=$true;$script:LobbyDeadline=(Get-Date).AddSeconds(20)
}
function Complete-CoopLobby {
 Read-Lobby
 if(-not $script:LobbyPending){return $script:LobbyReady}
 if($script:LobbyOwnId -ne 0 -and $script:LobbyOwner -ne 0){
  $online=@($script:LobbyClients|Where-Object{$_.online})
  if($online.Count -gt 2){throw 'Bilik penuh: dua pemain sudah online.'}
  if($script:LobbyRole -eq 'Host' -and $script:LobbyOwner -ne $script:LobbyOwnId){throw 'Kod ini dimiliki host lain. Tekan Create Lobby untuk kod baharu.'}
  if($script:LobbyRole -eq 'Ivan'){
   if($script:LobbyOwner -eq $script:LobbyOwnId){throw 'Kod ini tiada host aktif. Minta host tekan Create Lobby dan SALIN KOD baharu. Kedua-dua PC mesti guna v2.7.5 atau lebih baharu.'}
   $hostPlayer=@($online|Where-Object{$_.clientId -eq $script:LobbyOwner -and -not $_.self})
   if($hostPlayer.Count -ne 1){
    if((Get-Date) -ge $script:LobbyDeadline){throw 'Host telah offline. Minta host buka semula bilik atau cipta kod baharu.'}
    return $false
   }
   if($hostPlayer[0].clientVersion -ne '961c151d2e87f2686a955a9be24d316f1362bf21'){throw 'Versi game host berbeza. Kedua-dua pemain perlu Update.'}
  }
  Set-CoopProfile $script:LobbyRole $script:LobbyCode
  $cfg=Read-Config
  Set-Node $cfg 'CVars.gRemote.Anchor.LastClientId' $script:LobbyOwnId
  Set-Node $cfg 'CVars.gRemote.Anchor.Host' '127.0.0.1'
  Set-Node $cfg 'CVars.gRemote.Anchor.Port' $script:Lobby.LocalPort
  Set-Node $cfg 'Senz.LobbyMachine' ([Environment]::MachineName)
  Write-Config $cfg
  $script:LobbyReady=$true;$script:LobbyPending=$false
  return $true
 }
 if((Get-Date) -ge $script:LobbyDeadline){throw 'Relay belum mengesahkan bilik. Semak internet dan cuba semula.'}
 return $false
}
function Assert-LobbyReady {
 $cfg=Read-Config
 if((Get-Node $cfg 'CVars.gRemote.Anchor.Enabled' 0) -eq 0){return}
 Read-Lobby
 if(-not $script:LobbyReady -or -not $script:Lobby -or -not $script:Lobby.Connected){throw 'Tekan Create Lobby atau Join by Code dahulu dan tunggu pengesahan.'}
 $online=@($script:LobbyClients|Where-Object{$_.online})
 if($online.Count -gt 2){throw 'Bilik penuh. Cipta bilik baharu.'}
 if($script:LobbyRole -eq 'Ivan' -and @($online|Where-Object{$_.clientId -eq $script:LobbyOwner -and -not $_.self}).Count -ne 1){throw 'Host offline. Tunggu host buka semula bilik.'}
}
