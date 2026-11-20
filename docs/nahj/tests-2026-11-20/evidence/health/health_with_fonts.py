"""Run the original health tool with a valid font link in its disposable rig."""
import json
import os
from pathlib import Path
import subprocess
import time

out = Path('/build/work/qa-2026-11-20')
out.mkdir(exist_ok=True)
source = Path('/build/work/qa-2026-11-15/source')
rig = out / 'rig'
env = dict(os.environ,
    PATH='/build/work/qa-2026-11-15/bin:/build/payload-next/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
    XDG_STATE_HOME=str(out/'state'), RIG=str(rig), RIG_SCREENS='2',
    RIG_PNG=str(out/'rig-start.png'), RIG_AT='30',
    FONTCONFIG_FILE='/build/work/qa-2026-11-15/fonts.conf')
with (out/'health.txt').open('w') as log:
    process = subprocess.Popen(['python3', str(source/'dev/health'), '--no-static', '--no-live', '--cycles', '4', '--idle', '60'], env=env, stdout=log, stderr=subprocess.STDOUT)
    try:
        font_link = rig/'home/.local/share/fonts'
        deadline = time.monotonic()+25
        while time.monotonic()<deadline:
            if font_link.is_symlink() and (rig/'pid').exists():
                break
            if process.poll() is not None:
                raise RuntimeError('Health process exited before creating the rig')
            time.sleep(.1)
        assert font_link.is_symlink() and not font_link.exists(), 'Expected the isolated rig font-link failure'
        before = subprocess.run([str(source/'dev/rig'), 'say', 'get panel'], env=env, capture_output=True, text=True, timeout=10)
        assert before.returncode!=0 and 'File exists' in before.stderr, (before.returncode, before.stdout, before.stderr)
        old_target = str(font_link.readlink())
        font_link.unlink()
        font_link.symlink_to('/build/payload-next/usr/share/fonts')
        assert font_link.is_dir()
        evidence = dict(old_target=old_target, prior_exit=before.returncode, prior_stderr=before.stderr,
                        new_target=str(font_link.readlink()), modification='Only the disposable rig font symlink; no script or shell source changed')
        (out/'font-fixture.json').write_text(json.dumps(evidence, indent=2)+'\n')
        print(json.dumps(evidence), flush=True)
        rc = process.wait(timeout=600)
        print(f'Original health exit code: {rc}', flush=True)
    except BaseException:
        process.terminate()
        process.wait(timeout=10)
        subprocess.run([str(source/'dev/rig'), 'stop'], env=env, timeout=10)
        raise
print((out/'health.txt').read_text(), flush=True)
