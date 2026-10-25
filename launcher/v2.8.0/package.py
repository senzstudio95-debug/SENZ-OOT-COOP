import zipfile, pathlib, hashlib,json,shutil
root=pathlib.Path(__file__).resolve().parent
base=pathlib.Path('base.zip')
assert hashlib.file_digest(base.open('rb'),'sha256').hexdigest()=='9f173ad944efff5adf9795a974b6d36028d33469e8b874bc3ed2a920864eb4e5'
z=zipfile.ZipFile(base)
prefix='SENZ-OOT-SOLO/'
(root/'zelda.ico').write_bytes(z.read(prefix+'zelda.ico'))
if not (root/'SENZ-Zelda.exe').exists():
 print('Icon extracted; build EXE then run package again.');raise SystemExit(0)
files=['Launcher.ps1','Launcher.xaml','Coop.ps1','Lobby.ps1','LobbyBridge.cs','Updater.ps1','UpdateCore.ps1','version.json','BACA-DULU.txt','SENZ-Zelda.exe']
manifest={'version':'2.8.0','files':[{'path':n,'sha256':hashlib.sha256((root/n).read_bytes()).hexdigest()} for n in files]}
(root/'update-files.json').write_text(json.dumps(manifest,indent=2))
out=pathlib.Path('output');out.mkdir(exist_ok=True)
patch=out/'SENZ-Update-2.8.0.zip'
with zipfile.ZipFile(patch,'w',zipfile.ZIP_DEFLATED) as o:
 for n in files+['update-files.json']:o.write(root/n,n)
full=out/'SENZ-Zelda-v2.8.0-OFFLINE-LENGKAP-EXE.zip'
retired={'Coop.ps1','Lobby.ps1','LobbyBridge.cs','RELAY.json','DEPLOYMENT.json'}
with zipfile.ZipFile(full,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as o:
 for info in z.infolist():
  n=info.filename.removeprefix(prefix)
  if n in files+['update-files.json'] or n in retired or n.startswith('source/'):continue
  data=z.read(info)
  if n=='engine/shipofharkinian.json':
   cfg=json.loads(data.decode('utf-8-sig'));cv=cfg.setdefault('CVars',{})
   for service in ['Anchor','Sail','CrowdControl']:cv.setdefault('gRemote',{})[service]={'Enabled':0}
   cv.setdefault('gWindows',{})['AnchorRoom']=0
   cfg.setdefault('Senz',{}).update(CoopRole='Solo',ShowCoopPanel=0)
   data=json.dumps(cfg,indent=2).encode()
  if n.startswith('language-backup/') and '-Ivan.' in n:continue
  o.writestr(info.filename,data)
 for n in files+['update-files.json']:
  if n not in retired:o.write(root/n,prefix+n)
# Validate complete archives and patch/full parity.
with zipfile.ZipFile(full) as o:
 assert o.testzip() is None
 assert not any(n in o.namelist() for n in [prefix+'Coop.ps1',prefix+'Lobby.ps1',prefix+'LobbyBridge.cs'])
 for n in files:
  if n not in retired:assert o.read(prefix+n)==(root/n).read_bytes()
 assert hashlib.sha256(o.read(prefix+'engine/soh.exe')).hexdigest()=='53c5d5621431c6009755c96c15efab93611cd0a7ffea06990c56641f21171633'
channel={'schema':1,'version':'2.8.0','channel':'beta','url':'https://github.com/senzstudio95-debug/SENZ-OOT-COOP/releases/download/v2.8.0-offline/SENZ-Update-2.8.0.zip','sha256':hashlib.file_digest(patch.open('rb'),'sha256').hexdigest(),'bytes':patch.stat().st_size}
(out/'windows.json').write_text(json.dumps(channel,indent=2))
(out/'SHA256SUMS.txt').write_text('\n'.join(hashlib.file_digest(p.open('rb'),'sha256').hexdigest()+'  '+p.name for p in [patch,full])+'\n')
# Smoke fixture is the actual packaged game, tested without starting gameplay.
with zipfile.ZipFile(full) as o:o.extractall('smoke')
print('Validated patch/full archive, engine hash, parity and offline scripts.')
