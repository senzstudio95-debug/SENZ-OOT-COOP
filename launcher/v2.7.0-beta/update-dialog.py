from pathlib import Path
import zipfile,struct,re,json
r=Path('/tmp/senz-v270/SENZ-OOT-SOLO')
lens={5:1,6:1,7:2,12:1,14:1,17:2,18:2,19:1,20:1,21:3,30:1}
def atoms(b):
 i=0
 while i<len(b):
  n=lens.get(b[i],0) if b[i]<32 else 0;yield b[i:i+1+n];i+=1+n

def patch(msg):
 # Match text spans only; control arguments are never searched or rewritten.
 a=list(atoms(msg));s=b''.join(a)
 # Existing phrase consists of printable bytes with optional line break between words.
 matches=list(re.finditer(rb'pari(?:-|[ \x01])pari(?! butoh)',s,re.I))
 if not matches:return msg,0
 for m in reversed(matches):s=s[:m.end()]+b' butoh'+s[m.end():]
 out=bytearray();line=0;col=0;choice=False
 for a in atoms(s):
  c=a[0]
  if c==4:line=col=0;choice=False
  elif c==1:
   line+=1;col=0
   if line>=4 and not choice:a=b'\x04';line=0
  elif c in (27,28):choice=True
  elif c>=32:
   if col>=30 and c==32:
    a=b'\x01';col=0;line+=1
    if line>=4 and not choice:a=b'\x04';line=0
   else:col+=1
  out.extend(a)
 return bytes(out),len(matches)
p=r/'engine/mods/senz-bahasa-melayu-preview.o2r'
with zipfile.ZipFile(p) as z:d={n:z.read(n) for n in z.namelist()}
k='override/text/nes_message_data_static/senz_ms';b=d[k];out=bytearray(b[:68]);pos=68;changed={};count=struct.unpack_from('<I',b,64)[0]
for _ in range(count):
 id,t,y,n=struct.unpack_from('<HBBI',b,pos);pos+=8;msg=b[pos:pos+n];pos+=n;new,m=patch(msg)
 if m:
  oldctl=[x for x in atoms(msg) if x[0]<32 and x[0] not in (1,4)]
  newctl=[x for x in atoms(new) if x[0]<32 and x[0] not in (1,4)]
  assert oldctl==newctl;changed[f'{id:04X}']={'occurrences':m,'hex':new.hex()}
 out.extend(struct.pack('<HBBI',id,t,y,len(new)));out.extend(new)
assert pos==len(b);d[k]=out
for p in [p,r/'language-backup/senz-bahasa-melayu-kasar.o2r']:
 with zipfile.ZipFile(p,'w',zipfile.ZIP_DEFLATED) as z:
  for n,v in d.items():z.writestr(n,v)
 with zipfile.ZipFile(p) as z:assert z.testzip() is None
s=r/'source/v2.7.0';s.mkdir(exist_ok=True);(s/'fairy-changes.json').write_text(json.dumps(changed,indent=2));print(len(changed),'records',sum(x['occurrences'] for x in changed.values()),'occurrences')
