param([switch]$ValidateOnly, [switch]$FunctionsOnly, [switch]$SmokeTest)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Numerics
$Root = $PSScriptRoot
$Engine = Join-Path $Root 'engine'
$ConfigPath = Join-Path $Engine 'shipofharkinian.json'
function Set-Node($Object, [string]$Path, $Value) {
    $Parts = $Path.Split('.')
    for ($i = 0; $i -lt $Parts.Length - 1; $i++) {
        $name = $Parts[$i]
        if (-not $Object.PSObject.Properties[$name]) { $Object | Add-Member -NotePropertyName $name -NotePropertyValue ([pscustomobject]@{}) }
        $Object = $Object.$name
    }
    $Object | Add-Member -NotePropertyName $Parts[-1] -NotePropertyValue $Value -Force
}
function Read-Config {
    if (Test-Path $ConfigPath) { return (Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json) }
    return [pscustomobject]@{ ConfigVersion = 7 }
}
function Get-Node($Object, [string]$Path, $Default) {
    foreach ($name in $Path.Split('.')) {
        if ($null -eq $Object -or -not $Object.PSObject.Properties[$name]) { return $Default }
        $Object = $Object.$name
    }
    return $Object
}
function Write-Config($Config) {
    $json = $Config | ConvertTo-Json -Depth 100
    # LUS distinguishes float and integer CVars. Preserve integral floats too.
    $json = [regex]::Replace($json, '("InternalResolution"\s*:\s*)([12])(?=\s*[,}])', '${1}${2}.0')
    $tmp = $ConfigPath + '.tmp'
    [IO.File]::WriteAllText($tmp, $json, (New-Object Text.UTF8Encoding($false)))
    if (Test-Path $ConfigPath) {
        [IO.File]::Replace($tmp, $ConfigPath, ($ConfigPath + '.bak'))
    } else { [IO.File]::Move($tmp, $ConfigPath) }
}
function Test-GameFiles {
    foreach ($name in @('soh.exe','soh.o2r','oot.z64')) {
        if (-not (Test-Path (Join-Path $Engine $name))) { throw "Fail diperlukan tiada: engine\$name. Jika ini folder baharu, ekstrak pakej lengkap. ZIP kemas kini perlu digabungkan ke folder permainan lama." }
    }
    $hash = (Get-FileHash -LiteralPath (Join-Path $Engine 'oot.z64') -Algorithm SHA1).Hash
    if ($hash -ne 'ad69c91157f6705e8ab06c79fe08aad47bb57ba7') { throw 'ROM berbeza atau rosak. Pakej ini disediakan untuk ROM USA 1.0 yang dimuat naik.' }
}
function Get-RunningGame {
    @(Get-Process -Name soh -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq (Join-Path $Engine 'soh.exe') })
}
function Repair-ControllerMappings([switch]$Force) {
    $cfg=Read-Config
    if (-not $Force -and (Get-Node $cfg 'Senz.ControllerFixVersion' 0) -ge 3) { return }
    if ((Get-RunningGame).Count -gt 0) { throw 'Tutup permainan sebelum pulihkan kawalan.' }
    if (Test-Path $ConfigPath) { Copy-Item -LiteralPath $ConfigPath -Destination ($ConfigPath+'.before-v13-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.bak') }
    $defaults = @'
{
  "Port1": {
    "HasConfig": 1,
    "Buttons": {
      "AButtonMappingIds": "P0-B32768-KB45,P0-B32768-SDLB0,",
      "BButtonMappingIds": "P0-B16384-KB46,P0-B16384-SDLB1,",
      "ZButtonMappingIds": "P0-B8192-KB44,P0-B8192-SDLA4-ADP,",
      "StartButtonMappingIds": "P0-B4096-KB57,P0-B4096-SDLB6,P0-B4096-KB28,",
      "LButtonMappingIds": "P0-B32-KB18,P0-B32-SDLB9,",
      "RButtonMappingIds": "P0-B16-KB19,P0-B16-SDLB10,P0-B16-SDLA5-ADP,",
      "CUpButtonMappingIds": "P0-B8-KB23,P0-B8-SDLA3-ADN,",
      "CDownButtonMappingIds": "P0-B4-KB37,P0-B4-SDLA3-ADP,",
      "CLeftButtonMappingIds": "P0-B2-KB36,P0-B2-SDLA2-ADN,",
      "CRightButtonMappingIds": "P0-B1-KB38,P0-B1-SDLA2-ADP,",
      "DUpButtonMappingIds": "P0-B2048-KB20,P0-B2048-SDLB11,",
      "DDownButtonMappingIds": "P0-B1024-KB34,P0-B1024-SDLB12,",
      "DLeftButtonMappingIds": "P0-B512-KB33,P0-B512-SDLB13,",
      "DRightButtonMappingIds": "P0-B256-KB35,P0-B256-SDLB14,"
    },
    "LeftStick": {
      "LeftAxisDirectionMappingIds": "P0-S0-D0-KB331,P0-S0-D0-SDLA0-ADN,",
      "RightAxisDirectionMappingIds": "P0-S0-D1-KB333,P0-S0-D1-SDLA0-ADP,",
      "UpAxisDirectionMappingIds": "P0-S0-D2-KB328,P0-S0-D2-SDLA1-ADN,",
      "DownAxisDirectionMappingIds": "P0-S0-D3-KB336,P0-S0-D3-SDLA1-ADP,"
    },
    "RightStick": {
      "LeftAxisDirectionMappingIds": "P0-S1-D0-SDLA2-ADN,",
      "RightAxisDirectionMappingIds": "P0-S1-D1-SDLA2-ADP,",
      "UpAxisDirectionMappingIds": "P0-S1-D2-SDLA3-ADN,",
      "DownAxisDirectionMappingIds": "P0-S1-D3-SDLA3-ADP,"
    }
  },
  "ButtonMappings": {
    "P0-B32768-KB45": {
      "ButtonMappingClass": "KeyboardKeyToButtonMapping",
      "Bitmask": 32768,
      "KeyboardScancode": 45
    },
    "P0-B16384-KB46": {
      "ButtonMappingClass": "KeyboardKeyToButtonMapping",
      "Bitmask": 16384,
      "KeyboardScancode": 46
    },
    "P0-B8192-KB44": {
      "ButtonMappingClass": "KeyboardKeyToButtonMapping",
      "Bitmask": 8192,
      "KeyboardScancode": 44
    },
    "P0-B4096-KB57": {
      "ButtonMappingClass": "KeyboardKeyToButtonMapping",
      "Bitmask": 4096,
      "KeyboardScancode": 57
    },
    "P0-B32-KB18": {
      "ButtonMappingClass": "KeyboardKeyToButtonMapping",
      "Bitmask": 32,
      "KeyboardScancode": 18
    },
    "P0-B16-KB19": {
      "ButtonMappingClass": "KeyboardKeyToButtonMapping",
      "Bitmask": 16,
      "KeyboardScancode": 19
    },
    "P0-B8-KB23": {
      "ButtonMappingClass": "KeyboardKeyToButtonMapping",
      "Bitmask": 8,
      "KeyboardScancode": 23
    },
    "P0-B4-KB37": {
      "ButtonMappingClass": "KeyboardKeyToButtonMapping",
      "Bitmask": 4,
      "KeyboardScancode": 37
    },
    "P0-B2-KB36": {
      "ButtonMappingClass": "KeyboardKeyToButtonMapping",
      "Bitmask": 2,
      "KeyboardScancode": 36
    },
    "P0-B1-KB38": {
      "ButtonMappingClass": "KeyboardKeyToButtonMapping",
      "Bitmask": 1,
      "KeyboardScancode": 38
    },
    "P0-B2048-KB20": {
      "ButtonMappingClass": "KeyboardKeyToButtonMapping",
      "Bitmask": 2048,
      "KeyboardScancode": 20
    },
    "P0-B1024-KB34": {
      "ButtonMappingClass": "KeyboardKeyToButtonMapping",
      "Bitmask": 1024,
      "KeyboardScancode": 34
    },
    "P0-B512-KB33": {
      "ButtonMappingClass": "KeyboardKeyToButtonMapping",
      "Bitmask": 512,
      "KeyboardScancode": 33
    },
    "P0-B256-KB35": {
      "ButtonMappingClass": "KeyboardKeyToButtonMapping",
      "Bitmask": 256,
      "KeyboardScancode": 35
    },
    "P0-B32768-SDLB0": {
      "ButtonMappingClass": "SDLButtonToButtonMapping",
      "Bitmask": 32768,
      "SDLControllerButton": 0
    },
    "P0-B16384-SDLB1": {
      "ButtonMappingClass": "SDLButtonToButtonMapping",
      "Bitmask": 16384,
      "SDLControllerButton": 1
    },
    "P0-B32-SDLB9": {
      "ButtonMappingClass": "SDLButtonToButtonMapping",
      "Bitmask": 32,
      "SDLControllerButton": 9
    },
    "P0-B16-SDLB10": {
      "ButtonMappingClass": "SDLButtonToButtonMapping",
      "Bitmask": 16,
      "SDLControllerButton": 10
    },
    "P0-B4096-SDLB6": {
      "ButtonMappingClass": "SDLButtonToButtonMapping",
      "Bitmask": 4096,
      "SDLControllerButton": 6
    },
    "P0-B2048-SDLB11": {
      "ButtonMappingClass": "SDLButtonToButtonMapping",
      "Bitmask": 2048,
      "SDLControllerButton": 11
    },
    "P0-B1024-SDLB12": {
      "ButtonMappingClass": "SDLButtonToButtonMapping",
      "Bitmask": 1024,
      "SDLControllerButton": 12
    },
    "P0-B512-SDLB13": {
      "ButtonMappingClass": "SDLButtonToButtonMapping",
      "Bitmask": 512,
      "SDLControllerButton": 13
    },
    "P0-B256-SDLB14": {
      "ButtonMappingClass": "SDLButtonToButtonMapping",
      "Bitmask": 256,
      "SDLControllerButton": 14
    },
    "P0-B8192-SDLA4-ADP": {
      "ButtonMappingClass": "SDLAxisDirectionToButtonMapping",
      "Bitmask": 8192,
      "SDLControllerAxis": 4,
      "AxisDirection": 1
    },
    "P0-B16-SDLA5-ADP": {
      "ButtonMappingClass": "SDLAxisDirectionToButtonMapping",
      "Bitmask": 16,
      "SDLControllerAxis": 5,
      "AxisDirection": 1
    },
    "P0-B8-SDLA3-ADN": {
      "ButtonMappingClass": "SDLAxisDirectionToButtonMapping",
      "Bitmask": 8,
      "SDLControllerAxis": 3,
      "AxisDirection": -1
    },
    "P0-B4-SDLA3-ADP": {
      "ButtonMappingClass": "SDLAxisDirectionToButtonMapping",
      "Bitmask": 4,
      "SDLControllerAxis": 3,
      "AxisDirection": 1
    },
    "P0-B2-SDLA2-ADN": {
      "ButtonMappingClass": "SDLAxisDirectionToButtonMapping",
      "Bitmask": 2,
      "SDLControllerAxis": 2,
      "AxisDirection": -1
    },
    "P0-B1-SDLA2-ADP": {
      "ButtonMappingClass": "SDLAxisDirectionToButtonMapping",
      "Bitmask": 1,
      "SDLControllerAxis": 2,
      "AxisDirection": 1
    },
    "P0-B4096-KB28": {
      "ButtonMappingClass": "KeyboardKeyToButtonMapping",
      "Bitmask": 4096,
      "KeyboardScancode": 28
    }
  },
  "AxisDirectionMappings": {
    "P0-S0-D0-KB331": {
      "AxisDirectionMappingClass": "KeyboardKeyToAxisDirectionMapping",
      "Stick": 0,
      "Direction": 0,
      "KeyboardScancode": 331
    },
    "P0-S0-D1-KB333": {
      "AxisDirectionMappingClass": "KeyboardKeyToAxisDirectionMapping",
      "Stick": 0,
      "Direction": 1,
      "KeyboardScancode": 333
    },
    "P0-S0-D2-KB328": {
      "AxisDirectionMappingClass": "KeyboardKeyToAxisDirectionMapping",
      "Stick": 0,
      "Direction": 2,
      "KeyboardScancode": 328
    },
    "P0-S0-D3-KB336": {
      "AxisDirectionMappingClass": "KeyboardKeyToAxisDirectionMapping",
      "Stick": 0,
      "Direction": 3,
      "KeyboardScancode": 336
    },
    "P0-S0-D0-SDLA0-ADN": {
      "AxisDirectionMappingClass": "SDLAxisDirectionToAxisDirectionMapping",
      "Stick": 0,
      "Direction": 0,
      "SDLControllerAxis": 0,
      "AxisDirection": -1
    },
    "P0-S0-D1-SDLA0-ADP": {
      "AxisDirectionMappingClass": "SDLAxisDirectionToAxisDirectionMapping",
      "Stick": 0,
      "Direction": 1,
      "SDLControllerAxis": 0,
      "AxisDirection": 1
    },
    "P0-S0-D2-SDLA1-ADN": {
      "AxisDirectionMappingClass": "SDLAxisDirectionToAxisDirectionMapping",
      "Stick": 0,
      "Direction": 2,
      "SDLControllerAxis": 1,
      "AxisDirection": -1
    },
    "P0-S0-D3-SDLA1-ADP": {
      "AxisDirectionMappingClass": "SDLAxisDirectionToAxisDirectionMapping",
      "Stick": 0,
      "Direction": 3,
      "SDLControllerAxis": 1,
      "AxisDirection": 1
    },
    "P0-S1-D0-SDLA2-ADN": {
      "AxisDirectionMappingClass": "SDLAxisDirectionToAxisDirectionMapping",
      "Stick": 1,
      "Direction": 0,
      "SDLControllerAxis": 2,
      "AxisDirection": -1
    },
    "P0-S1-D1-SDLA2-ADP": {
      "AxisDirectionMappingClass": "SDLAxisDirectionToAxisDirectionMapping",
      "Stick": 1,
      "Direction": 1,
      "SDLControllerAxis": 2,
      "AxisDirection": 1
    },
    "P0-S1-D2-SDLA3-ADN": {
      "AxisDirectionMappingClass": "SDLAxisDirectionToAxisDirectionMapping",
      "Stick": 1,
      "Direction": 2,
      "SDLControllerAxis": 3,
      "AxisDirection": -1
    },
    "P0-S1-D3-SDLA3-ADP": {
      "AxisDirectionMappingClass": "SDLAxisDirectionToAxisDirectionMapping",
      "Stick": 1,
      "Direction": 3,
      "SDLControllerAxis": 3,
      "AxisDirection": 1
    }
  }
}

'@ | ConvertFrom-Json
    Set-Node $cfg 'CVars.gSettings.Controllers' $defaults
    Set-Node $cfg 'CVars.gSettings.ControlNav' 0
    Set-Node $cfg 'CVars.gSettings.OpenMenuBar' 0
    Set-Node $cfg 'CVars.gAllowBackgroundInputs' 0
    foreach($stick in @('LeftStick','RightStick')){Set-Node $cfg ('CVars.gSettings.Controllers.Port1.'+$stick+'.DeadzonePercentage') 30;Set-Node $cfg ('CVars.gSettings.Controllers.Port1.'+$stick+'.SensitivityPercentage') 100}
    Set-Node $cfg 'CVars.gSettings.Controllers.GlobalSDLDeviceSettings.StickAxisThresholdPercentage' 50
    Set-Node $cfg 'CVars.gSettings.Controllers.GlobalSDLDeviceSettings.TriggerAxisThresholdPercentage' 30
    foreach($key in @('EnableMouse','AutoCaptureMouse','FreeLook.Enabled')){Set-Node $cfg ('CVars.gSettings.'+$key) 0}
    Set-Node $cfg 'Senz.StickDeadzone' 30
    Set-Node $cfg 'Senz.ControllerFixVersion' 3
    Write-Config $cfg
}
function Apply-Options($res, $full, $backend, $scale, $aa, $fps, $vsync, $mouse) {
    $cfg = Read-Config
    $wh = $res.Split('x')
    Set-Node $cfg 'Window.Width' ([int]$wh[0]); Set-Node $cfg 'Window.Height' ([int]$wh[1])
    Set-Node $cfg 'Window.Fullscreen.Width' ([int]$wh[0]); Set-Node $cfg 'Window.Fullscreen.Height' ([int]$wh[1])
    Set-Node $cfg 'Window.Fullscreen.Enabled' ([bool]$full)
    Set-Node $cfg 'Window.Backend.Id' ([int]$backend)
    Set-Node $cfg 'Window.Backend.Name' (@{1='DirectX 11';2='OpenGL'}[[int]$backend])
    Set-Node $cfg 'CVars.gSettings.InterpolationFPS' ([int]$fps)
    Set-Node $cfg 'CVars.gSettings.MatchRefreshRate' 0
    Set-Node $cfg 'CVars.gSettings.InternalResolution' ([double]$scale)
    Set-Node $cfg 'CVars.gSettings.MSAAValue' ([int]$aa)
    Set-Node $cfg 'CVars.gSettings.VsyncEnabled' ([int][bool]$vsync)
    Set-Node $cfg 'CVars.gSettings.EnableMouse' ([int][bool]$mouse)
    Set-Node $cfg 'CVars.gSettings.AutoCaptureMouse' ([int][bool]$mouse)
    Set-Node $cfg 'CVars.gSettings.FreeLook.Enabled' ([int][bool]$mouse)
    Set-Node $cfg 'CVars.gSettings.AdvancedResolution.Enabled' 0
    Set-Node $cfg 'CVars.gSettings.LowResMode' 0
    Write-Config $cfg
}
function Ensure-KeyboardDefaults {
 # Migrate once; preserve in-game calibration and bindings on subsequent launches.
 Repair-ControllerMappings
}
function Set-ControlSafety([int]$Deadzone) {
 if($Deadzone -lt 10 -or $Deadzone -gt 50){throw 'Deadzone mesti antara 10 hingga 50 peratus.'}
 $cfg=Read-Config
 foreach($stick in @('LeftStick','RightStick')){Set-Node $cfg ('CVars.gSettings.Controllers.Port1.'+$stick+'.DeadzonePercentage') $Deadzone}
 Set-Node $cfg 'CVars.gAllowBackgroundInputs' 0
 Set-Node $cfg 'Senz.StickDeadzone' $Deadzone
 Write-Config $cfg
}
function Set-OfflineMode {
 if ((Get-RunningGame).Count -gt 0) { throw 'Tutup game sebelum ubah tetapan offline.' }
 $cfg=Read-Config
 foreach($service in @('Anchor','Sail','CrowdControl')){
  Set-Node $cfg ('CVars.gRemote.'+$service) ([pscustomobject]@{Enabled=0})
 }
 Set-Node $cfg 'CVars.gWindows.AnchorRoom' 0
 Set-Node $cfg 'Senz.CoopRole' 'Solo'
 Set-Node $cfg 'Senz.ShowCoopPanel' 0
 Write-Config $cfg
}
function Initialize-Offline {
 if ((Get-RunningGame).Count -gt 0) { throw 'Game masih berjalan. Tutup game lama dahulu.' }
 $cfg=Read-Config
 if((Get-Node $cfg 'Senz.OfflineSetupVersion' 0) -lt 1){
  if(Test-Path $ConfigPath){Copy-Item -LiteralPath $ConfigPath -Destination ($ConfigPath+'.before-offline-'+[guid]::NewGuid().ToString('N')+'.bak')}
  Apply-Options '1280x720' $false 1 1.0 1 60 $true $false
  Set-HDTextures $false
  Set-NatureTextures $false 'HD'
  Set-VisualEffects $false $false
  $cfg=Read-Config
  Set-Node $cfg 'Senz.OfflineSetupVersion' 1
  Write-Config $cfg
 }
 Set-OfflineMode
 Repair-ControllerMappings
}
function Reset-SafeMode {
 if ((Get-RunningGame).Count -gt 0) { throw 'Tutup game sebelum pulihkan tetapan.' }
 $backup=Join-Path $Root ('recovery-backups/'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6))
 [void][IO.Directory]::CreateDirectory($backup)
 if(Test-Path $ConfigPath){Move-Item -LiteralPath $ConfigPath -Destination (Join-Path $backup 'shipofharkinian.json')}
 # Keep saves and game assets. All optional mods are retained in the backup.
 $mods=Join-Path $Engine 'mods'
 if(Test-Path $mods){Move-Item -LiteralPath $mods -Destination (Join-Path $backup 'mods')}
 [void][IO.Directory]::CreateDirectory($mods)
 Initialize-Offline
 $cfg=Read-Config
 Set-Node $cfg 'Senz.RecoveryMode' 1
 Write-Config $cfg
 return $backup
}
function Enable-FastMode {
    if ((Get-RunningGame).Count -gt 0) { throw 'Tutup permainan sebelum aktifkan Mod Laju.' }
    $cfg=Read-Config
    Apply-Options '1280x720' ([bool](Get-Node $cfg 'Window.Fullscreen.Enabled' $false)) ([int](Get-Node $cfg 'Window.Backend.Id' 1)) 0.5 1 60 $false ([bool](Get-Node $cfg 'CVars.gSettings.EnableMouse' 1))
    $cfg=Read-Config
    Set-Node $cfg 'Senz.FastModeSetupVersion' 1
    Write-Config $cfg
    Set-HDTextures $false
    Set-VisualEffects $false $false
    Set-NatureTextures ([bool](Get-Node $cfg 'Senz.NatureEnabled' 0)) 'Fast'
}
function Enable-QualityMode([switch]$Ultra) {
    if ((Get-RunningGame).Count -gt 0) { throw 'Tutup permainan sebelum ubah grafik.' }
    $cfg=Read-Config
    $res='1920x1080'; $scale=1.0
    if ($Ultra) { $res='2560x1440'; $scale=1.5 }
    Apply-Options $res ([bool](Get-Node $cfg 'Window.Fullscreen.Enabled' $false)) ([int](Get-Node $cfg 'Window.Backend.Id' 1)) $scale 4 60 $true ([bool](Get-Node $cfg 'CVars.gSettings.EnableMouse' 1))
    $cfg=Read-Config
    Set-Node $cfg 'CVars.gSettings.TextureFilter' 1
    Set-Node $cfg 'Senz.SoloQualitySetupVersion' 1
    Write-Config $cfg
    Set-HDTextures $true
    Set-VisualEffects $false $false
}
function Initialize-SoloQuality {
    if ((Get-Node (Read-Config) 'Senz.SoloQualitySetupVersion' 0) -lt 1) { Enable-QualityMode }
}
function Set-NatureTextures([bool]$enabled, [string]$preset) {
    if ((Get-RunningGame).Count -gt 0) { throw 'Tutup permainan sebelum tukar tekstur.' }
    if ($preset -notin @('HD','Fast')) { throw 'Pilihan tekstur tidak sah.' }
    $source=Join-Path $Root ("textures/Nature-"+$preset+'.pack')
    if ($enabled -and -not (Test-Path -LiteralPath $source -PathType Leaf)) { throw 'Pek tekstur alam tiada. Ekstrak semua kandungan ZIP permainan.' }
    $mods=Join-Path $Engine 'mods'
    $active=Join-Path $mods 'senz-nature.o2r'
    if ($enabled) {
        [void][IO.Directory]::CreateDirectory($mods)
        $tmp=$active+'.tmp'
        Copy-Item -LiteralPath $source -Destination $tmp -Force
        Move-Item -LiteralPath $tmp -Destination $active -Force
    } elseif (Test-Path -LiteralPath $active) {
        # Only remove this package's generated active copy; source packs stay intact.
        Remove-Item -LiteralPath $active
    }
    $cfg=Read-Config
    Set-Node $cfg 'Senz.NatureEnabled' ([int]$enabled)
    Set-Node $cfg 'Senz.NaturePreset' $preset
    if ($enabled) { Set-Node $cfg 'CVars.gSettings.AltAssets' 1 }
    Write-Config $cfg
}
function Set-DialogOptions([bool]$skip, [bool]$instant) {
    if ((Get-RunningGame).Count -gt 0) { throw 'Tutup permainan sebelum ubah tetapan dialog.' }
    $cfg=Read-Config
    Set-Node $cfg 'CVars.gEnhancements.SkipText' ([int]$skip)
    Set-Node $cfg 'CVars.gEnhancements.TextSpeed' $(if($instant){6}else{1})
    Set-Node $cfg 'CVars.gEnhancements.SlowTextSpeed' $(if($instant){5}else{1})
    Set-Node $cfg 'Senz.DialogSetupVersion' 1
    Write-Config $cfg
}
function Set-CutsceneSkip([bool]$enabled) {
    if ((Get-RunningGame).Count -gt 0) { throw 'Tutup permainan sebelum ubah tetapan babak cerita.' }
    $cfg=Read-Config
    foreach($category in @('Intro','Entrances','Story','LearnSong','BossIntro','QuickBossDeaths','OnePoint')) {
        Set-Node $cfg ('CVars.gEnhancements.TimeSavers.SkipCutscene.'+$category) ([int]$enabled)
    }
    Set-Node $cfg 'CVars.gEnhancements.WarpSongSkipAnimation' ([int]$enabled)
    Set-Node $cfg 'Senz.CutsceneSkipEnabled' ([int]$enabled)
    Set-Node $cfg 'Senz.CutsceneSetupVersion' 1
    Write-Config $cfg
}
function Initialize-CutsceneSkip {
    if ((Get-Node (Read-Config) 'Senz.CutsceneSetupVersion' 0) -lt 1) { Set-CutsceneSkip $true }
}
function Initialize-Malay {
    $cfg=Read-Config
    Set-Node $cfg 'CVars.gSettings.Languages' 0
    Write-Config $cfg
}
function Initialize-Dialog {
    if ((Get-Node (Read-Config) 'Senz.DialogSetupVersion' 0) -lt 1) { Set-DialogOptions $true $true }
}
function Initialize-Nature {
    $cfg=Read-Config
    if ((Get-Node $cfg 'Senz.NatureSetupVersion' 0) -lt 1) {
        Set-Node $cfg 'Senz.NatureEnabled' 1; Write-Config $cfg
        Enable-QualityMode
        $cfg=Read-Config; Set-Node $cfg 'Senz.NatureSetupVersion' 1; Write-Config $cfg
    } else {
        Set-NatureTextures ([bool](Get-Node $cfg 'Senz.NatureEnabled' 1)) ([string](Get-Node $cfg 'Senz.NaturePreset' 'HD'))
    }
}
function Set-HDTextures([bool]$enabled) {
    if ((Get-RunningGame).Count -gt 0) { throw 'Tutup permainan sebelum tukar tekstur HD.' }
    $active=Join-Path $Engine 'mods/000-senz-reloaded-hd-ms.o2r'
    $inactive=Join-Path $Engine 'mods-disabled/000-senz-reloaded-hd-ms.o2r'
    if ($enabled) {
        if (-not (Test-Path -LiteralPath $active)) {
            if (-not (Test-Path -LiteralPath $inactive)) { throw 'Pek HD tiada. Ekstrak semua kandungan ZIP lengkap.' }
            [void][IO.Directory]::CreateDirectory((Split-Path $active))
            Move-Item -LiteralPath $inactive -Destination $active
        }
        Set-NatureTextures $false 'HD'
    } elseif (Test-Path -LiteralPath $active) {
        [void][IO.Directory]::CreateDirectory((Split-Path $inactive))
        Move-Item -LiteralPath $active -Destination $inactive -Force
    }
    $cfg=Read-Config
    Set-Node $cfg 'Senz.HDTexturesEnabled' ([int]$enabled)
    if ($enabled) { Set-Node $cfg 'CVars.gSettings.AltAssets' 1 }
    Write-Config $cfg
}
function Set-VisualEffects([bool]$bloom,[bool]$blur) {
    if ((Get-RunningGame).Count -gt 0) { throw 'Tutup permainan sebelum ubah kesan grafik.' }
    $cfg=Read-Config
    $source=Join-Path $Root 'runtime/SENZ-ReShade64.dll'
    $enabled=$bloom -or $blur
    $hash=$null
    if(Test-Path -LiteralPath $source){$hash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash}
    elseif($enabled){throw 'Komponen kesan grafik tiada. Ekstrak ZIP lengkap.'}
    $api=[int](Get-Node $cfg 'Window.Backend.Id' 1)
    $wanted=if ($api -eq 1) { 'dxgi.dll' } else { 'opengl32.dll' }
    foreach ($name in @('dxgi.dll','opengl32.dll')) {
        $target=Join-Path $Engine $name
        if (Test-Path -LiteralPath $target) {
            if (-not $hash -or (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $hash) {
                if($enabled){throw "Fail $name daripada pemasangan lain ditemui. Ia tidak diganti. Gunakan folder pakej baharu."}
                continue
            }
            if (-not $enabled -or $name -ne $wanted) { Remove-Item -LiteralPath $target }
        }
    }
    if ($enabled) {
        $target=Join-Path $Engine $wanted
        if (-not (Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath $source -Destination $target }
    }
    $techniques=@()
    if ($bloom) { $techniques+='SENZBloom@SENZ.fx' }
    if ($blur) { $techniques+='SENZMotionBlur@SENZ.fx' }
    $list=$techniques -join ','
    $preset="Techniques=$list`nTechniqueSorting=SENZBloom@SENZ.fx,SENZMotionBlur@SENZ.fx`n`n[SENZ.fx]`nBloomStrength=0.080000`nBloomThreshold=0.780000`nBlurAmount=0.080000`n"
    [IO.File]::WriteAllText((Join-Path $Engine 'SENZ-Preset.ini'),$preset,(New-Object Text.UTF8Encoding($false)))
    Set-Node $cfg 'Senz.BloomEnabled' ([int]$bloom)
    Set-Node $cfg 'Senz.MotionBlurEnabled' ([int]$blur)
    Set-Node $cfg 'Senz.VisualSetupVersion' 1
    Write-Config $cfg
}
function Initialize-Visual {
    $cfg=Read-Config
    Set-HDTextures ([bool](Get-Node $cfg 'Senz.HDTexturesEnabled' 0))
    Set-VisualEffects ([bool](Get-Node $cfg 'Senz.BloomEnabled' 0)) ([bool](Get-Node $cfg 'Senz.MotionBlurEnabled' 0))
}

if ($FunctionsOnly) { return }
if ($ValidateOnly) { Test-GameFiles; Write-Output 'ROM dan fail enjin berjaya disahkan'; return }
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
[xml]$xaml = Get-Content -LiteralPath (Join-Path $Root 'Launcher.xaml') -Raw
$reader = New-Object System.Xml.XmlNodeReader $xaml
$win = [Windows.Markup.XamlReader]::Load($reader)
try { $win.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([uri](Join-Path $Root 'zelda.ico')) } catch {}
$ui = @{}
foreach ($n in @('Play','Save','Resolution','Mode','Backend','Scale','AA','FPS','Vsync','Mouse','Status','SettingsPanel','Performance','Balanced','Quality','Help','Files','Artwork','Runtime','RepairPad','TestPad','FocusGame','TextureFilter','Ultra','NatureTextures','SkipDialog','InstantDialog','SkipCutscene','HDTextures','Bloom','MotionBlur','RudeDialog','SettingsTabs','NavHome','NavPlay','NavGraphics','NavControls','NavMods','SaveFolder','About','TitleBar','Minimize','Maximize','CloseWindow','UpdateNow','StickDeadzone','RecoverGame')) { $ui[$n] = $win.FindName($n) }
foreach($value in @('15','20','25','30','35','40','45','50')){[void]$ui.StickDeadzone.Items.Add($value)}
function Set-OptionalArtwork($imageControl, [string]$path) {
    # Artwork is cosmetic: missing, unreadable or invalid images must never stop startup.
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return }
    try {
        $bitmap = New-Object Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.CacheOption = [Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.UriSource = [uri]$path
        $bitmap.EndInit()
        $bitmap.Freeze()
        $imageControl.Source = $bitmap
    } catch { $imageControl.Source = $null }
}
Set-OptionalArtwork $ui.Artwork (Join-Path $Root 'reference.png')
function Fill-Combo($name, $items) { foreach ($item in $items) { [void]$ui[$name].Items.Add($item) }; $ui[$name].SelectedIndex=0 }
Fill-Combo 'Resolution' @('960x540','1280x720','1600x900','1920x1080','2560x1440','3840x2160')
Fill-Combo 'Mode' @('Tetingkap','Skrin penuh')
Fill-Combo 'Backend' @('DirectX 11','OpenGL')
Fill-Combo 'Scale' @('0.5','0.75','1.0','1.5','2.0')
Fill-Combo 'AA' @('1','2','4','8')
Fill-Combo 'TextureFilter' @('Licin (bilinear)','Klasik (3 titik)','Tajam (jiran terdekat)')
Fill-Combo 'FPS' @('30','60','120','144')
function Select-Value($name,$value,$fallback) {
    if ($ui[$name].Items.Contains([string]$value)) { $ui[$name].SelectedItem=[string]$value } else { $ui[$name].SelectedItem=[string]$fallback }
}
function Load-Options {
    $cfg = Read-Config
    $ui.StickDeadzone.SelectedItem=[string](Get-Node $cfg 'CVars.gSettings.Controllers.Port1.LeftStick.DeadzonePercentage' 30)
    if($ui.StickDeadzone.SelectedIndex -lt 0){$ui.StickDeadzone.SelectedItem='30'}
    $ui.RudeDialog.IsChecked=[bool](Get-Node $cfg 'Senz.RudeDialogEnabled' 1)
    $w=Get-Node $cfg 'Window.Width' 1280; $h=Get-Node $cfg 'Window.Height' 720
    Select-Value 'Resolution' "${w}x${h}" '1280x720'
    $ui.Mode.SelectedIndex=[int][bool](Get-Node $cfg 'Window.Fullscreen.Enabled' $false)
    $ui.Backend.SelectedIndex=([int](Get-Node $cfg 'Window.Backend.Id' 1))-1
    $sc=([double](Get-Node $cfg 'CVars.gSettings.InternalResolution' 1.0)).ToString('0.0#',[Globalization.CultureInfo]::InvariantCulture)
    Select-Value 'Scale' $sc '1.0'
    Select-Value 'AA' (Get-Node $cfg 'CVars.gSettings.MSAAValue' 1) '1'
    Select-Value 'FPS' (Get-Node $cfg 'CVars.gSettings.InterpolationFPS' 60) '60'
    $ui.Vsync.IsChecked=[bool](Get-Node $cfg 'CVars.gSettings.VsyncEnabled' 1)
    $filter=[int](Get-Node $cfg 'CVars.gSettings.TextureFilter' 1)
    $ui.SkipCutscene.IsChecked=[bool](Get-Node $cfg 'Senz.CutsceneSkipEnabled' 1)
    $ui.SkipDialog.IsChecked=[bool](Get-Node $cfg 'CVars.gEnhancements.SkipText' 1)
    $ui.InstantDialog.IsChecked=((Get-Node $cfg 'CVars.gEnhancements.TextSpeed' 6) -eq 6)
    $ui.HDTextures.IsChecked=[bool](Get-Node $cfg 'Senz.HDTexturesEnabled' 0)
    $ui.Bloom.IsChecked=[bool](Get-Node $cfg 'Senz.BloomEnabled' 0)
    $ui.MotionBlur.IsChecked=[bool](Get-Node $cfg 'Senz.MotionBlurEnabled' 0)
    $ui.NatureTextures.IsEnabled=-not $ui.HDTextures.IsChecked
    $ui.NatureTextures.IsChecked=[bool](Get-Node $cfg 'Senz.NatureEnabled' 1)
    $ui.TextureFilter.SelectedIndex=@{1=0;0=1;2=2}[$filter]
    $ui.Mouse.IsChecked=[bool](Get-Node $cfg 'CVars.gSettings.EnableMouse' 1)
}
function Set-RudeDialog([bool]$enabled) {
    if ((Get-RunningGame).Count -gt 0) { throw 'Tutup game sebelum tukar pek dialog.' }
    $cfg=Read-Config
    $person='Sen'
    $style=if($enabled){'kasar'}else{'standard'}
    $name="senz-$style-$person.o2r"
    $src=Join-Path $Root ('language-backup/'+$name)
    if(-not(Test-Path $src)){throw 'Fail pek dialog tidak lengkap. Ekstrak pakej penuh.'}
    $target=Join-Path $Engine 'mods/senz-bahasa-melayu-preview.o2r'
    $tmp=$target+'.tmp'
    Copy-Item -LiteralPath $src -Destination $tmp -Force
    if(Test-Path $target){[IO.File]::Replace($tmp,$target,(Join-Path $Root 'language-backup/last-active.o2r'))}else{[IO.File]::Move($tmp,$target)}
    $cfg=Read-Config;Set-Node $cfg 'Senz.RudeDialogEnabled' ([int]$enabled);Write-Config $cfg
}
function Save-Options {
    if ((Get-RunningGame).Count -gt 0) { throw 'Tutup permainan sebelum ubah tetapan pelancar.' }
    if(-not (Get-Node (Read-Config) 'Senz.RecoveryMode' 0)){Set-RudeDialog ([bool]$ui.RudeDialog.IsChecked)}
    Set-CutsceneSkip ([bool]$ui.SkipCutscene.IsChecked)
    Set-DialogOptions ([bool]$ui.SkipDialog.IsChecked) ([bool]$ui.InstantDialog.IsChecked)
    Apply-Options $ui.Resolution.SelectedItem ($ui.Mode.SelectedIndex -eq 1) ($ui.Backend.SelectedIndex+1) ([double]::Parse($ui.Scale.SelectedItem,[Globalization.CultureInfo]::InvariantCulture)) $ui.AA.SelectedItem $ui.FPS.SelectedItem $ui.Vsync.IsChecked $ui.Mouse.IsChecked
    $cfg=Read-Config; Set-Node $cfg 'CVars.gSettings.TextureFilter' (@(1,0,2)[$ui.TextureFilter.SelectedIndex]); Write-Config $cfg
    Set-HDTextures ([bool]$ui.HDTextures.IsChecked)
    Set-VisualEffects ([bool]$ui.Bloom.IsChecked) ([bool]$ui.MotionBlur.IsChecked)
    Set-NatureTextures ([bool]($ui.NatureTextures.IsChecked -and -not $ui.HDTextures.IsChecked)) ([string](Get-Node $cfg 'Senz.NaturePreset' 'HD'))
    Set-ControlSafety ([int]$ui.StickDeadzone.SelectedItem)
}
function Show-Error($err) {
    if($SmokeTest){throw $err}
    $ui.Status.Text=$err.Exception.Message
    [void][Windows.MessageBox]::Show($win, $err.Exception.Message, 'Pelancar SENZ', 'OK', 'Error')
}
$ui.HDTextures.Add_Checked({ $ui.NatureTextures.IsChecked=$false; $ui.NatureTextures.IsEnabled=$false })
$ui.HDTextures.Add_Unchecked({ $ui.NatureTextures.IsEnabled=$true })
$ui.Save.Add_Click({ try { Save-Options; Load-Options; $ui.Status.Text='Tetapan disimpan. Tekan MAIN OFFLINE untuk mula.' } catch { Show-Error $_ } })
$ui.Play.Add_Click({
    try {
        if ((Get-RunningGame).Count -gt 0) { throw 'Permainan sedang berjalan. Gunakan Alt+Tab untuk kembali.' }
        Test-GameFiles
        Set-OfflineMode; Ensure-KeyboardDefaults
        $script:game = Start-Process -FilePath (Join-Path $Engine 'soh.exe') -WorkingDirectory $Engine -PassThru
        $script:wasRunning=$true
        $ui.Status.Text='Permainan dibuka. Sahkan pengekstrakan ROM jika diminta. F2 = tetikus, F11 = skrin penuh.'
        $ui.Play.IsEnabled=$false; $ui.SettingsPanel.IsEnabled=$false
    } catch { Show-Error $_ }
})
$ui.Performance.Add_Click({ try { Enable-FastMode; Load-Options; $ui.Status.Text='MOD LAJU: HD dan kesan tambahan ditutup; 720p, skala 50%, sasaran 60 FPS.' } catch { Show-Error $_ } })
$ui.Balanced.Add_Click({ $ui.Resolution.SelectedItem='1280x720';$ui.Scale.SelectedItem='1.0';$ui.AA.SelectedItem='2';$ui.FPS.SelectedItem='60';$ui.Status.Text='Pilihan Seimbang dipilih. Tekan Simpan Tetapan atau Main Offline.' })
$ui.Quality.Add_Click({ try { Enable-QualityMode; Load-Options; $ui.Status.Text='KUALITI: pek HD aktif; kesan tambahan ditutup; 1080p, MSAA 4x, sasaran 60 FPS.' } catch { Show-Error $_ } })
$ui.Ultra.Add_Click({ try { Enable-QualityMode -Ultra; Load-Options; $ui.Status.Text='ULTRA aktif: 1440p, skala 150%, MSAA 4x. Beban GPU lebih tinggi.' } catch { Show-Error $_ } })
$ui.Help.Add_Click({ Start-Process notepad.exe -ArgumentList ('"' + (Join-Path $Root 'BACA-DULU.txt') + '"') })
$ui.RepairPad.Add_Click({ try { Repair-ControllerMappings -Force; Load-Options; $ui.Status.Text='Kawalan dipulihkan; deadzone 30%, kamera tetikus dimatikan. Tetapan lama dibackup.' } catch { Show-Error $_ } })
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class SenzFocus {
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
 [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h,int n);
 [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 public static bool Resume(IntPtr h) {
  if(h==IntPtr.Zero) return false;
  ShowWindow(h,9); bool ok=SetForegroundWindow(h);
  RECT r; if(GetClientRect(h,out r) && r.Bottom>80) {
   int p=((r.Bottom-35)<<16)|20;
   PostMessage(h,0x200,IntPtr.Zero,(IntPtr)p);
   PostMessage(h,0x201,(IntPtr)1,(IntPtr)p);
   PostMessage(h,0x202,IntPtr.Zero,(IntPtr)p);
  }
  return ok;
 }
}
'@
$ui.FocusGame.Add_Click({ try {
    $games=Get-RunningGame
    if ($games.Count -eq 0) { throw 'Buka permainan dahulu.' }
    if (-not [SenzFocus]::Resume($games[0].MainWindowHandle)) { throw 'Windows belum beri fokus. Klik dunia permainan di luar menu.' }
    $ui.Status.Text='Fokus dikembalikan. Tekan Enter / Space / Start. Tutup menu tetapan untuk sambung bermain.'
} catch { Show-Error $_ } })
$ui.TestPad.Add_Click({ Start-Process 'control.exe' -ArgumentList 'joy.cpl' })
$ui.Runtime.Add_Click({ try {
    $installer = Join-Path $Root 'runtime/VC_redist.x64.exe'
    if (Test-Path $installer) { Start-Process -FilePath $installer } else { Start-Process 'https://aka.ms/vc14/vc_redist.x64.exe' }
} catch { Show-Error $_ } })
$ui.Files.Add_Click({ Start-Process explorer.exe -ArgumentList ('"' + $Engine + '"') })
$ui.RecoverGame.Add_Click({try{
 if([Windows.MessageBox]::Show($win,'Pulihkan tetapan asas dan asingkan semua mod? Save game dikekalkan; mod dan tetapan lama disimpan dalam recovery-backups. Bahasa mod juga akan dimatikan sementara.','Pulihkan game','YesNo','Question') -ne 'Yes'){return}
 $backup=Reset-SafeMode
 Test-GameFiles; Load-Options; $script:startupReady=$true
 $ui.Status.Text='Pemulihan siap. Tekan MAIN OFFLINE. Backup: '+$backup
}catch{Show-Error $_}})
$ui.UpdateNow.Add_Click({
 try {
  if((Get-RunningGame).Count -gt 0){throw 'Tutup game dahulu sebelum Update.'}
  $work=Join-Path ([IO.Path]::GetTempPath()) ('SenzUpdater-'+[guid]::NewGuid().ToString('N'))
  [void][IO.Directory]::CreateDirectory($work)
  foreach($file in @('Updater.ps1','UpdateCore.ps1')){Copy-Item -LiteralPath (Join-Path $Root $file) -Destination (Join-Path $work $file)}
  $args='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $work 'Updater.ps1')+'" -InstallRoot "'+$Root+'" -LauncherPid '+$PID
  Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $args -WorkingDirectory $work
  $win.Close()
 }catch{Show-Error $_}
})
$ui.NavHome.Add_Click({$ui.SettingsTabs.SelectedIndex=0})
$ui.NavGraphics.Add_Click({$ui.SettingsTabs.SelectedIndex=0})
$ui.NavControls.Add_Click({$ui.SettingsTabs.SelectedIndex=1})
$ui.NavMods.Add_Click({$ui.SettingsTabs.SelectedIndex=2})
$ui.NavPlay.Add_Click({if($ui.Play.IsEnabled){$ui.Play.RaiseEvent(([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)))}})
$ui.SaveFolder.Add_Click({try{$p=Join-Path $Engine 'Save';[void][IO.Directory]::CreateDirectory($p);Start-Process explorer.exe -ArgumentList ('"'+$p+'"')}catch{Show-Error $_}})
$ui.About.Add_Click({[void][Windows.MessageBox]::Show($win,'SENZ Zelda v2.8.0-offline — Solo, Bahasa Melayu. Enjin Ship of Harkinian 9.3.1. Reka bentuk mengikut rujukan Sen. Pek dialog kasar: 35 dialog disunting.','Tentang SENZ','OK','Information')})
$ui.Minimize.Add_Click({$win.WindowState='Minimized'})
$ui.Maximize.Add_Click({if($win.WindowState -eq 'Maximized'){$win.WindowState='Normal'}else{$win.WindowState='Maximized'}})
$ui.CloseWindow.Add_Click({$win.Close()})
$ui.TitleBar.Add_MouseLeftButtonDown({if($_.ClickCount -eq 2){if($win.WindowState -eq 'Maximized'){$win.WindowState='Normal'}else{$win.WindowState='Maximized'}}else{$win.DragMove()}})
$script:wasRunning=$false
$script:focusPid=0; $script:focusDue=$null; $script:focusDone=$false
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval=[TimeSpan]::FromMilliseconds(250)
$timer.Add_Tick({
    $games=Get-RunningGame
    if ($games.Count -gt 0) {
        $g=$games[0]
        if ($script:focusPid -ne $g.Id) { $script:focusPid=$g.Id; $script:focusDue=(Get-Date).AddSeconds(4); $script:focusDone=$false }
        if (-not $script:focusDone -and (Get-Date) -ge $script:focusDue -and $g.MainWindowHandle -ne [IntPtr]::Zero) {
            [void][SenzFocus]::Resume($g.MainWindowHandle); $script:focusDone=$true
        }
    } else { $script:focusPid=0 }
    $running=((Get-RunningGame).Count -gt 0)
    $ui.UpdateNow.IsEnabled=-not $running
    $ui.RecoverGame.IsEnabled=-not $running
    $ui.SettingsPanel.IsEnabled=(-not $running -and $script:startupReady)
    $canPlay=(-not $running -and $script:startupReady)
    $ui.Play.IsEnabled=$canPlay; $ui.SettingsTabs.IsEnabled=(-not $running -and $script:startupReady); $ui.Save.IsEnabled=(-not $running -and $script:startupReady); $ui.NavPlay.IsEnabled=$canPlay
    if ($script:wasRunning -and -not $running) {
        try { Load-Options; $ui.Status.Text='Permainan ditutup. Tetapan dimuat semula. Jika gagal, semak engine\logs dan BACA-DULU.txt.' } catch { Show-Error $_ }
    }
    $script:wasRunning=$running
})
$win.Add_Closing({
 param($sender,$closingEvent)
 $games=@(Get-RunningGame)
 if($games.Count -gt 0){
  $choice=[Windows.MessageBox]::Show($win,'Tutup game dan keluar launcher? Progress yang belum disimpan boleh hilang. Pilih No untuk terus bermain.','Keluar SENZ','YesNo','Warning')
  if($choice -ne 'Yes'){$closingEvent.Cancel=$true;return}
  foreach($gameProcess in $games){
   try {
    [void]$gameProcess.CloseMainWindow()
    if(-not $gameProcess.WaitForExit(5000)){
     $force=[Windows.MessageBox]::Show($win,'Game tidak memberi respons. Paksa tutup game ini? Progress yang belum disimpan akan hilang.','Game masih berjalan','YesNo','Warning')
     if($force -ne 'Yes'){$closingEvent.Cancel=$true;return}
     # The process object was selected by exact executable path in this install.
     $gameProcess.Kill();[void]$gameProcess.WaitForExit(3000)
    }
   }catch{$closingEvent.Cancel=$true;Show-Error $_;return}
  }
 }
})
$win.Add_Closed({ $timer.Stop() })
$script:startupReady=$false
try {
 Test-GameFiles; Initialize-Offline; Load-Options
 $script:startupReady=$true
 $ui.Status.Text='SENZ v2.8.0 | Offline sahaja | Tetapan grafik asas | Tekan Simpan selepas ubah pilihan.'
} catch { Show-Error $_; $ui.Play.IsEnabled=$false }
if($SmokeTest){if(-not $script:startupReady){throw 'Startup smoke test failed'};$win.Close();return}
$timer.Start()
try { [void]$win.ShowDialog() }
finally {
 $timer.Stop()
 # Exit the PowerShell host after the launcher closes.
 [Environment]::Exit(0)
}

