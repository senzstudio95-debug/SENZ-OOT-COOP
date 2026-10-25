import hashlib
import json
import shutil
import zipfile
from pathlib import Path

ROOT = Path('/workspace/scratch')
BASE = ROOT / 'SENZ-Zelda-v2.7.0-BETA-LENGKAP-EXE.zip'
PATCH = ROOT / 'SENZ-v2.7.1-UPDATE.zip'
OUT = ROOT / 'SENZ-Zelda-v2.7.1-BETA-LENGKAP-EXE.zip'
PREFIX = 'SENZ-OOT-SOLO/'
README = '''SENZ v2.7.1 BETA — PAKEJ LENGKAP
Patch nama dialog dan lobi sudah dipasang. Tidak perlu pasang ZIP update.
Extract SEMUA fail ke folder baharu, kemudian buka SENZ-Zelda.exe.
Jangan jalankan EXE terus dari dalam ZIP. Simpan folder/save lama.

Kedua-dua pemain gunakan pakej ini.
Host: tab Mod > CREATE ROOM > tunggu ROOM AKTIF > salin kod kepada kawan.
Kawan: tampal kod > JOIN BY CODE > tunggu sambungan disahkan.
Kemudian kedua-duanya tekan PLAY CO-OP dan buka save masing-masing.
Gunakan versi game sama dan save yang sepadan untuk ujian awal.
Sen berbaju hijau; Ivan merah. Keyboard/gamepad lalai dipasang setiap Main.
Untuk offline, pilih Kembali Solo sebelum Main. Steam tidak diperlukan.

163 rujukan nama dialog menggunakan Sen (solo/host) atau Ivan (join).
Nama/progress save asal tidak diubah. Pek dialog BM biasa/kasar tersedia.
HD, bloom dan blur kekal dimatikan secara lalai untuk kestabilan.

Lobi sebenar menunggu pengesahan relay anchor.hm64.org:43383.
Kod tanpa host dan pemain ketiga ditolak oleh launcher.
Had dua pemain bukan sekatan pada relay awam. Internet/relay diperlukan.
Anchor berkongsi pemain serta item/flag tertentu. Dunia, musuh, boss dan
cutscene BELUM disegerakkan sepenuhnya dengan host.

Ujian lobi menggunakan pelayan upstream tempatan lulus. Gameplay Windows
dan dua PC melalui internet BELUM diuji. Ini masih beta.
Jika gagal, hantar launcher-error.log dan log dalam engine/logs.
'''

with zipfile.ZipFile(BASE) as base, zipfile.ZipFile(PATCH) as patch:
    changes = {PREFIX + name: patch.read(name) for name in patch.namelist()
               if name != 'BACA-UPDATE-v2.7.1.txt'}
    changes[PREFIX + 'BACA-DULU.txt'] = README.encode('utf-8-sig')
    info = json.loads(base.read(PREFIX + 'BUILD-INFO.json'))
    info.update(version='2.7.1-live-lobby-complete', live_lobby_preinstalled=True,
                dialogue_name_fix_preinstalled=True, dialogue_name_references=163,
                local_upstream_relay_tests_pass=True, launcher_two_player_limit=True)
    changes[PREFIX + 'BUILD-INFO.json'] = json.dumps(info, indent=2).encode()
    with zipfile.ZipFile(OUT, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as out:
        for item in base.infolist():
            if item.filename in changes:
                continue
            with base.open(item) as src, out.open(item.filename, 'w', force_zip64=True) as dst:
                shutil.copyfileobj(src, dst, 1024 * 1024)
        for name, data in changes.items():
            out.writestr(name, data)

print('Built bundle; checking CRC and embedded patch', flush=True)
with zipfile.ZipFile(OUT) as out, zipfile.ZipFile(PATCH) as patch:
    assert out.testzip() is None
    assert len(out.namelist()) == len(set(out.namelist()))
    for name in patch.namelist():
        if name != 'BACA-UPDATE-v2.7.1.txt':
            assert out.read(PREFIX + name) == patch.read(name), name
    assert not any(n.lower().endswith(('.bat', '.cmd')) for n in out.namelist())
    assert PREFIX + 'SENZ-Zelda.exe' in out.namelist()
    assert hashlib.sha256(out.read(PREFIX + 'engine/soh.exe')).hexdigest() == info['engine_sha256']
    count = len(out.namelist())
sha = hashlib.file_digest(OUT.open('rb'), 'sha256').hexdigest()
manifest = dict(filename=OUT.name, bytes=OUT.stat().st_size, sha256=sha,
                files=count, zip_crc='PASS', embedded_patch_match='PASS',
                native_engine_hash='PASS', windows_gameplay_tested=False,
                internet_two_pc_tested=False)
(ROOT / 'SENZ-v2.7.1-LENGKAP-SHA256.txt').write_text(sha + '  ' + OUT.name + '\n')
Path(__file__).with_name('bundle-validation.json').write_text(json.dumps(manifest, indent=2))
Path(__file__).with_name('BACA-DULU.txt').write_text(README)
print(json.dumps(manifest), flush=True)
