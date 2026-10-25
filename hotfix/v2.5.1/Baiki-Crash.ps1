param([string]$GameRoot=$PSScriptRoot,[switch]$Force)
$ErrorActionPreference='Stop'
$Engine=Join-Path $GameRoot 'engine'
$Payload=Join-Path $PSScriptRoot 'hotfix-v2.5.1'
$ConfigPath=Join-Path $Engine 'shipofharkinian.json'
$OriginalHash='53c5d5621431c6009755c96c15efab93611cd0a7ffea06990c56641f21171633'
$V250Hash='8b62c98edf3fc33de7ef56b23e280b93bc54c929948e893809c5c9f3d279c541'
$EffectsHash='62a099e37610953ecb5bf2333965165596d40eab5b993a1c6526dfbd94e35efd'
function Hash($p) { (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant() }
function Set-Node($o,[string]$path,$v) {
 $parts=$path.Split('.')
 for($i=0;$i -lt $parts.Length-1;$i++) {
  $k=$parts[$i]
  if(-not $o.PSObject.Properties[$k] -or $null -eq $o.$k){$o|Add-Member -NotePropertyName $k -NotePropertyValue ([pscustomobject]@{}) -Force}
  $o=$o.$k
 }
 $o|Add-Member -NotePropertyName $parts[-1] -NotePropertyValue $v -Force
}
function Get-Node($o,[string]$path,$fallback) {
 foreach($k in $path.Split('.')) {if($null -eq $o -or -not $o.PSObject.Properties[$k]){return $fallback};$o=$o.$k};return $o
}
if(-not(Test-Path "$Engine/oot.z64") -or -not(Test-Path "$GameRoot/START-SENZ.cmd")) {
 throw 'Ekstrak hotfix ini DALAM folder SENZ-OOT-SOLO yang mengandungi START-SENZ.cmd dan folder engine, kemudian jalankan BAIKI-CRASH.cmd.'
}
if(@(Get-Process soh -ErrorAction SilentlyContinue).Count -gt 0){throw 'Tutup game dan tetingkap Crash dahulu, kemudian cuba lagi.'}
foreach($n in @('soh.exe','Launcher.ps1','Launcher.xaml')){if(-not(Test-Path "$Payload/$n")){throw "Fail hotfix tidak lengkap: $n"}}
if((Hash "$Payload/soh.exe") -ne $OriginalHash){throw 'Enjin pemulihan rosak. Muat turun semula hotfix.'}
$current=Hash "$Engine/soh.exe"
if($current -notin @($OriginalHash,$V250Hash)){throw 'Enjin ini bukan versi v2.5.0 yang disokong. Tiada fail diubah.'}
foreach($n in @('dxgi.dll','opengl32.dll')) {
 if((Test-Path "$Engine/$n") -and (Hash "$Engine/$n") -ne $EffectsHash){throw "DLL lain ditemui: $n. Tiada fail diubah; gunakan folder SENZ v2.5.0 asal."}
}
$cfg=[pscustomobject]@{ConfigVersion=7}
if(Test-Path $ConfigPath){try{$cfg=Get-Content -Raw -LiteralPath $ConfigPath|ConvertFrom-Json}catch{Write-Host 'Tetapan tidak boleh dibaca; salinan asal akan disimpan sebelum tetapan asas dipulihkan.'}}
if(-not $Force -and (Get-Node $cfg 'Senz.CrashRecoveryVersion' 0) -eq 251 -and $current -eq $OriginalHash){Write-Host 'Hotfix v2.5.1 sudah dipasang.';return}
$backup=Join-Path $GameRoot ('backup-crash-v251-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6))
[void][IO.Directory]::CreateDirectory($backup)
$backed=@();$moved=@();$created=@()
function Backup-File([string]$relative) {
 $p=Join-Path $GameRoot $relative
 if(Test-Path -LiteralPath $p){$dest=Join-Path $backup $relative;[void][IO.Directory]::CreateDirectory((Split-Path $dest));Copy-Item -LiteralPath $p -Destination $dest;$script:backed+=$relative}
 else{$script:created+=$relative}
}
function Park-File([string]$relative,[string]$destination) {
 $p=Join-Path $GameRoot $relative
 if(Test-Path -LiteralPath $p) {
  if(Test-Path -LiteralPath $destination){$destination=Join-Path $backup $relative}
  [void][IO.Directory]::CreateDirectory((Split-Path $destination))
  Move-Item -LiteralPath $p -Destination $destination
  $script:moved+=@{From=$p;To=$destination}
 }
}
try {
 foreach($r in @('engine/soh.exe','engine/shipofharkinian.json','Launcher.ps1','Launcher.xaml')){Backup-File $r}
 foreach($n in @('dxgi.dll','opengl32.dll','oot.o2r','oot-mq.o2r')){Park-File ('engine/'+$n) (Join-Path $backup ('engine/'+$n))}
 foreach($n in @('000-senz-reloaded-hd-ms.o2r','senz-nature.o2r')){Park-File ('engine/mods/'+$n) (Join-Path $Engine ('mods-disabled/'+$n))}
 Copy-Item -LiteralPath "$Payload/soh.exe" -Destination "$Engine/soh.exe" -Force
 Copy-Item -LiteralPath "$Payload/Launcher.ps1" -Destination "$GameRoot/Launcher.ps1" -Force
 Copy-Item -LiteralPath "$Payload/Launcher.xaml" -Destination "$GameRoot/Launcher.xaml" -Force
 foreach($k in @('HDTexturesEnabled','BloomEnabled','MotionBlurEnabled','NatureEnabled')){Set-Node $cfg ('Senz.'+$k) 0}
 foreach($k in @('SoloQualitySetupVersion','VisualSetupVersion','NatureSetupVersion')){Set-Node $cfg ('Senz.'+$k) 1}
 Set-Node $cfg 'Senz.CrashRecoveryVersion' 251
 Set-Node $cfg 'Senz.NaturePreset' 'HD'
 Set-Node $cfg 'Window.Backend.Id' 1
 Set-Node $cfg 'Window.Backend.Name' 'DirectX 11'
 Set-Node $cfg 'Window.Width' 1280;Set-Node $cfg 'Window.Height' 720
 Set-Node $cfg 'Window.Fullscreen.Enabled' $false
 Set-Node $cfg 'CVars.gSettings.InternalResolution' ([double]1.0)
 Set-Node $cfg 'CVars.gSettings.MSAAValue' 1
 Set-Node $cfg 'CVars.gSettings.InterpolationFPS' 60
 Set-Node $cfg 'CVars.gSettings.MatchRefreshRate' 0
 Set-Node $cfg 'CVars.gSettings.VsyncEnabled' 1
 Set-Node $cfg 'CVars.gSettings.AdvancedResolution.Enabled' 0
 Set-Node $cfg 'CVars.gSettings.LowResMode' 0
 Set-Node $cfg 'CVars.gSettings.AltAssets' 1
 Set-Node $cfg 'CVars.gSettings.Languages' 0
 Set-Node $cfg 'CVars.gSettings.OpenMenuBar' 0
 Set-Node $cfg 'CVars.gSettings.Menu' ([pscustomobject]@{})
 $json=$cfg|ConvertTo-Json -Depth 100
 $json=[regex]::Replace($json,'("InternalResolution"\s*:\s*)([12])(?=\s*[,}])','${1}${2}.0')
 [IO.File]::WriteAllText($ConfigPath,$json,(New-Object Text.UTF8Encoding($false)))
 if((Hash "$Engine/soh.exe") -ne $OriginalHash){throw 'Semakan enjin selepas pemasangan gagal.'}
 [IO.File]::WriteAllText((Join-Path $backup 'recovery.json'),(@{Version='2.5.1';BackedUp=$backed;Moved=$moved}|ConvertTo-Json -Depth 8))
 Write-Host "Hotfix siap. Backup: $backup"
 Write-Host 'Save dan pek dialog BM dikekalkan. HD disimpan tetapi dimatikan. Enjin akan mengekstrak semula aset ROM pada pembukaan pertama.'
} catch {
 $failure=$_
 foreach($r in $backed){Copy-Item -LiteralPath (Join-Path $backup $r) -Destination (Join-Path $GameRoot $r) -Force}
 foreach($r in $created){$p=Join-Path $GameRoot $r;if(Test-Path $p){Remove-Item -LiteralPath $p -Force}}
 foreach($m in $moved){if(Test-Path -LiteralPath $m.To){Move-Item -LiteralPath $m.To -Destination $m.From -Force}}
 throw $failure
}
