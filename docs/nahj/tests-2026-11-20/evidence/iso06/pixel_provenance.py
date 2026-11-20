import hashlib
import json
from pathlib import Path
import subprocess
from PIL import Image

out = Path('/build/work/qa-2026-11-14')
theme = out / 'iso-root/usr/share/plymouth/themes/nahj'
source = Path('/src/distro/boot/source/nahj.mp4')
assert hashlib.sha256(source.read_bytes()).hexdigest() == '7e62194861a2ce7f6c7e3fa56d66d4b26f827354d2fc3e656253f4dff7cdfa08'
decoder = subprocess.Popen(['ffmpeg', '-v', 'error', '-i', str(source), '-map', '0:v:0', '-vf', 'fps=24', '-frames:v', '240', '-pix_fmt', 'rgb24', '-f', 'rawvideo', '-threads', '1', 'pipe:1'], stdout=subprocess.PIPE)
heads = {}
verified = []
try:
    for n in range(240):
        data = decoder.stdout.read(1280*720*3)
        assert len(data)==1280*720*3, f'Truncated source frame {n}'
        frame = Image.frombytes('RGB', (1280,720), data)
        if 108 <= n < 132:
            heads[n-108] = frame
        if n < 132:
            name = f'intro-{n}.bmp'
        elif n < 216:
            name = f'loop-{n-132}.bmp'
        else:
            j = n-216
            t = j/23
            frame = Image.blend(frame, heads[j], t*t*(3-2*t))
            name = f'loop-{84+j}.bmp'
        with Image.open(theme/name) as actual:
            assert actual.convert('RGB').tobytes()==frame.tobytes(), f'Pixel mismatch {name}'
        verified.append(name)
    assert decoder.stdout.read()==b''
    assert decoder.wait(timeout=10)==0
finally:
    if decoder.poll() is None:
        decoder.terminate()
        decoder.wait(timeout=10)
result = dict(original_video_unchanged=True, frames_verified=len(verified),
    exact_source_frames=216, prescribed_smooth_crossfade_frames=24,
    dimensions=[1280,720], fps=24, artifact='ISO 06 freshly extracted theme')
(out/'pixel-provenance.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
