import ctypes
import ctypes.util
import hashlib
import json
import os
from pathlib import Path
import statistics
import subprocess
import time
from PIL import Image

out = Path('/build/work/qa-2026-11-15')
theme = Path('/build/iso-local-06/profile/airootfs/usr/share/plymouth/themes/nahj')
installed = Path('/usr/share/plymouth/themes/nahj')
ref = {}
manifest = json.loads((theme / 'manifest.json').read_text())
for name, digest in manifest['frames'].items():
    assert hashlib.sha256((installed / name).read_bytes()).hexdigest() == digest, name
    lib = ctypes.CDLL(ctypes.util.find_library('ply-splash-graphics'))
    lib.ply_image_new.argtypes = [ctypes.c_char_p]
    lib.ply_image_new.restype = ctypes.c_void_p
    lib.ply_image_load.argtypes = [ctypes.c_void_p]
    lib.ply_image_load.restype = ctypes.c_bool
    lib.ply_image_resize.argtypes = [ctypes.c_void_p, ctypes.c_long, ctypes.c_long]
    lib.ply_image_resize.restype = ctypes.c_void_p
    lib.ply_image_get_data.argtypes = [ctypes.c_void_p]
    lib.ply_image_get_data.restype = ctypes.c_void_p
    lib.ply_image_free.argtypes = [ctypes.c_void_p]
    original = lib.ply_image_new(bytes(theme/name))
    assert lib.ply_image_load(original)
    resized = lib.ply_image_resize(original, 1920, 1080)
    assert resized
    data = ctypes.string_at(lib.ply_image_get_data(resized), 1920*1080*4)
    im = Image.frombytes('RGBA', (1920,1080), data, 'raw', 'BGRA')
    ref.setdefault(hashlib.md5(im.convert('RGB').tobytes()).hexdigest(), []).append(Path(name).stem)
    lib.ply_image_free(resized)
    lib.ply_image_free(original)
assert (installed / 'nahj.script').read_bytes() == (theme / 'nahj.script').read_bytes()
env = dict(os.environ, DISPLAY=':111')
display = subprocess.Popen(['Xvfb', ':111', '-screen', '0', '1920x1080x24', '-nolisten', 'tcp'], stdout=subprocess.DEVNULL, stderr=(out / 'xvfb.log').open('w'))
try:
    for _ in range(100):
        if Path('/tmp/.X11-unix/X111').exists():
            break
        time.sleep(.05)
    for trial in range(1, 4):
        dest = out / f'native-{trial}.md5'
        cap = subprocess.Popen(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-f', 'x11grab', '-draw_mouse', '0', '-framerate', '60', '-video_size', '1920x1080', '-i', ':111', '-t', '20', '-threads', '1', '-pix_fmt', 'rgb24', '-f', 'framemd5', '-y', str(dest)])
        time.sleep(.7)
        subprocess.run(['plymouthd', '--mode=boot', '--no-boot-log', f'--pid-file={out}/plymouth.pid', '--kernel-command-line=quiet splash', '--graphical-boot'], env=env, check=True)
        subprocess.run(['plymouth', '--show-splash'], check=True)
        try:
            cap.wait(timeout=40)
            assert cap.returncode == 0
        finally:
            subprocess.run(['plymouth', '--quit'], timeout=10, check=True)
            if cap.poll() is None:
                cap.terminate()
                cap.wait(timeout=5)
        samples = []
        for line in dest.read_text().splitlines():
            if line.startswith('#'):
                continue
            fields = [x.strip() for x in line.split(',')]
            samples.append((int(fields[2])/60, '|'.join(sorted(ref.get(fields[-1], ['unmatched'])))))
        runs = []
        for t, frame in samples:
            if not runs or runs[-1]['frame'] != frame:
                runs.append({'time': t, 'frame': frame})
        matched = [r for r in runs if r['frame'] != 'unmatched']
        gaps = [1000*(b['time']-a['time']) for a,b in zip(matched, matched[1:])]
        assert matched, 'No actual theme frames matched capture'
        summary = dict(resolution='1920x1080', trial=trial, capture_samples=len(samples), expected_samples=1200,
            capture_max_gap_ms=max(1000*(b[0]-a[0]) for a,b in zip(samples,samples[1:])),
            matched_changes=len(matched), median_frame_ms=statistics.median(gaps),
            mean_frame_ms=statistics.mean(gaps), max_frame_ms=max(gaps),
            gaps_over_84ms=sum(x>84 for x in gaps), first=matched[:3], last=matched[-3:], runs=runs)
        (out / f'native-{trial}.json').write_text(json.dumps(summary, indent=2)+'\n')
        print(json.dumps({k:v for k,v in summary.items() if k!='runs'}), flush=True)
finally:
    display.terminate()
    display.wait(timeout=5)
