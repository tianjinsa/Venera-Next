"""Coordinate CPU/Timeline collection with a labelled ADB gesture capture."""
import argparse
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlsplit

from adb_benchmark import Device


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--variant', choices=['next', 'prime'], required=True)
    parser.add_argument('--name', required=True)
    parser.add_argument('--input', choices=['swipes', 'keysequence'], default='swipes')
    parser.add_argument('--count', type=int, default=20)
    parser.add_argument('--widget-builds', action='store_true', help='Diagnostic build tracking adds overhead; never compare its timings with Release')
    parser.add_argument('--touch-driver', choices=['adb', 'fixed'], default='adb')
    parser.add_argument('--interval', type=float, default=.02)
    parser.add_argument('--alternate', action='store_true')
    parser.add_argument('--warm-radius', type=int, choices=range(3), default=0)
    parser.add_argument('--expected-cache-mib', type=int, default=192,
                        help='0 permits a diagnostic with its actual budget; do not use it for matched Release A/B')
    parser.add_argument('--adb', default='E:/Android/Sdk/platform-tools/adb.exe')
    parser.add_argument('--dart', default='D:/.tool/flutter-3.41.4/bin/cache/dart-sdk/bin/dart.exe')
    parser.add_argument('--out', type=Path, default=Path(__file__).resolve().parent / 'raw')
    args = parser.parse_args()
    device = Device(args.adb, args.variant)
    device.launch(fresh=True, enable_profiling=True)
    process_id = device.run('shell', 'pidof', device.package).strip()
    logs = device.run('logcat', '--pid=' + process_id, '-d', '-s', 'flutter:I')
    match = re.search(r'(?:Dart VM service|Observatory).*?(http://127\.0\.0\.1:\d+/\S*)', logs)
    if not match:
        raise RuntimeError('Profile VM service not found; install the Profile APK first')
    uri = urlsplit(match.group(1))
    port = device.run('forward', 'tcp:0', 'tcp:' + str(uri.port)).strip()
    ws = f'ws://127.0.0.1:{port}{uri.path.rstrip("/")}/ws'
    output = args.out / (args.name + '-vm')
    if output.exists():
        raise ValueError('VM output already exists')
    vm = None
    try:
        collector = [args.dart, str(Path(__file__).with_name('vm_trace.dart')), ws, str(output), '35']
        if args.widget_builds:
            collector += ['--widget-builds']
        vm = subprocess.Popen(collector, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding='utf-8')
        # No periodic status queries. Wait on the explicit VM-ready marker.
        lines = []
        for line in vm.stdout:
            lines.append(line)
            if 'VM CAPTURE READY' in line:
                break
        else:
            raise RuntimeError(''.join(lines))
        command = [sys.executable, str(Path(__file__).with_name('adb_benchmark.py')), '--adb', args.adb, '--variant', args.variant, 'capture', '--name', args.name, '--out', str(args.out), '--seconds', '14', '--input', args.input, '--count', str(args.count), '--interval', str(args.interval), '--swipe-ms', '80', '--key-delay-ms', '50', '--perfetto', '--reuse-process', '--touch-driver', args.touch_driver, '--warm-radius', str(args.warm_radius)]
        command += ['--expected-cache-mib', str(args.expected_cache_mib)]
        if args.alternate:
            command += ['--alternate']
        subprocess.run(command, check=True)
        lines.extend(vm.stdout.readlines())
        result = vm.wait(timeout=60)
        output.mkdir(parents=True, exist_ok=True)
        (output / 'collector.log').write_text(''.join(lines), encoding='utf-8')
        if result:
            raise RuntimeError('VM collection failed; see collector.log')
        print('Saved CPU samples and Timeline:', output)
    finally:
        if vm and vm.poll() is None:
            vm.terminate()
            vm.wait(timeout=15)
        device.run('forward', '--remove', 'tcp:' + port, check=False)


if __name__ == '__main__':
    main()
