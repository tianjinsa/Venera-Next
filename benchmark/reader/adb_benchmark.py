"""ADB capture for the isolated reader APKs. No clear/uninstall/delete commands.

`duration` is a calibration candidate, not an assertion that ADB reproduces a
physical hold. Compare native repeatCount/downTime/event intervals first.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shlex
import subprocess
import time

PACKAGES = {
    'next': ('com.github.cyrilpeng.veneranext.readerbenchmark', 'com.github.cyrilpeng.veneranext.MainActivity'),
    'prime': ('com.github.wgh136.venera.prime.readerbenchmark', 'com.github.wgh136.venera.MainActivity'),
}


class Device:
    def __init__(self, adb, variant, serial=None):
        self.prefix = [adb] + (['-s', serial] if serial else [])
        self.package, self.activity = PACKAGES[variant]
        self.remote = f'/sdcard/Android/data/{self.package}/files/reader-bench'

    def run(self, *args, check=True, input_bytes=None):
        result = subprocess.run(self.prefix + list(args), capture_output=True, input=input_bytes)
        if check and result.returncode:
            raise RuntimeError(result.stderr.decode('utf-8', errors='replace') + result.stdout.decode('utf-8', errors='replace'))
        return result.stdout.decode('utf-8', errors='replace')

    def command(self, command, **args):
        params = ['shell', 'am', 'broadcast', '-p', self.package, '-a', self.package + '.READER_BENCH', '--es', 'command', command]
        for key, value in args.items():
            params += ['--ei' if isinstance(value, int) else '--es', key, str(value)]
        return self.run(*params)

    def read_json(self, name):
        result = self.run('shell', 'cat', self.remote + '/' + name, check=False)
        try:
            return json.loads(result)
        except ValueError:
            return None

    def wait_status(self, command, timeout=30):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            status = self.read_json('status.json')
            if status and status.get('command') == command:
                return status
            time.sleep(.3)
        raise TimeoutError(f'No {command!r} status: ' + self.run('shell', 'cat', self.remote + '/error.txt', check=False))

    def launch(self, fresh=False, enable_profiling=False):
        prior = (self.read_json('status.json') or {}).get('timelineUs', 0)
        if fresh:
            self.run('shell', 'am', 'force-stop', self.package)
        activity_args = ['shell', 'am', 'start', '-n', self.package + '/' + self.activity]
        if enable_profiling:
            activity_args += ['--ez', 'enable-dart-profiling', 'true']
        self.run(*activity_args)
        deadline = time.monotonic() + 60
        # Existing singleTop Activities do not initialize again. A fresh ping
        # acknowledgement works for both a new process and a resumed reader.
        while time.monotonic() < deadline:
            self.command('ping')
            time.sleep(1)
            status = self.read_json('status.json')
            if status and status.get('command') == 'ping' and status.get('timelineUs', 0) > prior:
                return status
        raise TimeoutError('No fresh benchmark acknowledgement after launch')

    def snapshot(self, directory, phase):
        commands = {
            'display': ['dumpsys', 'display'],
            'thermal': ['dumpsys', 'thermalservice'],
            'battery': ['dumpsys', 'battery'],
            'meminfo': ['dumpsys', 'meminfo', '-s', self.package],
            'cpuinfo': ['dumpsys', 'cpuinfo', self.package],
        }
        for name, args in commands.items():
            (directory / f'{phase}-{name}.txt').write_text(self.run('shell', *args, check=False), encoding='utf-8')


def perfetto_config(package, duration):
    return f'''buffers {{ size_kb: 65536 fill_policy: RING_BUFFER }}
duration_ms: {int(duration * 1000)}
data_sources {{ config {{ name: "linux.ftrace" ftrace_config {{
  ftrace_events: "sched/sched_switch"
  ftrace_events: "sched/sched_waking"
  ftrace_events: "power/cpu_frequency"
  ftrace_events: "power/cpu_idle"
  atrace_categories: "gfx"
  atrace_categories: "view"
  atrace_categories: "input"
  atrace_categories: "wm"
  atrace_apps: "{package}"
  compact_sched {{ enabled: true }}
}} }} }}
data_sources {{ config {{ name: "linux.process_stats" process_stats_config {{
  scan_all_processes_on_start: true proc_stats_poll_ms: 1000
}} }} }}
data_sources {{ config {{ name: "linux.sys_stats" sys_stats_config {{
  stat_period_ms: 1000 cpufreq_period_ms: 1000
}} }} }}
data_sources {{ config {{ name: "android.surfaceflinger.frametimeline" }} }}
data_sources {{ config {{ name: "android.gpu.memory" }} }}
data_sources {{ config {{ name: "android.power" android_power_config {{
  battery_poll_ms: 1000 collect_power_rails: true
}} }} }}
'''


def capture(device, args):
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,80}', args.name):
        raise ValueError('Invalid capture name')
    folder = args.out / args.name
    folder.mkdir(parents=True, exist_ok=False)
    initial = device.launch(fresh=not args.reuse_process)
    if initial.get('pageCount') != 512 or initial.get('refreshHz', 0) < 119:
        raise ValueError('Requires a ready 512-page reader at 120 Hz')
    if args.expected_cache_mib and initial.get('cacheLimitBytes') != args.expected_cache_mib * 1024 * 1024:
        raise ValueError('Unexpected cache budget; do not mix pressure and normal baselines')
    package_path = device.run('shell', 'pm', 'path', device.package).splitlines()[0].removeprefix('package:').strip()
    installed_hash = device.run('shell', 'sha256sum', shlex.quote(package_path)).split()[0]
    if not re.fullmatch('[0-9a-fA-F]{64}', installed_hash):
        raise ValueError('Cannot identify installed benchmark APK')
    # Visit a neighbour first, so a preceding double-tap/zoom probe cannot leave
    # the next swipe scenario inside a zoomed PhotoView at the same page.
    device.command('position', page=args.page + 1 if args.page < 512 else args.page - 1)
    device.wait_status('position')
    time.sleep(.3)
    device.command('position', page=args.page)
    device.wait_status('position')
    time.sleep(args.settle)
    device.snapshot(folder, 'before')
    trace_duration = args.seconds + 6
    if args.perfetto:
        config = folder / 'perfetto.pbtxt'
        config.write_text(perfetto_config(device.package, trace_duration), encoding='utf-8')
        remote = '/data/misc/perfetto-traces/reader-bench-' + args.name
        # Android's perfetto domain may not read shell_data_file in local/tmp.
        # Feed configuration on stdin and use the platform trace output folder.
        launch = device.run('shell', 'perfetto', '--txt', '-c', '-', '-o', remote + '.pftrace', '--background-wait', input_bytes=config.read_bytes())
        (folder / 'perfetto-launch.txt').write_text(launch, encoding='utf-8')
        trace_started = time.monotonic()
    device.command('capture', name=args.name, seconds=args.seconds)
    status = device.wait_status('capture')
    (folder / 'start-status.json').write_text(json.dumps(status, indent=2), encoding='utf-8')
    print('CAPTURING', args.name, 'input=', args.input, flush=True)
    start = time.monotonic()
    if args.input == 'duration':
        time.sleep(1)
        device.run('shell', 'input', 'keyevent', '--duration', str(args.hold_ms), '25' if args.direction == 'forward' else '24')
    elif args.input == 'keysequence':
        time.sleep(1)
        # Legal discrete DOWN/UP pairs. This deliberately retains repeatCount=0
        # and is labelled separately from the pending physical-hold validation.
        code = '25' if args.direction == 'forward' else '24'
        device.run('shell', 'input', 'keyevent', '--async', '--delay', str(args.key_delay_ms), *([code] * args.count))
    elif args.input == 'taps':
        time.sleep(1)
        # A single remote shell preserves the requested cadence between touches.
        # This scenario is labelled taps and is never called a held volume key.
        x = 920 if args.direction == 'forward' else 160
        script = f'for i in $(seq 1 {args.count}); do input tap {x} 1200; sleep {args.interval}; done'
        device.run('shell', script)
    elif args.input == 'swipes':
        time.sleep(1)
        coords = '920 1200 160 1200' if args.direction == 'forward' else '160 1200 920 1200'
        script = f'for i in $(seq 1 {args.count}); do input swipe {coords} {args.swipe_ms}; sleep {args.interval}; done'
        device.run('shell', script)
    elif args.input == 'manual':
        print('PHYSICAL HOLD: hold at the high tone; release at the low tone.', flush=True)
        time.sleep(1)
        try:
            import winsound
            winsound.Beep(1000, 200)
        except ImportError:
            print('\a', end='', flush=True)
        time.sleep(args.hold_ms / 1000)
        try:
            import winsound
            winsound.Beep(500, 350)
        except ImportError:
            print('\a', end='', flush=True)
    while time.monotonic() - start < args.seconds + 1.6:
        time.sleep(.3)
    device.wait_status('saved', timeout=15)
    device.run('pull', device.remote + '/' + args.name + '.json', str(folder / 'capture.json'))
    device.snapshot(folder, 'after')
    if args.perfetto:
        while time.monotonic() - trace_started < trace_duration + .7:
            time.sleep(.3)
        device.run('pull', remote + '.pftrace', str(folder / 'trace.pftrace'))
    metadata = {k: str(v) if isinstance(v, Path) else v for k, v in vars(args).items() if k not in ('serial', 'adb')}
    metadata['package'] = device.package
    metadata['installedApkSha256'] = installed_hash.lower()
    metadata['captureSha256'] = hashlib.sha256((folder / 'capture.json').read_bytes()).hexdigest()
    (folder / 'procedure.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    report = json.loads((folder / 'capture.json').read_text(encoding='utf-8'))
    if report['before'].get('pageCount') != 512:
        raise ValueError('Fixture was not ready: results are invalid')
    print('SAVED', folder, 'frames=', len(report['frames']), 'nativeKeys=', len(report['native']['keys']), 'page=', report['before'].get('page'), '->', report['after'].get('page'), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', default='E:/Android/Sdk/platform-tools/adb.exe')
    parser.add_argument('--serial')
    parser.add_argument('--variant', choices=PACKAGES, required=True)
    sub = parser.add_subparsers(dest='action', required=True)
    sub.add_parser('launch')
    pos = sub.add_parser('position')
    pos.add_argument('page', type=int)
    install = sub.add_parser('install')
    install.add_argument('apk', type=Path)
    install.add_argument('--aapt', default='E:/Android/Sdk/build-tools/36.0.0/aapt.exe')
    sample = sub.add_parser('capture')
    sample.add_argument('--out', type=Path, default=Path(__file__).resolve().parent / 'raw')
    sample.add_argument('--name', required=True)
    sample.add_argument('--seconds', type=int, default=12)
    sample.add_argument('--page', type=int, default=160)
    sample.add_argument('--settle', type=float, default=3)
    sample.add_argument('--input', choices=['manual', 'duration', 'keysequence', 'taps', 'swipes', 'idle'], default='idle')
    sample.add_argument('--direction', choices=['forward', 'reverse'], default='forward')
    sample.add_argument('--hold-ms', type=int, default=8000)
    sample.add_argument('--count', type=int, default=20)
    sample.add_argument('--interval', type=float, default=.2)
    sample.add_argument('--swipe-ms', type=int, default=100)
    sample.add_argument('--key-delay-ms', type=int, default=50)
    sample.add_argument('--perfetto', action='store_true')
    sample.add_argument('--reuse-process', action='store_true', help='For explicitly labelled warm-window or memory-pressure probes')
    sample.add_argument('--expected-cache-mib', type=int, default=192, help='Use 0 only for explicitly labelled pressure-policy experiments')
    args = parser.parse_args()
    device = Device(args.adb, args.variant, args.serial)
    if args.action == 'install':
        badging = subprocess.check_output([args.aapt, 'dump', 'badging', str(args.apk)], text=True, encoding='utf-8', errors='replace')
        if f"package: name='{device.package}'" not in badging:
            raise ValueError('Refusing an APK with a non-benchmark application ID')
        print(device.run('install', '-r', '--no-streaming', str(args.apk)))
    elif args.action == 'launch':
        print(json.dumps(device.launch(), indent=2))
    elif args.action == 'position':
        device.command('position', page=args.page)
        print(json.dumps(device.wait_status('position'), indent=2))
    else:
        capture(device, args)


if __name__ == '__main__':
    main()
