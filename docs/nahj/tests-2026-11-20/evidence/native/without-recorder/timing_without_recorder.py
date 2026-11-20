import json
import os
from pathlib import Path
import statistics
import subprocess
import time

out = Path('/build/work/qa-2026-11-20')
subprocess.run(['cc', '-O2', '-fPIC', '-shared', str(out/'frame_trace.c'), '-ldl', '-o', str(out/'frame_trace.so')], check=True)
results = []
for resolution in ['1280x720', '1920x1080']:
    trace = out/f'frame-requests-{resolution}.tsv'
    assert not trace.exists(), 'Use fresh trace output'
    display = subprocess.Popen(['Xvfb', ':112', '-screen', '0', resolution+'x24', '-nolisten', 'tcp'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        for _ in range(100):
            if Path('/tmp/.X11-unix/X112').exists(): break
            time.sleep(.05)
        env = dict(os.environ, DISPLAY=':112', LD_PRELOAD=str(out/'frame_trace.so'), NAHJ_TIMING_PATH=str(trace))
        subprocess.run(['plymouthd', '--mode=boot', '--no-boot-log', f'--pid-file={out}/trace-plymouth.pid', '--kernel-command-line=quiet splash', '--graphical-boot'], env=env, check=True)
        subprocess.run(['plymouth', '--show-splash'], check=True)
        time.sleep(16)
    finally:
        subprocess.run(['plymouth', '--quit'], timeout=10, check=True)
        display.terminate()
        display.wait(timeout=5)
    rows=[]
    for line in trace.read_text().splitlines():
        t,name=line.split('\t')
        if not rows or rows[-1][1] != name: rows.append((float(t),name))
    gaps=[1000*(b[0]-a[0]) for a,b in zip(rows,rows[1:])]
    assert len(gaps)>100, 'Insufficient frame requests'
    result=dict(resolution=resolution,frame_requests=len(rows),mean_ms=statistics.mean(gaps),median_ms=statistics.median(gaps),max_ms=max(gaps),request_fps=1000/statistics.mean(gaps),meaning='Frame load requests, not completed display scanout; no screen recorder')
    results.append(result)
    print(json.dumps(result),flush=True)
(out/'timing-without-recorder.json').write_text(json.dumps(results,indent=2)+'\n')
