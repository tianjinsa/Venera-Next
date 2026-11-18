"""Real-device before/after precache experiment with an equal, lower test cap.

The isolated fixture can only LOWER its automatic ceiling. Default 128 MiB
keeps the 24 MiB decoded images unchanged while avoiding mixed automatic budgets.
This is a separately labelled regime, not a replacement for default-budget A/B.
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
    'touch-fast': ['--input', 'swipes', '--direction', 'forward', '--touch-driver', 'fixed',
                   '--count', '20', '--swipe-ms', '80', '--interval', '.125', '--seconds', '8'],
    'cached': ['--input', 'keysequence', '--alternate', '--warm-radius', '1', '--count', '100',
               '--key-delay-ms', '50', '--seconds', '12'],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before-apk', type=Path, required=True)
    parser.add_argument('--after-apk', type=Path, required=True)
    parser.add_argument('--prefix', required=True)
    parser.add_argument('--order', nargs='+', choices=['before', 'after'],
                        default=['before', 'after', 'after', 'before'])
    parser.add_argument('--scenarios', nargs='+', choices=SCENARIOS,
                        default=['hold-forward', 'hold-reverse', 'touch-fast', 'cached'])
    parser.add_argument('--cache-cap-mib', type=int, choices=[128, 192], default=128)
    parser.add_argument('--reader-diagnostics', action='store_true')
    parser.add_argument('--expected-pages', type=int, default=512)
    parser.add_argument('--forward-page', type=int, default=160)
    parser.add_argument('--reverse-page', type=int, default=160)
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,24}', args.prefix):
        parser.error('Requires a short safe prefix')
    here = Path(__file__).resolve().parent
    raw = here / 'raw'
    manifest = raw / (args.prefix + '-series.json')
    if manifest.exists():
        parser.error('Series already exists; preserve failed attempts')
    apks = {'before': args.before_apk, 'after': args.after_apk}
    data = {
        'apks': {k: {'file': p.name, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                 for k, p in apks.items()},
        'cacheCapMiB': args.cache_cap_mib,
        'budgetRegime': 'explicit shared LOWER cap; actual automatic ceilings saved before cap',
        'order': args.order, 'scenarios': args.scenarios, 'completed': [],
        'expectedPages': args.expected_pages,
        'forwardPage': args.forward_page, 'reversePage': args.reverse_page,
    }
    manifest.write_text(json.dumps(data, indent=2))
    signatures = {}
    for scenario in args.scenarios:
        for index, variant in enumerate(args.order):
            name = f'{args.prefix}-{scenario}-{variant}-{index + 1}'
            print('PRECACHE EXPERIMENT:', name, flush=True)
            subprocess.run([sys.executable, str(here / 'adb_benchmark.py'), '--variant', 'next',
                            'install', str(apks[variant])], check=True)
            subprocess.run([sys.executable, str(here / 'surface_capture.py'), '--variant', 'next',
                            '--name', name, '--expected-cache-mib', str(args.cache_cap_mib),
                            '--test-cache-cap-mib', str(args.cache_cap_mib), '--perfetto']
                           + (['--reader-diagnostics'] if args.reader_diagnostics else [])
                           + ['--expected-pages', str(args.expected_pages), '--page',
                              str(args.reverse_page if scenario == 'hold-reverse' else args.forward_page)]
                           + SCENARIOS[scenario], check=True)
            folder = raw / name
            report = json.loads((folder / 'capture.json').read_text())
            if args.reader_diagnostics:
                diagnostic = json.loads((folder / 'production-diagnostics.json').read_text())
                if diagnostic['stopReason'] != 'review':
                    raise ValueError('Reader left capture before explicit stop; preserve but exclude this run')
            result = summarize(report)
            signature = [result[k] for k in ['nativeKeys', 'dartKeys', 'pointerDowns',
                         'newDragWhileScrolling', 'pageChanges']]
            signature += [report['before'][k] for k in ['page', 'cacheImages', 'cacheBytes']]
            signature.append(report['after']['page'])
            signatures.setdefault(scenario, []).append(signature)
            if report['droppedEvents'] or report['before']['pendingImages'] or report['after']['pendingImages']:
                raise ValueError('Capture incomplete or image work still pending')
            if scenario == 'cached' and (result['distinctMissKeys'] or result['distinctSourceKeys']):
                raise ValueError('Cached isolation contains source work')
            subprocess.run([sys.executable, str(here / 'analyze_presentation.py'), str(folder)],
                           check=True, stdout=subprocess.DEVNULL)
            presented = json.loads((folder / 'presentation-summary.json').read_text())
            if presented['sampleErrors'] or presented['possibleRingOverflows']:
                raise ValueError('Incomplete presentation fences')
            # The screen must show the generated page, not a fast error/blank.
            focused = subprocess.run(['E:/Android/Sdk/platform-tools/adb.exe', 'shell',
                                      'dumpsys window | grep mCurrentFocus'],
                                     check=True, capture_output=True, text=True)
            if 'com.github.cyrilpeng.veneranext.readerbenchmark/' not in focused.stdout:
                raise ValueError('Benchmark is not focused; do not capture another app screen')
            data['completed'].append({'name': name, 'variant': variant, 'scenario': scenario,
                                      'signature': signature})
            manifest.write_text(json.dumps(data, indent=2))
    data['sameInputNavigationAndPrewarm'] = {
        scene: all(s == values[0] for s in values) for scene, values in signatures.items()
    }
    manifest.write_text(json.dumps(data, indent=2))
    if not all(data['sameInputNavigationAndPrewarm'].values()):
        raise ValueError('Do not compare timing: input/navigation/starting residency differed')
    print('COMPLETED: compare CPU and presentation as well as FrameTiming', flush=True)


if __name__ == '__main__':
    main()
