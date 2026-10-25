param([Parameter(Mandatory=$true)][string]$InstallRoot,[int]$LauncherPid=0)
$ErrorActionPreference='Stop'
$lock=$null;$success=$false
try {
 $InstallRoot=[IO.Path]::GetFullPath($InstallRoot)
 . (Join-Path $PSScriptRoot 'UpdateCore.ps1')
 if(-not (Test-Path -LiteralPath (Join-Path $InstallRoot 'SENZ-Zelda.exe'))){throw 'Folder launcher tidak ditemui.'}
 if($LauncherPid -gt 0){$p=Get-Process -Id $LauncherPid -ErrorAction SilentlyContinue;if($p -and -not $p.WaitForExit(30000)){throw 'Launcher masih terbuka. Tutup launcher sebelum update.'}}
 $deadline=(Get-Date).AddSeconds(15)
 while(@(Get-Process -Name SENZ-Zelda -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq (Join-Path $InstallRoot 'SENZ-Zelda.exe')}).Count -gt 0){
  if((Get-Date) -gt $deadline){throw 'Tutup EXE launcher lama sebelum update.'}
  Start-Sleep -Milliseconds 200
 }
 $lock=[IO.File]::Open((Join-Path $InstallRoot '.senz-update.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
 if(@(Get-Process -Name soh -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq (Join-Path $InstallRoot 'engine/soh.exe')}).Count -gt 0){throw 'Tutup game sebelum update.'}
 [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
 Write-Host 'SENZ UPDATE — menyemak GitHub...' -ForegroundColor Green
 $manifestUrl='https://raw.githubusercontent.com/senzstudio95-debug/SENZ-OOT-COOP/main/updates/windows.json'
 $manifest=Invoke-RestMethod -Uri ($manifestUrl+'?t='+[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) -Headers @{'User-Agent'='SENZ-Launcher-Updater'} -TimeoutSec 30
 Assert-UpdateManifest $manifest
 $current=[version]'0.0.0';$versionPath=Join-Path $InstallRoot 'version.json'
 if(Test-Path $versionPath){$current=[version](Get-Content -LiteralPath $versionPath -Raw|ConvertFrom-Json).version}
 if([version]$manifest.version -le $current){Write-Host ('Sudah versi terkini: '+$current);$success=$true}
 else {
  $work=Join-Path ([IO.Path]::GetTempPath()) ('SenzUpdate-'+[guid]::NewGuid().ToString('N'))
  [void][IO.Directory]::CreateDirectory($work);$zip=Join-Path $work 'update.zip';$stage=Join-Path $work 'stage'
  Write-Host ('Muat turun versi '+$manifest.version+' dari GitHub. Save dan tetapan dikekalkan.')
  $web=New-Object Net.WebClient;$web.Headers['User-Agent']='SENZ-Launcher-Updater'
  try {
   $task=$web.DownloadFileTaskAsync([uri]$manifest.url,$zip)
   $deadline=(Get-Date).AddMinutes(10)
   while(-not $task.IsCompleted){if((Get-Date) -gt $deadline){$web.CancelAsync();throw 'Download tamat masa. Cuba Update semula.'};$size=if(Test-Path $zip){(Get-Item $zip).Length}else{0};Write-Progress -Activity 'Muat turun kemas kini SENZ' -Status ('{0:N1} / {1:N1} MB' -f ($size/1MB),($manifest.bytes/1MB)) -PercentComplete ([Math]::Min(99,100*$size/$manifest.bytes));Start-Sleep -Milliseconds 200}
   $task.GetAwaiter().GetResult();Write-Progress -Activity 'Muat turun kemas kini SENZ' -Completed
  }finally{$web.Dispose()}
  $list=Expand-VerifiedUpdate $zip $stage $manifest
  $backup=Install-VerifiedUpdate $InstallRoot $stage $list
  Write-Host ('Update siap. Backup launcher: '+$backup) -ForegroundColor Green
  $success=$true
 }
} catch {
 if($lock){$lock.Dispose();$lock=$null}
 Write-Host ('UPDATE GAGAL: '+$_.Exception.Message) -ForegroundColor Red
 Write-Host 'Jika pemasangan gagal, fail launcher yang telah ditukar dipulihkan daripada backup.'
 Read-Host 'Tekan Enter untuk kembali ke launcher'
} finally {if($lock){$lock.Dispose()}}
if($success){Start-Sleep -Seconds 2}
Start-Process -FilePath (Join-Path $InstallRoot 'SENZ-Zelda.exe') -WorkingDirectory $InstallRoot
exit 0

