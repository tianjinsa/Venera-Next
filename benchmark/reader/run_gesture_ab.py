"""ABBA Release experiment for one Next gesture candidate, always forward.

Use sealed APKs. Only the isolated benchmark package is replaced. The optional
natural-budget mode is a diagnostic; it never changes the app's cache policy and
requires the same actual decoded capacity/resident set and image work in all runs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

from summarize import summarize


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before-apk', type=Path, required=True)
    parser.add_argument('--after-apk', type=Path, required=True)
    parser.add_argument('--prefix', required=True)
    parser.add_argument('--natural-budget', action='store_true')
    parser.add_argument('--adb', default='E:/Android/Sdk/platform-tools/adb.exe')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,28}', args.prefix):
        parser.error('Requires a short safe prefix')
    here = Path(__file__).resolve().parent
    raw = here / 'raw'
    manifest = raw / (args.prefix + '-series.json')
    if manifest.exists():
        parser.error('Series already exists; retain it and inspect before retrying')
    apks = {'before': args.before_apk, 'after': args.after_apk}
    data = {
        'apks': {v: {'file': p.name, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                 for v, p in apks.items()},
        'order': ['before', 'after', 'after', 'before'],
        'expectedCacheMiB': None if args.natural_budget else 192,
        'naturalBudgetDiagnostic': args.natural_budget,
        'alternatingPages': False, 'downCadenceMs': 205,
        'dragDurationMs': 80, 'afterUpGapMs': 125, 'completed': [],
    }
    manifest.write_text(json.dumps(data, indent=2))
    signatures = []
    for index, variant in enumerate(data['order']):
        name = f'{args.prefix}-{variant}-{index + 1}'
        print('FORWARD GESTURES:', name, flush=True)
        subprocess.run([sys.executable, str(here / 'adb_benchmark.py'), '--adb', args.adb,
                        '--variant', 'next', 'install', str(apks[variant])], check=True)
        subprocess.run([sys.executable, str(here / 'surface_capture.py'), '--adb', args.adb,
                        '--variant', 'next', '--name', name, '--input', 'swipes',
                        '--touch-driver', 'fixed', '--direction', 'forward', '--count', '20',
                        '--swipe-ms', '80', '--interval', '.125', '--seconds', '8',
                        '--expected-cache-mib', '0' if args.natural_budget else '192',
                        '--perfetto'], check=True)
        folder = raw / name
        report = json.loads((folder / 'capture.json').read_text())
        summary = summarize(report)
        before, after = report['before'], report['after']
        image_bytes = 2048 * 3072 * 4
        if (before['cacheLimitBytes'] != after['cacheLimitBytes'] or
                before['cacheLimitBytes'] < 7 * image_bytes or
                report['droppedEvents'] or summary['pointerDowns'] != 20 or
                before['page'] != 160 or after['page'] != 179 or
                summary['newDragWhileScrolling'] < 17 or before['pendingImages'] or
                after['pendingImages'] or before['refreshHz'] < 119 or after['refreshHz'] < 119):
            raise ValueError('Input/cache/reader preconditions differ; preserve and inspect')
        signature = [before['cacheLimitBytes'] // image_bytes,
                     before['cacheImages'], before['cacheBytes'],
                     after['cacheImages'], after['cacheBytes'],
                     summary['eventCounts'].get('sourceLoad', 0),
                     summary['eventCounts'].get('imageMiss', 0)]
        signatures.append(signature)
        subprocess.run([sys.executable, str(here / 'analyze_presentation.py'), str(folder)],
                       check=True, stdout=subprocess.DEVNULL)
        presented = json.loads((folder / 'presentation-summary.json').read_text())
        if presented['sampleErrors'] or presented['possibleRingOverflows']:
            raise ValueError('Incomplete presentation recording')
        data['completed'].append({'name': name, 'signature': signature,
                                  'cacheLimitBytes': before['cacheLimitBytes'],
                                  'uiMs': summary['uiMs'], 'cpuTimeMs': summary['cpuTimeMs']})
        manifest.write_text(json.dumps(data, indent=2))
    data['sameDecodedCapacityAndWork'] = all(s == signatures[0] for s in signatures)
    manifest.write_text(json.dumps(data, indent=2))
    if not data['sameDecodedCapacityAndWork']:
        raise ValueError('Do not compare timing: actual cache capacity/image work differed')
    print('COMPLETED ABBA: same input path and decoded working set', flush=True)


if __name__ == '__main__':
    main()
