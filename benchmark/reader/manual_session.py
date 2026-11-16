"""Arm sampling before the live hold prompt; finish without hidden prompts."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shlex
import time

from adb_benchmark import Device, perfetto_config
from summarize import summarize


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['arm', 'finish'])
    parser.add_argument('--variant', required=True, choices=['next', 'prime'])
    parser.add_argument('--name', required=True)
    parser.add_argument('--seconds', type=int, default=20)
    args = parser.parse_args()
    if not re.fullmatch('[A-Za-z0-9_-]{1,80}', args.name):
        raise ValueError('Invalid capture name')
    folder = Path(__file__).resolve().parent / 'raw' / args.name
    d = Device('E:/Android/Sdk/platform-tools/adb.exe', args.variant)
    remote_trace = '/data/misc/perfetto-traces/reader-bench-' + args.name + '.pftrace'
    if args.action == 'arm':
        folder.mkdir(parents=True, exist_ok=False)
        print('PREPARING: starting the isolated Release reader; do not hold yet.', flush=True)
        ready = d.launch(fresh=True)
        if ready.get('refreshHz', 0) < 119 or ready.get('cacheLimitBytes') != 192 << 20 or ready.get('pageCount') != 512:
            raise ValueError('Requires the ready 512-page 120 Hz / 192 MiB fixture')
        for page in (161, 160):
            d.command('position', page=page)
            d.wait_status('position')
            time.sleep(.3)
        time.sleep(3)
        d.snapshot(folder, 'before')
        path = d.run('shell', 'pm', 'path', d.package).splitlines()[0].removeprefix('package:').strip()
        digest = d.run('shell', 'sha256sum', shlex.quote(path)).split()[0]
        config = perfetto_config(d.package, args.seconds + 6)
        (folder / 'perfetto.pbtxt').write_text(config, encoding='utf-8')
        trace_start = time.monotonic()
        d.run('shell', 'perfetto', '--txt', '-c', '-', '-o', remote_trace, '--background-wait', input_bytes=config.encode())
        d.command('capture', name=args.name, seconds=args.seconds)
        status = d.wait_status('capture')
        (folder / 'start-status.json').write_text(json.dumps(status, indent=2))
        (folder / 'manual-state.json').write_text(json.dumps({'traceStart': trace_start, 'seconds': args.seconds, 'package': d.package, 'installedApkSha256': digest}))
        print('SAMPLER ARMED: frame and native-key recording are active.', flush=True)
    else:
        state = json.loads((folder / 'manual-state.json').read_text())
        remaining = state['traceStart'] + state['seconds'] + 6.8 - time.monotonic()
        if remaining > 0:
            time.sleep(remaining)
        d.wait_status('saved', timeout=15)
        d.run('pull', d.remote + '/' + args.name + '.json', str(folder / 'capture.json'))
        d.snapshot(folder, 'after')
        d.run('pull', remote_trace, str(folder / 'trace.pftrace'))
        state.update({'input': 'physical-hold', 'captureSha256': hashlib.sha256((folder / 'capture.json').read_bytes()).hexdigest()})
        (folder / 'procedure.json').write_text(json.dumps(state, indent=2))
        report = json.loads((folder / 'capture.json').read_text())
        summary = summarize(report)
        (folder / 'summary.json').write_text(json.dumps(summary, indent=2))
        print('SAVED:', args.name, 'native=', summary['nativeKeys'], 'Dart=', summary['dartKeys'], 'repeatHz=', summary['sustainedRepeatHz'], 'pages=', summary['before']['page'], '->', summary['after']['page'], flush=True)


if __name__ == '__main__':
    main()
