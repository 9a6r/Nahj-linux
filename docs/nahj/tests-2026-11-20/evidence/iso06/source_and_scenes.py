import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

out = Path('/build/work/qa-2026-11-14')
source = Path('/src')
image = out / 'iso-root/usr/share/nahj/vitreus'
isolated = out / 'fresh-iso-scene-check'
isolated.mkdir(exist_ok=True)
baseline = '92cd90b0b3ff8bf88831b12f176051450da4a98a'
records = subprocess.check_output(['git', '-c', 'safe.directory=/src', '-C', '/src', 'ls-tree', '-rz', baseline])
files = []
scenes = []
for record in records.split(b'\0'):
    if not record:
        continue
    meta, name = record.split(b'\t', 1)
    mode, kind, oid = meta.decode().split()
    relative = name.decode()
    expected = subprocess.check_output(['git', '-c', 'safe.directory=/src', '-C', '/src', 'cat-file', 'blob', oid])
    path = isolated / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    if mode == '120000':
        path.symlink_to(expected.decode())
        actual = str((image / relative).readlink()).encode()
    else:
        path.write_bytes(expected)
        actual = (image / relative).read_bytes()
        if relative.endswith('.plm') and re.search(rb'^scene\s', expected, re.M):
            scenes.append(relative)
    files.append(dict(path=relative, iso_matches=actual==expected, sha256=hashlib.sha256(expected).hexdigest()))
assert all(r['iso_matches'] for r in files)
for name in ['palette', 'wm-palette']:
    shutil.copyfile(isolated / f'{name}.default.plm', isolated / f'{name}.plm')
results = []
for name in scenes:
    p = subprocess.run([str(out / 'iso-root/usr/bin/pleamar'), '--check', str(isolated/name)], capture_output=True, text=True, timeout=60)
    results.append(dict(scene=name, exit_code=p.returncode, output=p.stdout+p.stderr))
    print(f'{name}: {p.returncode}', flush=True)
(out / 'iso-source-audit.json').write_text(json.dumps(dict(baseline=baseline, files=files), indent=2)+'\n')
(out / 'scene-audit.json').write_text(json.dumps(results, indent=2)+'\n')
assert all(r['exit_code']==0 for r in results), 'Scene compilation failed'
print(f'{len(files)} exact ISO source matches; {len(results)} scenes passed', flush=True)
