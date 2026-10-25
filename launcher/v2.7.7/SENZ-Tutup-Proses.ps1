param([switch]$FunctionsOnly)
$ErrorActionPreference='Stop'
function Test-SenzOwnedProcess($Process,[string]$InstallRoot) {
 $root=[IO.Path]::GetFullPath($InstallRoot).TrimEnd('\','/')
 $allowed=@((Join-Path $root 'SENZ-Zelda.exe'),(Join-Path $root 'engine/soh.exe'))
 if($Process.ExecutablePath -and $Process.ExecutablePath -in $allowed){return $true}
 if($Process.Name -notin @('powershell.exe','pwsh.exe')){return $false}
 $cmd=[string]$Process.CommandLine
 # Match a complete quoted -File path; don't match prefix-similar folders.
 foreach($file in @('Launcher.ps1','Updater.ps1')){
  $path=Join-Path $root $file
  if($cmd -match ('(?i)(?:^|\s)-File\s+"'+[regex]::Escape($path)+'"(?:\s|$)')){return $true}
  if($path -notmatch '\s' -and $cmd -match ('(?i)(?:^|\s)-File\s+'+[regex]::Escape($path)+'(?:\s|$)')){return $true}
 }
 # Updater runs from TEMP, but carries the exact installation path.
 if($cmd -match '(?i)(?:^|\s)-File\s+"[^"]+[\\/]Updater\.ps1"' -and $cmd -match ('(?i)(?:^|\s)-InstallRoot\s+"'+[regex]::Escape($root)+'"(?:\s|$)')){return $true}
 return $false
}
if($FunctionsOnly){return}
Add-Type -AssemblyName System.Windows.Forms
$picker=New-Object Windows.Forms.FolderBrowserDialog
$picker.Description='Pilih folder SENZ yang ada SENZ-Zelda.exe. Tiada fail akan dipadam.'
if($picker.ShowDialog() -ne 'OK'){$picker.Dispose();exit}
$target=$picker.SelectedPath;$picker.Dispose()
if(-not (Test-Path -LiteralPath (Join-Path $target 'Launcher.ps1'))){[void][Windows.Forms.MessageBox]::Show('Folder ini tiada Launcher.ps1. Pilih folder game yang betul.','SENZ');exit 1}
try {
 $found=@(Get-CimInstance Win32_Process | Where-Object {$_.ProcessId -ne $PID -and (Test-SenzOwnedProcess $_ $target)})
 if($found.Count -eq 0){[void][Windows.Forms.MessageBox]::Show('Tiada proses SENZ untuk folder ini dikesan. Tutup tetingkap Explorer yang berada di dalam folder, kemudian cuba semula. Jika masih gagal, restart Windows dan jangan buka launcher dahulu.','SENZ');exit}
 $list=($found|ForEach-Object{$_.Name+' (PID '+$_.ProcessId+')'}) -join "`r`n"
 $answer=[Windows.Forms.MessageBox]::Show("Proses folder ini akan ditutup:`r`n$list`r`n`r`nSave game dahulu. Progress yang belum disimpan boleh hilang. Tiada fail akan dipadam. Teruskan?",'Tutup proses SENZ','YesNo','Warning')
 if($answer -ne 'Yes'){exit}
 $failures=@()
 foreach($entry in ($found|Sort-Object @{Expression={if($_.Name -eq 'soh.exe'){0}elseif($_.Name -in @('powershell.exe','pwsh.exe')){1}else{2}}})){
  try {
   $fresh=Get-CimInstance Win32_Process -Filter ('ProcessId='+$entry.ProcessId)
   if(-not $fresh){continue}
   if($fresh.CreationDate -ne $entry.CreationDate -or -not (Test-SenzOwnedProcess $fresh $target)){continue}
   Stop-Process -Id $fresh.ProcessId -Force -ErrorAction Stop
  }catch{if(Get-Process -Id $entry.ProcessId -ErrorAction SilentlyContinue){$failures+=($entry.Name+': '+$_.Exception.Message)}}
 }
 if($failures.Count){[void][Windows.Forms.MessageBox]::Show(($failures -join "`r`n")+"`r`nRestart Windows jika proses tidak boleh ditutup.",'Sebahagian proses masih berjalan')}
 else{[void][Windows.Forms.MessageBox]::Show('Arahan tutup proses SENZ selesai. Tutup Explorer yang berada di dalam folder game, kemudian cuba delete semula. Alat ini tidak memadam sebarang fail.','SENZ')}
}catch{[void][Windows.Forms.MessageBox]::Show($_.Exception.Message,'SENZ — pemeriksaan gagal')}
