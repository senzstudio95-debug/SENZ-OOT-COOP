$ErrorActionPreference='Stop'
$base=Split-Path $PSScriptRoot -Parent
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $base 'Launcher.ps1'),[ref]$null,[ref]$null)
$names=@('Set-Node','Get-Node','Read-Config','Write-Config','Get-RunningGame','Repair-ControllerMappings','Ensure-KeyboardDefaults','Set-ControlSafety')
foreach($node in $ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$false)){if($node.Name -in $names){. ([scriptblock]::Create($node.Extent.Text))}}
$Root=Join-Path ([IO.Path]::GetTempPath()) ('senz-controller-test-'+[guid]::NewGuid());$Engine=Join-Path $Root 'engine';$ConfigPath=Join-Path $Engine 'shipofharkinian.json';[void][IO.Directory]::CreateDirectory($Engine)
Copy-Item (Join-Path $base 'tests/controller-defaults.json') (Join-Path $Root 'controller-defaults.json')
function Assert($v,$msg){if(-not $v){throw $msg};Write-Host ('PASS '+$msg)}
Repair-ControllerMappings
$c=Read-Config
Assert ((Get-Node $c 'CVars.gSettings.Controllers.Port1.LeftStick.DeadzonePercentage' 0) -eq 30) 'left stick deadzone 30'
Assert ((Get-Node $c 'CVars.gSettings.Controllers.Port1.RightStick.DeadzonePercentage' 0) -eq 30) 'right stick deadzone 30'
Assert ((Get-Node $c 'CVars.gSettings.Controllers.GlobalSDLDeviceSettings.StickAxisThresholdPercentage' 0) -eq 50) 'C-button axis threshold 50'
Assert ((Get-Node $c 'CVars.gSettings.EnableMouse' 1) -eq 0 -and (Get-Node $c 'CVars.gAllowBackgroundInputs' 1) -eq 0) 'mouse and background input disabled'
Set-Node $c 'CVars.gSettings.Controllers.Port1.LeftStick.DeadzonePercentage' 35
Set-Node $c 'CVars.gSettings.Controllers.Port1.Buttons.AButtonMappingIds' 'custom-mapping'
Write-Config $c
Ensure-KeyboardDefaults;$c=Read-Config
Assert ((Get-Node $c 'CVars.gSettings.Controllers.Port1.LeftStick.DeadzonePercentage' 0) -eq 35) 'subsequent Play preserves calibration'
Assert ((Get-Node $c 'CVars.gSettings.Controllers.Port1.Buttons.AButtonMappingIds' '') -eq 'custom-mapping') 'subsequent Play preserves custom mappings'
Set-Node $c 'CVars.gRemote.Anchor.Enabled' 1;Write-Config $c
Set-ControlSafety 40 $true;$c=Read-Config
Assert ((Get-Node $c 'CVars.gWindows.AnchorRoom' 0) -eq 1) 'native coop player panel enabled'
Assert ((Get-Node $c 'CVars.gSettings.Menu.NetworkSidebarSection' -1) -eq 2) 'network sidebar defaults to Anchor'
Set-ControlSafety 40 $false;$c=Read-Config
Assert ((Get-Node $c 'CVars.gWindows.AnchorRoom' 1) -eq 0) 'panel toggle can hide panel'
$invalid=$false;try{Set-ControlSafety 100 $true}catch{$invalid=$true};Assert $invalid 'invalid deadzone rejected'
