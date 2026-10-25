$script:UpdateRepo='senzstudio95-debug/SENZ-OOT-COOP'
function Assert-UpdateManifest($Manifest) {
 if($Manifest.schema -ne 1 -or $Manifest.version -notmatch '^\d+\.\d+\.\d+$' -or $Manifest.sha256 -notmatch '^[a-fA-F0-9]{64}$'){throw 'Manifest update tidak sah.'}
 $uri=[uri]$Manifest.url
 if($uri.Scheme -ne 'https' -or $uri.Host -ne 'github.com' -or $uri.Query -or $uri.Fragment -or $uri.AbsolutePath -notmatch '^/senzstudio95-debug/SENZ-OOT-COOP/releases/download/[^/]+/SENZ-Update-[a-zA-Z0-9.-]+\.zip$'){throw 'Alamat update bukan release rasmi projek ini.'}
 if([long]$Manifest.bytes -lt 1 -or [long]$Manifest.bytes -gt 104857600){throw 'Saiz update tidak sah.'}
}
function Expand-VerifiedUpdate([string]$Zip,[string]$Stage,$Manifest) {
 Assert-UpdateManifest $Manifest
 if((Get-Item -LiteralPath $Zip).Length -ne [long]$Manifest.bytes -or (Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash -ne $Manifest.sha256){throw 'Fail update tidak lengkap atau checksum berbeza. Fail game belum diubah.'}
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $allowed=@('Launcher.ps1','Launcher.xaml','Lobby.ps1','LobbyBridge.cs','Coop.ps1','Updater.ps1','UpdateCore.ps1','version.json','BACA-DULU.txt','SENZ-Zelda.exe','update-files.json')
 $archive=[IO.Compression.ZipFile]::OpenRead($Zip)
 try {
  $seen=@{};$total=0L
  foreach($entry in $archive.Entries){
   if($entry.FullName -notin $allowed -or $seen.ContainsKey($entry.FullName)){throw 'ZIP mengandungi fail tidak dibenarkan/berulang.'}
   $seen[$entry.FullName]=$true;$total+=$entry.Length
   if($total -gt 209715200){throw 'Saiz ekstrak melebihi had.'}
  }
  [void][IO.Directory]::CreateDirectory($Stage)
  foreach($entry in $archive.Entries){[IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $Stage $entry.FullName),$false)}
 }finally{$archive.Dispose()}
 $list=Get-Content -LiteralPath (Join-Path $Stage 'update-files.json') -Raw|ConvertFrom-Json
 if($list.version -ne $Manifest.version){throw 'Versi ZIP dan manifest tidak sepadan.'}
 $seenFiles=@{}
 foreach($f in $list.files){
  if($f.path -notin $allowed -or $f.path -eq 'update-files.json' -or $seenFiles.ContainsKey($f.path) -or $f.sha256 -notmatch '^[a-fA-F0-9]{64}$'){throw 'Senarai fail update tidak sah.'}
  $seenFiles[$f.path]=$true
  if((Get-FileHash -LiteralPath (Join-Path $Stage $f.path) -Algorithm SHA256).Hash -ne $f.sha256){throw ('Checksum fail gagal: '+$f.path)}
 }
 if($seen.Count -ne ($seenFiles.Count+1) -or -not $seenFiles.ContainsKey('version.json')){throw 'Senarai fail ZIP tidak lengkap.'}
 $v=Get-Content -LiteralPath (Join-Path $Stage 'version.json') -Raw|ConvertFrom-Json
 if($v.version -ne $Manifest.version){throw 'Versi pemasangan tidak sepadan.'}
 return $list
}
function Install-VerifiedUpdate([string]$InstallRoot,[string]$Stage,$FileList) {
 $backup=Join-Path $InstallRoot ('update-backups/'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,6))
 [void][IO.Directory]::CreateDirectory($backup)
 $done=New-Object 'System.Collections.Generic.List[object]'
 # Commit version last. Save/config/ROM/mods are never in the update allowlist.
 $files=@($FileList.files|Where-Object{$_.path -ne 'version.json'})+@($FileList.files|Where-Object{$_.path -eq 'version.json'})
 try {
  foreach($f in $files){
   $target=Join-Path $InstallRoot $f.path;$source=Join-Path $Stage $f.path
   if((Test-Path -LiteralPath $target) -and ((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Fail sasaran ialah pautan simbolik.'}
   $existed=Test-Path -LiteralPath $target
   if($existed){Copy-Item -LiteralPath $target -Destination (Join-Path $backup $f.path)}
   $tmp=$target+'.senz-update'
   Copy-Item -LiteralPath $source -Destination $tmp -Force
   if($existed){[IO.File]::Replace($tmp,$target,(Join-Path $backup ($f.path+'.atomic')))}else{[IO.File]::Move($tmp,$target)}
   $done.Add([pscustomobject]@{path=$f.path;existed=$existed})
  }
 } catch {
  $failure=$_
  for($i=$done.Count-1;$i -ge 0;$i--){$f=$done[$i];$target=Join-Path $InstallRoot $f.path;if($f.existed){Copy-Item -LiteralPath (Join-Path $backup $f.path) -Destination $target -Force}else{Remove-Item -LiteralPath $target -Force}}
  throw $failure
 }
 return $backup
}
