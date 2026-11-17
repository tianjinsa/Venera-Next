"""Repeat one-direction real-reader A/B, independently of cached alternation.

Install only guarded benchmark APKs. Preserve all user data. Stop on an invalid
capture; no silent cadence changes, cache overrides, or failed-run replacement.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

from summarize import summarize


SCENARIOS = {
    'hold-forward': ['--input', 'calibrated-hold', '--direction', 'forward', '--seconds', '12'],
    'hold-reverse': ['--input', 'calibrated-hold', '--direction', 'reverse', '--seconds', '12'],
    'touch-fast': ['--input', 'swipes', '--direction', 'forward', '--touch-driver', 'fixed', '--count', '20', '--swipe-ms', '80', '--interval', '.125', '--seconds', '8'],
    'touch-normal': ['--input', 'swipes', '--direction', 'forward', '--touch-driver', 'fixed', '--count', '20', '--swipe-ms', '160', '--interval', '1', '--seconds', '28'],
    'touch-medium': ['--input', 'swipes', '--direction', 'forward', '--touch-driver', 'fixed', '--count', '20', '--swipe-ms', '120', '--interval', '.35', '--seconds', '14'],
    'touch-very-fast': ['--input', 'swipes', '--direction', 'forward', '--touch-driver', 'fixed', '--count', '20', '--swipe-ms', '80', '--interval', '.045', '--seconds', '8'],
    'touch-single': ['--input', 'swipes', '--direction', 'forward', '--touch-driver', 'fixed', '--count', '1', '--swipe-ms', '160', '--interval', '.4', '--seconds', '6'],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--next-apk', required=True, type=Path)
    parser.add_argument('--prime-apk', required=True, type=Path)
    parser.add_argument('--prefix', required=True)
    parser.add_argument('--resume', action='store_true', help='Resume completed-plan manifest; retain invalid attempts under separate names')
    parser.add_argument('--rounds', type=int, default=2, choices=range(1, 4))
    parser.add_argument('--scenarios', nargs='+', choices=SCENARIOS, default=['hold-forward', 'hold-reverse', 'touch-fast'])
    parser.add_argument('--adb', default='E:/Android/Sdk/platform-tools/adb.exe')
    parser.add_argument('--out', type=Path, default=Path(__file__).resolve().parent / 'raw')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,28}', args.prefix):
        parser.error('Prefix must be a short safe name')
    here = Path(__file__).resolve().parent
    manifest = args.out / (args.prefix + '-series.json')
    if manifest.exists() and not args.resume:
        parser.error('Series already exists')
    apks = {'next': args.next_apk, 'prime': args.prime_apk}
    plan = []
    for round_index in range(args.rounds):
        for scenario_index, scenario in enumerate(args.scenarios):
            order = ['next', 'prime'] if (round_index + scenario_index) % 2 == 0 else ['prime', 'next']
            for variant in order:
                plan.append({'variant': variant, 'scenario': scenario,
                             'captureArgs': SCENARIOS[scenario],
                             'name': f'{args.prefix}-{variant}-{scenario}-r{round_index + 1}'})
    data = {'apks': {v: {'file': p.name, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for v, p in apks.items()},
            'expectedCacheMiB': 192, 'expectedRefreshHz': 120, 'alternatingPages': False,
            'plan': plan, 'completed': []}
    args.out.mkdir(parents=True, exist_ok=True)
    if args.resume:
        existing = json.loads(manifest.read_text())
        if existing['apks'] != data['apks']:
            parser.error('Cannot resume with different APKs')
        data = existing
        plan = data['plan']
        if any('captureArgs' not in row and row['name'] not in data['completed'] for row in plan):
            parser.error('Legacy pending plan has no frozen input arguments; start an explicitly named new series')
    else:
        manifest.write_text(json.dumps(data, indent=2))
    for variant, apk in apks.items():
        subprocess.run([sys.executable, str(here / 'adb_benchmark.py'), '--adb', args.adb,
                        '--variant', variant, 'install', str(apk)], check=True)
    for row in plan:
        if row['name'] in data['completed']:
            continue
        if (args.out / row['name']).exists():
            data.setdefault('excludedAttempts', []).append(row['name'])
            base = re.sub(r'-a\d+$', '', row['name'])
            for attempt in range(2, 5):
                candidate = f'{base}-a{attempt}'
                if not (args.out / candidate).exists():
                    row['name'] = candidate
                    break
            else:
                raise ValueError('Repeated invalid condition; inspect the device before another series')
            manifest.write_text(json.dumps(data, indent=2))
        print('ONE DIRECTION:', row['variant'], row['scenario'], row['name'], flush=True)
        subprocess.run([sys.executable, str(here / 'surface_capture.py'), '--adb', args.adb,
                        '--variant', row['variant'], '--name', row['name'], '--out', str(args.out),
                        '--perfetto'] + row['captureArgs'], check=True)
        subprocess.run([sys.executable, str(here / 'analyze_presentation.py'), str(args.out / row['name'])],
                       check=True, stdout=subprocess.DEVNULL)
        if row['scenario'] in ('touch-normal', 'touch-single'):
            report = json.loads((args.out / row['name'] / 'capture.json').read_text())
            counts = summarize(report)
            expected = 20 if row['scenario'] == 'touch-normal' else 1
            if (counts['pointerDowns'] != expected or counts['newDragWhileScrolling'] or
                    report['after']['page'] != 160 + expected):
                raise ValueError('Normal/single touch did not complete every idle-to-idle page; retain and inspect')
        presented = json.loads((args.out / row['name'] / 'presentation-summary.json').read_text())
        if presented['sampleErrors'] or presented['possibleRingOverflows'] or not presented['presentedSurfaceBuffers']:
            raise ValueError('Presentation stream incomplete; retain and inspect the capture')
        data['completed'].append(row['name'])
        manifest.write_text(json.dumps(data, indent=2))
    print('COMPLETED ONE-DIRECTION A/B:', len(plan), 'captures', flush=True)


if __name__ == '__main__':
    main()
