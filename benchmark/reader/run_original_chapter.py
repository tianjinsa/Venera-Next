"""Run real-image controls while the reader reports 120 Hz.

Only the benchmark packages are installed/stopped. The standard capture gate
checks the actual reader refresh rate before sending input.
"""
import argparse
from pathlib import Path
import re
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['before', 'after', 'synchronous', 'profile']:
        parser.add_argument('--' + name + '-apk', type=Path, required=True)
    parser.add_argument('--prefix', required=True)
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9_-]{1,16}', args.prefix):
        parser.error('Requires a safe short prefix')
    here = Path(__file__).resolve().parent

    def run(script, *arguments):
        subprocess.run([sys.executable, str(here / script), *map(str, arguments)], check=True)

    shared = ['--cache-cap-mib', '192', '--reader-diagnostics', '--expected-pages', '200',
              '--forward-page', '1', '--reverse-page', '80']
    run('run_precache_ab.py', '--before-apk', args.before_apk, '--after-apk', args.after_apk,
        '--prefix', args.prefix + '-main', *shared, '--scenarios', 'hold-forward', 'hold-reverse')
    run('run_precache_ab.py', '--before-apk', args.synchronous_apk, '--after-apk', args.after_apk,
        '--prefix', args.prefix + '-timing', *shared, '--scenarios', 'hold-forward')
    run('run_precache_ab.py', '--before-apk', args.before_apk, '--after-apk', args.after_apk,
        '--prefix', args.prefix + '-cached', '--cache-cap-mib', '192', '--reader-diagnostics',
        '--expected-pages', '200', '--forward-page', '35', '--scenarios', 'cached')
    run('adb_benchmark.py', '--variant', 'next', 'install', args.profile_apk)
    run('profile_capture.py', '--variant', 'next', '--name', args.prefix + '-profile',
        '--input', 'calibrated-hold', '--expected-pages', '200', '--page', '1',
        '--reader-diagnostics')


if __name__ == '__main__':
    main()
