"""Sample only the benchmark SurfaceView's present fences around a real capture.

No latency-clear, system settings or application data mutations. Half-second
sampling retains overlap in the 127-row SurfaceFlinger ring. This is diagnostic
overhead: compare only captures using the same collector.
"""
import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess
import sys
import threading
import time

from adb_benchmark import Device, PACKAGES


def find_layer(output, package):
    pattern = re.compile(r'^RequestedLayerState\{(SurfaceView\[' + re.escape(package)
                         + r'/[^\n]+?\]\(BLAST\)#\d+)(?:\s|})')
    matches = [m[1] for line in output.splitlines() if (m := pattern.match(line))]
    if len(matches) != 1:
        raise ValueError(f'Requires exactly one benchmark BLAST SurfaceView, found {len(matches)}')
    return matches[0]


def parse_latency(output):
    lines = output.splitlines()
    if not lines or not lines[0].isdigit():
        raise ValueError('Missing refresh period')
    rows = []
    for line in lines[1:]:
        values = line.split()
        if not values:
            continue
        if len(values) != 3:
            raise ValueError('Unexpected SurfaceFlinger row')
        rows.append([int(v) for v in values])
    return {'periodNs': int(lines[0]), 'rows': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--variant', required=True, choices=['next', 'prime'])
    parser.add_argument('--name', required=True)
    parser.add_argument('--adb', default='E:/Android/Sdk/platform-tools/adb.exe')
    parser.add_argument('--out', type=Path, default=Path(__file__).resolve().parent / 'raw')
    args, capture_args = parser.parse_known_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,80}', args.name):
        parser.error('Invalid name')
    folder = args.out / args.name
    if folder.exists():
        parser.error('Capture already exists')
    if '--reuse-process' in capture_args:
        parser.error('The wrapper owns the one fresh launch')
    device = Device(args.adb, args.variant)
    # Isolate the two benchmark processes; stable user installations are never
    # targeted. Both variants receive the same cold-process starting condition.
    for package, _ in PACKAGES.values():
        device.run('shell', 'am', 'force-stop', package)
    # Allow process/GPU resources to retire before the automatic memory query.
    # This keeps the original policy; never overwrite its selected budget.
    time.sleep(5)
    device.launch()
    layer = find_layer(device.run('shell', 'dumpsys SurfaceFlinger --list'), device.package)
    samples, errors = [], []
    stop = threading.Event()

    def sample():
        while not stop.is_set():
            started = time.monotonic_ns()
            try:
                result = subprocess.run(device.prefix + ['shell', 'dumpsys SurfaceFlinger --latency ' + shlex.quote(layer)],
                                        capture_output=True, text=True, timeout=5, check=True)
                row = parse_latency(result.stdout)
                row.update(hostStartedNs=started, queryDurationMs=(time.monotonic_ns() - started) / 1e6)
                samples.append(row)
            except (ValueError, OSError, subprocess.SubprocessError) as error:
                errors.append({'hostStartedNs': started, 'type': type(error).__name__})
            stop.wait(.5)

    worker = threading.Thread(target=sample, name='benchmark-present-fences', daemon=True)
    worker.start()
    try:
        result = subprocess.run([sys.executable, str(Path(__file__).with_name('adb_benchmark.py')),
                                 '--adb', args.adb, '--variant', args.variant, 'capture',
                                 '--name', args.name, '--out', str(args.out), '--reuse-process'] + capture_args)
    finally:
        stop.set()
        worker.join(timeout=6)
        folder.mkdir(parents=True, exist_ok=True)
        (folder / 'surface-latency.json').write_text(json.dumps({
            'layer': layer, 'sampleIntervalSeconds': .5, 'samples': samples,
            'freshProcessCooldownSeconds': 5,
            'errors': errors, 'workerStopped': not worker.is_alive(),
            'columns': ['desiredPresentNs', 'actualPresentNs', 'frameReadyNs'],
            'source': 'https://android.googlesource.com/platform/frameworks/native/+/refs/heads/main/services/surfaceflinger/FrameTracker.cpp',
            'limits': 'Actual SurfaceView present fences, not a per-vsync dropped-frame count. Includes intentional idle/dwell. Collector overhead must be matched.',
        }, indent=2), encoding='utf-8')
    if result.returncode:
        raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
