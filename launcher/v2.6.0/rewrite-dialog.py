from pathlib import Path
import json,re,textwrap,struct,zipfile,shutil
r=Path('/tmp/senz-v260/SENZ-OOT-SOLO')
changes={
'0022':'Haram jadah! Aku kena sumpah!!',
'0023':'Celaka betul sumpahan tu! Lepas ni kita kena lebih berjaga-jaga!',
'0205':'Diamlah, tahi hang!\n\nBaru {TIME}! Aku, Dampe penjaga kubur, tengah tidur!\n\nPergi main jauh-jauh! Siang pun nak cari hantu ke, bodoh?!',
'0206':'Dah {TIME}! Lawatan gali kubur dah tutup, faham?!\n\nAku, Dampe, nak tidur!\n\nButuh pak hang! Pergi main jauh-jauh, cari hantu sana!',
'1046':'Oi, haram jadah! Buat apa masuk rumah aku tanpa izin?!',
'1096':'{UNSKIPPABLE}{SOUND:685F}Oi! Bangunlah, pemalas!\n\n{UNSKIPPABLE}Haram jadah, nasib Hyrule bergantung kat budak kuat tidur ni ke?!',
'201C':'{UNSKIPPABLE}Bodoh tak sedar diri! Hang tahu tak siapa yang hang tengah cabar ni?!',
'2025':'Oi, masa dah habis! Hang bayar 10 Rupee je, celaka! Cukuplah main tu!{EVENT}',
'2081':'Masa tamat! Hah, padan muka!\n\nAyam aku hebat, kan? Hang asyik kalah, duit masuk poket aku!\n\nBalik sini, ayam-ayam aku!{EVENT}',
'504F':'Orang kata bodoh tak ada ubat. Tahi hang, nampaknya memang betul!',
'6006':'Bodoh! Masuk dalam tu dan tutup mulut hang!',
'6010':'Aku tak nak layan pengecut macam hang! Pergi mampus dengan alasan hang!',
'6028':'{UNSKIPPABLE}Oi, celaka! Hang nak bawa aku ke mana ni?!',
'603D':'{UNSKIPPABLE}{PLAYER}! Cabut sekarang! Jangan tercegat macam orang bodoh!',
'6048':'Tengok si bodoh tu! Datang sendiri nak jadi korban Ganondorf! Padan muka!{FADE:5A}',
'6052':'Hang panggil siapa nyanyuk, celaka?! Macam ni hang layan kakak sendiri?!{FADE:1E}',
'7020':'Sebab si bangang tu lah kawalan istana makin ketat! Haram jadah! Hahaha!',
'7029':'Hang nak jumpa Puteri Zelda?\n\nDengar cerita kat bandar terus nak masuk istana? Sedap betul kepala hang!\n\nBaliklah, tahi hang! Puteri bukan suka-suka nak jumpa orang yang menceroboh!',
'702F':'{UNSKIPPABLE}Oi! Siapa hang ni?!\n\n{UNSKIPPABLE}Macam mana hang lepas pengawal? Celaka, terkejut aku!{EVENT}',
'7065':'{UNSKIPPABLE}Zelda! Pengkhianat haram jadah!\n\n{UNSKIPPABLE}Tujuh tahun hang lari daripada aku. Hebat juga helah hang, celaka!',
'70DB':'{UNSKIPPABLE}{TEXT_SPEED:03}HARAM JADAH... ZELDA!{TEXT_SPEED:02} CELAKA... PARA PENDETA!!{TEXT_SPEED:00}{FADE:32}',
'70DC':'{UNSKIPPABLE}Haram jadah kau, {PLAYER}!{FADE:1E}',
'70DF':'{TEXT_SPEED:02}Hang...{TEXT_SPEED:00}siapa sebenarnya, celaka?{FADE:50}',
'7125':'Aku sibuk! Tepi sikit, butuh pak hang! Jangan halang jalan aku!',
'7127':'Hmph! Berambus dari depan aku! Menyemak betul, tahi hang!',
'7140':'Bodoh! Cakap dengan aku, pandanglah muka aku! Mata hang kat mana?!',
'7141':'Bodoh! Pandang apa lama sangat?! Nak tembus muka aku ke, celaka?!',
'7142':'Oi, bangang! Buka topeng tu bila bercakap dengan aku!',
'7143':'Hang memang bodoh! Aku tak tahu kenapa aku marah, tapi hang menyemak!',
'714C':'Sudahlah main-main, celaka! Tolong hapuskan sumpahan kami dulu!',
'715E':'Oi, topeng cantik! Aku nak!\n\nHah, tipu je! Tahi hang, aku tak nak topeng buruk tu!',
'717E':'Argh! Celaka, topeng rupanya! Berambuslah! Terkejut aku, bodoh!',
'719C':'Jangan kacau aku lagi! Berambus, haram jadah!',
'719E':'Tepi! Berambus dari sini! Hang sengaja nak cari pasal ke, bodoh?!',
'719F':'Berani hang datang pakai benda tu! Tahi hang, ingat senang nak tipu kami?!',
}
code={'UNSKIPPABLE':0x1a,'SOUND':0x12,'EVENT':0x0b,'PLAYER':0x0f,'TIME':0x1f,'TEXT_SPEED':0x14,'FADE':0x0e}
args={'SOUND':2,'TEXT_SPEED':1,'FADE':1}
def encode(s):
 out=bytearray();col=0;line=0
 def newline(page=False):
  nonlocal col,line
  if page or line>=3:out.append(4);line=0
  else:out.append(1);line+=1
  col=0
 for t in re.findall(r'\{[^}]+\}|\n\n|\n|[^\s{}]+|[ \t]+',s):
  if t=='\n\n':newline(True);continue
  if t=='\n':newline();continue
  if t.startswith('{'):
   name,_,value=t[1:-1].partition(':');out.append(code[name]);
   if value:out.extend(bytes.fromhex(value))
   if name in ('PLAYER','TIME'):col+=8
   continue
  if t.isspace():
   if col:out.extend(b' ');col+=1
   continue
  if col+len(t)>30:newline()
  out.extend(t.encode('ascii'));col+=len(t)
 out.append(2);return bytes(out)
def controls(b):
 out=[];i=0
 lengths={5:1,6:1,7:2,12:1,14:1,17:2,18:2,19:1,20:1,21:3,30:1}
 while i<len(b):
  c=b[i];n=lengths.get(c,0)
  if c<32 and c not in (1,2,4):out.append(b[i:i+n+1])
  i+=n+1
 return out
p=r/'source/malay-full/dialog-2115-malay-rojak.json';d=json.loads(p.read_text())
lookup={int(x['id'],16):x for x in d};encoded={}
for key,s in changes.items():
 old=bytes.fromhex(lookup[int(key,16)]['translated_hex']);new=encode(s)
 assert controls(old)==controls(new),(key,controls(old),controls(new))
 encoded[int(key,16)]=new
pack=r/'engine/mods/senz-bahasa-melayu-preview.o2r';backup=r/'language-backup/senz-bahasa-melayu-standard.o2r';backup.parent.mkdir(exist_ok=True);shutil.copy2(pack,backup)
with zipfile.ZipFile(pack) as z:
 records={i.filename:z.read(i.filename) for i in z.infolist()}
name='override/text/nes_message_data_static/senz_ms';b=records[name];count=struct.unpack_from('<I',b,64)[0];assert count==2115
out=bytearray(b[:68]);pos=68;seen=set()
for i in range(count):
 id,typ,yp,n=struct.unpack_from('<HBBI',b,pos);pos+=8;msg=b[pos:pos+n];pos+=n
 if id in encoded:
  assert msg==bytes.fromhex(lookup[id]['translated_hex']),hex(id)
  msg=encoded[id];seen.add(id)
 out.extend(struct.pack('<HBBI',id,typ,yp,len(msg)));out.extend(msg)
assert pos==len(b) and len(seen)==len(changes)
records[name]=out
with zipfile.ZipFile(pack,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for n,data in records.items():z.writestr(n,data)
with zipfile.ZipFile(pack) as z:assert z.testzip() is None
for key,s in changes.items():
 x=lookup[int(key,16)];x['malay_rojak']=s;x['translated_hex']=encoded[int(key,16)].hex();x['status']='manual_aggressive_nonracial_v260'
p.write_text(json.dumps(d,ensure_ascii=False,indent=2))
(r/'source/v2.6.0').mkdir(exist_ok=True)
(r/'source/v2.6.0/dialog-changes.json').write_text(json.dumps(changes,ensure_ascii=False,indent=2))
(r/'source/v2.6.0/dialog-validation.json').write_text(json.dumps({'total_records':count,'manually_rewritten':len(changes),'unchanged_records':count-len(changes),'control_sequences_preserved':True,'archive_crc_pass':True,'racial_abuse_added':False,'gameplay_tested':False},indent=2))
print('PASS',len(changes),'dialogues rewritten; control sequences identical; all other records unchanged')
