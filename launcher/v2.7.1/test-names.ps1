$ErrorActionPreference='Stop'
$Root='/tmp/senz-v271/SENZ-OOT-SOLO';$Engine="$Root/engine";$ConfigPath="$Engine/shipofharkinian.json"
$e=$null;$a=[System.Management.Automation.Language.Parser]::ParseFile("$Root/Launcher.ps1",[ref]$null,[ref]$e);if($e.Count){throw $e}
$a.FindAll({param($n)$n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in @('Set-Node','Get-Node','Read-Config','Write-Config','Get-RunningGame','Set-RudeDialog')},$true)|ForEach-Object{Invoke-Expression $_.Extent.Text}
foreach($role in @('Host','Ivan','Solo')){foreach($enabled in @($false,$true)){
$c=Read-Config;Set-Node $c 'Senz.CoopRole' $role;Write-Config $c;Set-RudeDialog $enabled
$name=if($role -eq 'Ivan'){'Ivan'}else{'Sen'};$style=if($enabled){'kasar'}else{'standard'}
if((Get-FileHash "$Engine/mods/senz-bahasa-melayu-preview.o2r").Hash -ne (Get-FileHash "$Root/language-backup/senz-$style-$name.o2r").Hash){throw 'name mismatch'}
}}
'PASS 6 role/style combinations, syntax, name packs selected correctly'
