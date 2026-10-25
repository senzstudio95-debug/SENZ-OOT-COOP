$ErrorActionPreference='Stop'
$source=Join-Path $PSScriptRoot 'Launcher.ps1'
$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
. $source -FunctionsOnly
$Root=Join-Path ([IO.Path]::GetTempPath()) ('senz-offline-test-'+[guid]::NewGuid().ToString('N'))
$Engine=Join-Path $Root 'engine';$ConfigPath=Join-Path $Engine 'shipofharkinian.json'
[void][IO.Directory]::CreateDirectory((Join-Path $Engine 'Save'))
[IO.File]::WriteAllText((Join-Path $Engine 'Save/slot1.sav'),'preserve-save')
function Get-RunningGame { @() }
try {
 $cfg=[pscustomobject]@{ConfigVersion=7}
 Set-Node $cfg 'CVars.gRemote.Anchor.Enabled' 1
 Set-Node $cfg 'CVars.gRemote.Anchor.Host' 'stale-server'
 Set-Node $cfg 'CVars.gRemote.Anchor.RoomId' 'stale-room'
 Set-Node $cfg 'CVars.gWindows.AnchorRoom' 1
 Write-Config $cfg
 Initialize-Offline
 $cfg=Read-Config
 if((Get-Node $cfg 'CVars.gRemote.Anchor.Enabled' 1) -ne 0){throw 'Online still enabled'}
 if(Get-Node $cfg 'CVars.gRemote.Anchor.Host' ''){throw 'Stale relay retained'}
 if((Get-Node $cfg 'CVars.gWindows.AnchorRoom' 1) -ne 0){throw 'Online panel remains'}
 if((Get-Node $cfg 'Window.Width' 0) -ne 1280){throw 'Safe resolution missing'}
 if((Get-Node $cfg 'Senz.HDTexturesEnabled' 1) -ne 0){throw 'HD still enabled'}
 Write-Host 'PASS: old online config migrates offline without optional asset files'
 Set-Node $cfg 'CVars.gSettings.Controllers.Port1.LeftStick.DeadzonePercentage' 40
 Write-Config $cfg
 Initialize-Offline
 if((Get-Node (Read-Config) 'CVars.gSettings.Controllers.Port1.LeftStick.DeadzonePercentage' 0) -ne 40){throw 'User calibration lost'}
 Write-Host 'PASS: subsequent launches preserve controller calibration'
 [void][IO.Directory]::CreateDirectory((Join-Path $Engine 'mods'))
 [IO.File]::WriteAllText((Join-Path $Engine 'mods/test.o2r'),'mod-original')
 [IO.File]::WriteAllText($ConfigPath,'corrupted json')
 $backup=Reset-SafeMode
 if((Get-Content -LiteralPath (Join-Path $backup 'shipofharkinian.json') -Raw) -ne 'corrupted json'){throw 'Config backup missing'}
 if((Get-Content -LiteralPath (Join-Path $backup 'mods/test.o2r') -Raw) -ne 'mod-original'){throw 'Mod backup missing'}
 if((Get-Content -LiteralPath (Join-Path $Engine 'Save/slot1.sav') -Raw) -ne 'preserve-save'){throw 'Save modified'}
 if((Get-Node (Read-Config) 'Senz.RecoveryMode' 0) -ne 1){throw 'Recovery not activated'}
 Write-Host 'PASS: damaged config recovery preserves saves and backs up all mods'
 $text=Get-Content -LiteralPath $source -Raw
 if($text -match 'Begin-CoopLobby|Assert-LobbyReady|TcpClient|Close-Lobby|LobbyBridge'){throw 'Runtime relay dependency remains'}
 [xml]$xaml=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Launcher.xaml') -Raw
 if($xaml.OuterXml -match 'CreateRoom|JoinRoom|InviteCode|ShowCoopPanel|LobbyStatus'){throw 'Online UI remains'}
 Write-Host 'PASS: no launcher online controls or relay dependency'
} finally {Remove-Item -LiteralPath $Root -Recurse -Force}
