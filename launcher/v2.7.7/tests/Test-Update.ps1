$ErrorActionPreference='Stop'
$base=Split-Path $PSScriptRoot -Parent
. (Join-Path $base 'UpdateCore.ps1')
function Assert($ok,$message){if(-not $ok){throw $message};Write-Host ('PASS '+$message)}
$manifest=Get-Content (Join-Path $base 'windows.json') -Raw|ConvertFrom-Json
$work=Join-Path ([IO.Path]::GetTempPath()) ('senz-update-tests-'+[guid]::NewGuid())
$root=Join-Path $work 'install';$stage=Join-Path $work 'stage'
[void][IO.Directory]::CreateDirectory((Join-Path $root 'engine/Save'))
[IO.File]::WriteAllText((Join-Path $root 'engine/Save/save.sav'),'save-original')
[IO.File]::WriteAllText((Join-Path $root 'engine/shipofharkinian.json'),'config-original')
[IO.File]::WriteAllText((Join-Path $root 'Launcher.ps1'),'old-launcher')
$list=Expand-VerifiedUpdate (Join-Path (Split-Path $base -Parent) 'SENZ-Update-2.7.7.zip') $stage $manifest
Assert ($list.files.Count -gt 5) 'valid checksum/package extracted'
$backup=Install-VerifiedUpdate $root $stage $list
Assert ((Get-Content (Join-Path $root 'version.json') -Raw|ConvertFrom-Json).version -eq '2.7.7') 'update installed and version committed'
Assert ((Get-Content (Join-Path $root 'engine/Save/save.sav') -Raw) -eq 'save-original') 'save preserved'
Assert ((Get-Content (Join-Path $root 'engine/shipofharkinian.json') -Raw) -eq 'config-original') 'settings preserved'
Assert ((Get-Content (Join-Path $backup 'Launcher.ps1') -Raw) -eq 'old-launcher') 'old launcher backed up'
$bad=$manifest|ConvertTo-Json|ConvertFrom-Json;$bad.sha256='0'*64
$rejected=$false;try{Expand-VerifiedUpdate (Join-Path (Split-Path $base -Parent) 'SENZ-Update-2.7.7.zip') (Join-Path $work 'bad') $bad}catch{$rejected=$true}
Assert $rejected 'tampered hash rejected'
$bad.url='https://example.com/update.zip';$rejected=$false;try{Assert-UpdateManifest $bad}catch{$rejected=$true};Assert $rejected 'untrusted update destination rejected'
# Deliberate failure on file two must restore file one.
[IO.File]::WriteAllText((Join-Path $root 'Launcher.ps1'),'before-rollback')
$badlist=[pscustomobject]@{files=@([pscustomobject]@{path='Launcher.ps1'},[pscustomobject]@{path='missing.ps1'})}
$failed=$false;try{Install-VerifiedUpdate $root $stage $badlist}catch{$failed=$true}
Assert ($failed -and (Get-Content (Join-Path $root 'Launcher.ps1') -Raw) -eq 'before-rollback') 'partial install rolled back'
# A path traversal entry must be rejected even with a matching ZIP hash.
$evil=Join-Path $work 'evil.zip';$z=[IO.Compression.ZipFile]::Open($evil,[IO.Compression.ZipArchiveMode]::Create)
$entry=$z.CreateEntry('../escape.txt');$w=[IO.StreamWriter]::new($entry.Open());$w.Write('bad');$w.Dispose();$z.Dispose()
$bad=$manifest|ConvertTo-Json|ConvertFrom-Json;$bad.sha256=(Get-FileHash $evil).Hash;$bad.bytes=(Get-Item $evil).Length
$rejected=$false;try{Expand-VerifiedUpdate $evil (Join-Path $work 'evil-stage') $bad}catch{$rejected=$true};Assert $rejected 'ZIP traversal rejected'
