$ErrorActionPreference='Stop'
$base=Split-Path $PSScriptRoot -Parent
. (Join-Path $base 'SENZ-Tutup-Proses.ps1') -FunctionsOnly
function Assert($yes,$message){if(-not $yes){throw $message};Write-Host ('PASS '+$message)}
$root=Join-Path ([IO.Path]::GetTempPath()) 'Senz Test'
$p=[pscustomobject]@{Name='powershell.exe';ExecutablePath='';CommandLine='powershell.exe -File "'+(Join-Path $root 'Launcher.ps1')+'"'}
Assert (Test-SenzOwnedProcess $p $root) 'select launcher belonging to exact folder'
Assert (-not (Test-SenzOwnedProcess $p ($root+'Other'))) 'exclude similarly named folder'
$p.CommandLine='powershell.exe -File "'+(Join-Path $root 'OtherScript.ps1')+'"'
Assert (-not (Test-SenzOwnedProcess $p $root)) 'exclude unrelated PowerShell script'
$p.Name='explorer.exe';$p.ExecutablePath=Join-Path $root 'explorer.exe'
Assert (-not (Test-SenzOwnedProcess $p $root)) 'exclude Explorer and arbitrary executable'
$p.Name='soh.exe';$p.ExecutablePath=Join-Path $root 'engine/soh.exe'
Assert (Test-SenzOwnedProcess $p $root) 'select only game at installation path'
$p.ExecutablePath=Join-Path ($root+'Other') 'engine/soh.exe'
Assert (-not (Test-SenzOwnedProcess $p $root)) 'exclude another game installation'
$p.Name='powershell.exe';$p.ExecutablePath='';$p.CommandLine='powershell.exe -File "C:\Temp\SenzUpdater-123\Updater.ps1" -InstallRoot "'+$root+'" -LauncherPid 123'
Assert (Test-SenzOwnedProcess $p $root) 'select temp updater with exact installation argument'
$s=Get-Content (Join-Path $base 'Launcher.ps1') -Raw
Assert (-not $s.Contains("`$_.Cancel=`$true;`$win.WindowState='Minimized'")) 'close no longer silently minimizes'
Assert ($s.Contains('[Environment]::Exit(0)')) 'hidden PowerShell explicitly exits after window closes'
