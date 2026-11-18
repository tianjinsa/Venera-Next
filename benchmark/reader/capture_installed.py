"""Capture an installed reader after the user prepares its page and settings.

No install, clear, force-stop, setting changes, UI navigation or screenshots.
This complements isolated fixtures; APK identity and input delivery limitations
are recorded explicitly. Raw device/app records remain in the ignored folder.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shlex
import subprocess
import threading
import time

from adb_benchmark import perfetto_config
from surface_capture import find_layer, parse_latency


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--package', required=True, choices=[
        'com.github.cyrilpeng.veneranext', 'com.github.wgh136.venera.prime'])
    parser.add_argument('--name', required=True)
    parser.add_argument('--direction', choices=['forward', 'reverse'], default='forward')
    parser.add_argument('--scenario', choices=['calibrated-hold', 'cached-alternation'], default='calibrated-hold')
    parser.add_argument('--user-start-page', type=int, required=True)
    parser.add_argument('--adb', default='E:/Android/Sdk/platform-tools/adb.exe')
    args = parser.parse_args()
    if not re.fullmatch('[A-Za-z0-9_-]{1,70}', args.name):
        parser.error('Requires a safe capture name')
    here = Path(__file__).resolve().parent
    folder = here / 'raw' / args.name
    folder.mkdir()  # Preserve every earlier capture and failed attempt.

    def run(*commands, input_bytes=None, timeout=30):
        result = subprocess.run([args.adb, *commands], input=input_bytes,
                                capture_output=True, check=True, timeout=timeout)
        return result.stdout.decode('utf-8', errors='replace')

    def require_focus():
        focused = run('shell', 'dumpsys window | grep mCurrentFocus')
        if args.package + '/' not in focused:
            raise ValueError('Prepared reader lost focus; no key input will be sent')

    require_focus()
    apk = run('shell', 'pm', 'path', args.package).splitlines()[0].removeprefix('package:').strip()
    apk_hash = run('shell', 'sha256sum', shlex.quote(apk)).split()[0]
    (folder / 'package.txt').write_text(run('shell', 'dumpsys', 'package', args.package))
    layer = find_layer(run('shell', 'dumpsys SurfaceFlinger --list'), args.package)
    timing = json.loads((here / 'inputs/physical-volume-20hz.json').read_text())
    driver = here / 'artifacts/key-driver/dex/classes.dex'
    digest = hashlib.sha256(driver.read_bytes()).hexdigest()
    remote_driver = '/data/local/tmp/venera-reader-keys-' + digest[:20] + '.dex'
    existing = run('shell', f'if [ -e {remote_driver} ]; then sha256sum {remote_driver}; else echo MISSING; fi').split()
    if existing == ['MISSING']:
        run('push', str(driver), remote_driver)
    elif not existing or existing[0] != digest:
        raise ValueError('Refusing to replace an unexpected device file')

    def snapshot(phase):
        for name, command in {
            'display': ['dumpsys', 'display'], 'battery': ['dumpsys', 'battery'],
            'thermal': ['dumpsys', 'thermalservice'],
            'meminfo': ['dumpsys', 'meminfo', '-s', args.package],
        }.items():
            (folder / f'{phase}-{name}.txt').write_text(run('shell', *command))

    snapshot('before')
    config = perfetto_config(args.package, 18)
    (folder / 'perfetto.pbtxt').write_text(config)
    remote_trace = '/data/misc/perfetto-traces/reader-bench-' + args.name + '.pftrace'
    trace_start = time.monotonic()
    launch = run('shell', 'perfetto', '--txt', '-c', '-', '-o', remote_trace,
                 '--background-wait', input_bytes=config.encode())
    (folder / 'perfetto-launch.txt').write_text(launch)
    stopped, samples, errors = threading.Event(), [], []

    def sample():
        while not stopped.is_set():
            started = time.monotonic_ns()
            try:
                row = parse_latency(run('shell', 'dumpsys SurfaceFlinger --latency ' + shlex.quote(layer), timeout=5))
                row.update(hostStartedNs=started, queryDurationMs=(time.monotonic_ns() - started) / 1e6)
                samples.append(row)
            except (ValueError, subprocess.SubprocessError) as error:
                errors.append(type(error).__name__)
            stopped.wait(.5)

    worker = threading.Thread(target=sample, daemon=True)
    worker.start()
    print('CAPTURE STARTED:', args.scenario, '; keep the screen untouched.', flush=True)
    try:
        require_focus()
        time.sleep(1)
        if args.scenario == 'calibrated-hold':
            sequence = ','.join(map(str, timing['downOffsetsMs']))
            code = 25 if args.direction == 'forward' else 24
            output = run('shell', f'CLASSPATH={remote_driver} app_process /system/bin ReaderBenchKeys {code} {timing["releaseMs"]} {sequence}')
            injected = json.loads(output.split('READER_BENCH_KEYS_JSON ', 1)[1].splitlines()[0])
            (folder / 'input-events.json').write_text(json.dumps(injected, indent=2))
        else:
            codes = ['25' if (i // 2) % 2 == 0 else '24' for i in range(100)]
            (folder / 'input-plan.json').write_text(json.dumps({
                'type': '100 discrete DOWN/UP pairs, two forward then two reverse',
                'codes': codes, 'afterUpDelayMs': 50,
                'limits': 'Cached isolation only, not a held key. Obtain actual event times from Perfetto.',
            }, indent=2))
            run('shell', 'input', 'keyevent', '--async', '--delay', '50', *codes)
        # Keep the settle tail, and allow Perfetto to finish independently.
        time.sleep(3)
        require_focus()
    finally:
        stopped.set()
        worker.join(timeout=6)
        (folder / 'surface-latency.json').write_text(json.dumps({
            'layer': layer, 'samples': samples, 'errors': errors,
            'workerStopped': not worker.is_alive(),
            'columns': ['desiredPresentNs', 'actualPresentNs', 'frameReadyNs'],
            'limits': 'Actual present fences include intentional static intervals. No frame ID mapping or screen drop count.',
        }, indent=2))
    snapshot('after')
    remaining = 19 - (time.monotonic() - trace_start)
    if remaining > 0:
        time.sleep(remaining)
    run('pull', remote_trace, str(folder / 'trace.pftrace'))
    (folder / 'procedure.json').write_text(json.dumps({
        'package': args.package, 'installedApkSha256': apk_hash,
        'userPreparedStartPage': args.user_start_page, 'direction': args.direction,
        'inputDriverSha256': digest,
        'inputSequenceSha256': hashlib.sha256((here / 'inputs/physical-volume-20hz.json').read_bytes()).hexdigest(),
        'scenario': args.scenario,
        'injectedDowns': len(timing['downOffsetsMs']) if args.scenario == 'calibrated-hold' else 100,
        'appReceivedDowns': None,
        'sourceRevision': 'User identifies Next67be06fc; package version alone does not verify source SHA',
        'limits': 'Prepared by user in existing installation. No Dart observer, cache-cap override or equivalent-work assertion. Compare with isolated fixtures as a context check, not strict performance A/B.',
    }, indent=2))
    print('CAPTURE SAVED:', folder.name, flush=True)


if __name__ == '__main__':
    main()
