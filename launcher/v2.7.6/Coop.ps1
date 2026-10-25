function New-InviteCode {
 $bytes=New-Object byte[] 8
 $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
 try{$rng.GetBytes($bytes)}finally{$rng.Dispose()}
 return 'SENZ-'+([BitConverter]::ToString($bytes).Replace('-',''))
}
function Set-CoopProfile([string]$Role,[string]$Code) {
 if((Get-RunningGame).Count -gt 0){throw 'Tutup game dahulu sebelum menukar sesi.'}
 $Code=$Code.Trim().ToUpperInvariant()
 if($Role -notin @('Host','Ivan','Solo')){throw 'Peranan tidak sah.'}
 if($Role -ne 'Solo' -and $Code -notmatch '^SENZ-[0-9A-F]{16}$'){throw 'Kod mesti SENZ- diikuti 16 aksara. Salin kod penuh daripada host.'}
 $cfg=Read-Config
 if($Role -ne 'Solo'){
  # Preserve local saves before any session can merge progress through Anchor.
  $save=Join-Path $Engine 'Save'
  if(Test-Path $save){$backup=Join-Path $Root ('save-backup-coop-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6));Copy-Item -LiteralPath $save -Destination $backup -Recurse}
  $name=if($Role -eq 'Ivan'){'Ivan'}else{'Sen'}
  $color=if($Role -eq 'Ivan'){[pscustomobject]@{Type='RGBA';R=230;G=35;B=40;A=255}}else{[pscustomobject]@{Type='RGBA';R=45;G=180;B=65;A=255}}
  Set-Node $cfg 'CVars.gRemote.Anchor.Host' 'iriguchi.proxy.rlwy.net'
  Set-Node $cfg 'CVars.gRemote.Anchor.Port' 51417
  Set-Node $cfg 'CVars.gRemote.Anchor.RoomId' $Code
  Set-Node $cfg 'CVars.gRemote.Anchor.TeamId' 'senz-duo'
  Set-Node $cfg 'CVars.gRemote.Anchor.Name' $name
  Set-Node $cfg 'CVars.gRemote.Anchor.Color.Value' $color
  Set-Node $cfg 'CVars.gRemote.Anchor.RoomSettings.SyncItemsAndFlags' 1
  Set-Node $cfg 'CVars.gRemote.Anchor.RoomSettings.PvpMode' 0
  Set-Node $cfg 'CVars.gRemote.Anchor.RoomSettings.TeleportMode' 1
  Set-Node $cfg 'CVars.gRemote.Anchor.RoomSettings.ShowLocationsMode' 1
 }
 Set-Node $cfg 'CVars.gRemote.Anchor.Enabled' ([int]($Role -ne 'Solo'))
 Set-Node $cfg 'Senz.CoopRole' $Role
 Set-Node $cfg 'CVars.gWindows.AnchorRoom' ([int]($Role -ne 'Solo' -and [bool](Get-Node $cfg 'Senz.ShowCoopPanel' 1)))
 Set-Node $cfg 'CVars.gSettings.Menu.NetworkSidebarSection' 2
 Write-Config $cfg
}
