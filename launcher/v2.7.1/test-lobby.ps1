$ErrorActionPreference='Stop'
$Root='/tmp/lobby-test-profile';[void][IO.Directory]::CreateDirectory("$Root/engine");$Engine="$Root/engine";$ConfigPath="$Engine/shipofharkinian.json"
Copy-Item '/tmp/senz-v271/SENZ-OOT-SOLO/engine/shipofharkinian.json' $ConfigPath -Force
$a=[System.Management.Automation.Language.Parser]::ParseFile('/tmp/senz-v271/SENZ-OOT-SOLO/Launcher.ps1',[ref]$null,[ref]$null)
$a.FindAll({param($n)$n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in @('Set-Node','Get-Node','Read-Config','Write-Config','Get-RunningGame')},$true)|ForEach-Object{Invoke-Expression $_.Extent.Text}
. '/tmp/senz-v271/SENZ-OOT-SOLO/Coop.ps1'
. '/tmp/senz-v271/SENZ-OOT-SOLO/Lobby.ps1'
$code=New-InviteCode
Open-CoopLobby Host $code '127.0.0.1' 43383
if(-not $script:LobbyReady -or $script:LobbyOwner -ne $script:LobbyOwnId){throw 'host not created'}
$hostSocket=$script:Lobby;$hostId=$script:LobbyOwnId;$script:Lobby=$null
Open-CoopLobby Ivan $code '127.0.0.1' 43383
Assert-LobbyReady
if(@($script:LobbyClients|Where-Object{$_.online}).Count -ne 2){throw 'two players not visible'}
if((Read-Config).CVars.gRemote.Anchor.LastClientId -ne $script:LobbyOwnId){throw 'handoff id not saved'}
$ivanId=$script:LobbyOwnId;$ivanSocket=$script:Lobby;$script:Lobby=$null
try{Open-CoopLobby Ivan $code '127.0.0.1' 43383;throw 'third accepted'}catch{if($_.Exception.Message -eq 'third accepted'){throw};Write-Host 'PASS reject third launcher client'}
try{Open-CoopLobby Ivan (New-InviteCode) '127.0.0.1' 43383;throw 'wrong room accepted'}catch{if($_.Exception.Message -eq 'wrong room accepted'){throw};Write-Host 'PASS reject absent host/wrong room'}
# Reconnect the game using the exact assigned client ID, as the native engine does.
$ivanSocket.Dispose();$game=New-Object SenzLobby;$game.Connect('127.0.0.1',43383)
$p=@{type='HANDSHAKE';clientId=$ivanId;roomId=$code;roomState=@{};clientState=@{name='Ivan';teamId='senz-duo';online=$true;clientVersion='961c151d2e87f2686a955a9be24d316f1362bf21';color=@{r=230;g=35;b=40};isSaveLoaded=$true}}
$game.Send(($p|ConvertTo-Json -Depth 10 -Compress));$script:Lobby=$game;$script:LobbyOwnId=0;$script:LobbyOwner=0
$w=[Diagnostics.Stopwatch]::StartNew();while($w.ElapsedMilliseconds -lt 2000 -and $script:LobbyOwnId -eq 0){Read-Lobby;Start-Sleep -Milliseconds 25}
if($script:LobbyOwnId -ne $ivanId -or $script:LobbyOwner -ne $hostId){throw 'game handoff identity mismatch'}
Write-Host 'PASS actual upstream relay: create room, join 2 clients, owner and team, persisted identity handoff'
$game.Dispose();$hostSocket.Dispose()
