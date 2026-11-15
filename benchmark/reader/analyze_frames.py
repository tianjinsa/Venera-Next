"""Join actual FrameTiming UI intervals with Perfetto thread states and touches.

Uses frame timestamps, not the batched callback receive time. Reports each
candidate UI thread separately; never adds two threads into a frame duration.
"""
import argparse
import bisect
import csv
import io
import json
from pathlib import Path
import re
import subprocess

from summarize import distribution


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--processor', default='D:/.tool/codex-temp/reader-adb-perf/trace_processor_shell.exe')
    args = parser.parse_args()
    report = json.loads((args.capture / 'capture.json').read_text())
    procedure = json.loads((args.capture / 'procedure.json').read_text())
    package = procedure['package']
    if not re.fullmatch(r'[a-z0-9._]+\.readerbenchmark', package):
        raise ValueError('Unexpected app ID')
    calibration = min(report['calibration'], key=lambda c: c['dartEndUs'] - c['dartBeginUs'])
    offset_us = (calibration['dartBeginUs'] + calibration['dartEndUs']) / 2 - calibration['monoNs'] / 1000
    boot_delta_ns = calibration['elapsedNs'] - calibration['monoNs']
    def boot(us):
        return round((us - offset_us) * 1000 + boot_delta_ns)
    frames = sorted(f for f in report['frames'] if report['startedUs'] <= f[0] <= report['stoppedUs'])
    boundaries = []
    for event in report['events']:
        if event[1] == 'pointerDown':
            boundaries.append((event[0], 'dragging'))
        elif event[1] == 'pointerUp' and event[4] <= 1:
            boundaries.append((event[0], 'afterRelease'))
    times = [point[0] for point in boundaries]
    rows = []
    for index, frame in enumerate(frames):
        phase_index = bisect.bisect_right(times, frame[1]) - 1
        phase = boundaries[phase_index][1] if phase_index >= 0 else 'beforeTouchOrCommand'
        rows.append((index, boot(frame[1]), boot(frame[2]), phase, (frame[2] - frame[1]) / 1000))
    if not rows:
        raise ValueError('No frames')
    values = ','.join(f"({i},{start},{end},'{phase}',{duration})" for i, start, end, phase, duration in rows)
    sql = f'''
CREATE PERFETTO TABLE frame_windows AS
WITH data(id,start,stop,phase,ui_ms) AS (VALUES {values}) SELECT * FROM data;
SELECT w.id, w.phase, w.ui_ms, t.tid, t.name, s.state,
    SUM(MAX(0,MIN(s.ts+s.dur,w.stop)-MAX(s.ts,w.start)))/1e6 AS state_ms
FROM frame_windows w JOIN thread_state s ON s.ts<w.stop AND s.ts+s.dur>w.start
JOIN thread t USING(utid) JOIN process p USING(upid)
WHERE (p.name='{package}' OR p.cmdline GLOB '{package}*')
    AND (t.tid=p.pid OR t.name GLOB '*.ui')
GROUP BY w.id,t.utid,s.state ORDER BY w.id,t.tid,s.state;
'''
    sql_path = args.capture / 'frame-states.sql'
    sql_path.write_text(sql, encoding='utf-8')
    result = subprocess.run([args.processor, 'query', '--format', 'csv', '--no-progress', '-f', str(sql_path), str(args.capture / 'trace.pftrace')], capture_output=True, check=True)
    (args.capture / 'frame-states.csv').write_bytes(result.stdout)
    grouped = {}
    for row in csv.DictReader(io.StringIO(result.stdout.decode('utf-8'))):
        key = (int(row['id']), int(row['tid']))
        item = grouped.setdefault(key, {'frame': key[0], 'tid': key[1], 'thread': row['name'], 'phase': row['phase'], 'uiMs': float(row['ui_ms'])})
        item[row['state']] = float(row['state_ms'])
    threads = []
    for tid in sorted({key[1] for key in grouped}):
        items = [value for key, value in grouped.items() if key[1] == tid]
        slow = [item for item in items if item['uiMs'] >= 2]
        coverage = [sum(v for k, v in item.items() if k not in ('frame', 'tid', 'thread', 'phase', 'uiMs')) / item['uiMs'] for item in items if item['uiMs'] > 0]
        threads.append({'tid': tid, 'name': items[0]['thread'], 'coveredFrames': len(items), 'stateCoverageRatio': distribution(coverage), 'slowUiFramesAtLeast2ms': len(slow),
                        'slowUiRunningMs': distribution([item.get('Running', 0) for item in slow]),
                        'slowUiRunnableMs': distribution([item.get('R', 0) + item.get('R+', 0) for item in slow]),
                        'slowUiSleepMs': distribution([item.get('S', 0) for item in slow])})
    summary = {'clockCalibrationRttUs': calibration['dartEndUs'] - calibration['dartBeginUs'],
               'uiMsByPointerPhase': {phase: distribution([row[4] for row in rows if row[3] == phase]) for phase in sorted({row[3] for row in rows})},
               'threads': threads, 'limits': 'After-release describes input phase, not proof the animation remains active. Thread states require clock-aligned valid sched data; this is not actual presentation FPS.'}
    (args.capture / 'frame-states-summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
