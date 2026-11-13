from pathlib import Path
import hashlib
import ctypes
import json
import os
import re
import stat

repo = Path('/src')
root = Path('/build/audit-iso09')
seed = root / 'usr/share/nahj/vitreus'
baseline = json.loads((repo / 'docs/nahj/tests-2026-11-06/iso06-source-audit.json').read_text())
exceptions = {'.github/workflows/addons-bump.yml'}
def contents(path):
    return os.readlink(path).encode() if path.is_symlink() else path.read_bytes()
def digest(data):
    return hashlib.sha256(data).hexdigest()

entries = []
for old in baseline['files']:
    name = old['path']
    actual = seed / name
    same = digest(contents(actual)) == old['sha256']
    current = contents(actual) == contents(repo / name)
    mode = actual.lstat().st_mode
    executable = old['mode'] == '120000' or bool(mode & 0o111) == bool(int(old['mode'], 8) & 0o111)
    kind = stat.S_ISLNK(mode) == (old['mode'] == '120000')
    assert same or name in exceptions, name
    assert current and executable and kind, name
    entries.append({'path': name, 'baseline_match': same, 'current_source_match': current,
                    'kind_and_executable_mode_match': executable and kind})

packages = {}
for desc in (root / 'var/lib/pacman/local').glob('*/desc'):
    lines = desc.read_text().splitlines()
    packages[lines[lines.index('%NAME%') + 1]] = lines[lines.index('%VERSION%') + 1]
required = re.search(r'^pacman_pkgs="([^"]+)"', (repo / 'install.sh').read_text(), re.M)[1].split()
assert set(required) <= packages.keys()
assert 'linux-zen' in packages and 'linux' not in packages
assert packages['nahj-installer'] == '3.3.14-5'
integrations = ['etc/skel/.config/hypr/hyprland.lua', 'usr/local/bin/nahj-session',
                'usr/local/libexec/nahj-vulkan-env', 'etc/sddm.conf.d/20-nahj-theme.conf']
for name in integrations:
    assert (root / name).read_bytes() == (repo / 'distro/archiso/airootfs' / name).read_bytes(), name
greeter = []
for old in baseline['files']:
    if old['path'].startswith('sddm/vitreus/'):
        path = root / 'usr/share/sddm/themes/vitreus' / old['path'].removeprefix('sddm/vitreus/')
        assert digest(contents(path)) == old['sha256'], str(path)
        greeter.append(str(path.relative_to(root)))
assert [p.name for p in (root / 'usr/share/nahj/wayland-sessions').glob('*.desktop')] == ['nahj.desktop']
assert not list((root / 'usr/share/nahj/xsessions').glob('*.desktop'))
shadow = dict(line.split(':', 2)[:2] for line in (root / 'etc/shadow').read_text().splitlines())
crypt = ctypes.CDLL('libcrypt.so.2')
crypt.crypt.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
crypt.crypt.restype = ctypes.c_char_p
stored = shadow['nahj'].encode()
assert crypt.crypt(b'nahj', stored) == stored
assert shadow['root'].startswith(('!', '*'))
report = {
    'iso': 'nahj-2026.11.12-x86_64.iso',
    'iso_sha256': Path('/build/out-local-09/SHA256SUMS').read_text().split()[0],
    'build_source': '943607c58dc2211a99cdb55eb04cf54572674ca8',
    'upstream_commit': baseline['upstream_commit'],
    'original_entries': len(entries),
    'baseline_exact_entries': sum(x['baseline_match'] for x in entries),
    'ci_only_exceptions': sorted(exceptions),
    'all_original_shell_and_greeter_sources_match': True,
    'installed_greeter_files_verified': greeter,
    'current_integration_files_verified': integrations,
    'upstream_required_packages': {n: packages[n] for n in required},
    'linux_zen': packages['linux-zen'],
    'installer': packages['nahj-installer'],
    'sddm_exposes_only_nahj_hyprland_session': True,
    'live_password_nahj_verified': True,
    'root_password_locked': True,
    'entries': entries,
}
Path('/build/iso09-source-audit.json').write_text(json.dumps(report, indent=2) + '\n')
print(f'PASS {len(entries)} current source entries; {sum(x["baseline_match"] for x in entries)} exact upstream + one CI-only exception')
print(f'PASS {len(greeter)} installed greeter files, {len(integrations)} current integration files, {len(required)} upstream package requirements')
print(f'PASS linux-zen {packages["linux-zen"]}; installer {packages["nahj-installer"]}; single SDDM desktop session')
print('PASS live password nahj and locked root password')
