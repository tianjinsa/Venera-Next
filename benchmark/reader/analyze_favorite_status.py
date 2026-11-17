"""Compare fixed generated-favorite captures with identical decoded residency."""
import argparse
import json
from pathlib import Path
import re

from summarize import distribution, summarize


def sync_read_spans(events):
    starts, durations = [], []
    for row in events:
        if row[1] == 'favoriteSql':
            starts.append(row[0])
        elif row[1] == 'favoriteSqlEnd':
            if not starts:
                raise ValueError('Unpaired favorite SQL completion')
            durations.append((row[0] - starts.pop()) / 1000)
    if starts:
        raise ValueError('Incomplete favorite SQL span')
    return distribution(durations)


def memory(path):
    text = path.read_text()
    return {name: int(m[1]) if (m := re.search(r'TOTAL ' + name + r':\s*(\d+)', text)) else None
            for name in ['PSS', 'RSS']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('captures', type=Path, nargs='+')
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    runs = []
    resident = set()
    for p in args.captures:
        report = json.loads((p / 'capture.json').read_text())
        s = summarize(report)
        if (s['mode'] != 'release' or s['nativeKeys'] != 100 or s['dartKeys'] != 100 or
                s['pageChanges'] != 50 or s['distinctMissKeys'] or s['distinctSourceKeys']):
            raise ValueError(f'{p.name}: not the fixed cached key scenario')
        for phase in ['before', 'after']:
            snap = s[phase]
            if snap['cacheLimitBytes'] != 192 << 20 or snap['refreshHz'] < 119 or snap['pendingImages']:
                raise ValueError(f'{p.name}: wrong budget/rate/pending')
            resident.add((snap['cacheBytes'], snap['cacheImages']))
        s['syncFavoriteReadWallMs'] = sync_read_spans(report['events'])
        s['dumpsysMemoryKb'] = {phase: memory(p / f'{phase}-meminfo.txt') for phase in ['before', 'after']}
        s['batteryTemperatureTenthsC'] = {
            phase: int(re.search(r'temperature:\s*(\d+)', (p / f'{phase}-battery.txt').read_text())[1])
            for phase in ['before', 'after']}
        schedule = p / 'cpu-schedule.json'
        if schedule.exists():
            s['cpuPlacement'] = json.loads(schedule.read_text())['rows']
        runs.append(s)
    if len(resident) != 1:
        raise ValueError('Do not compare different decoded working sets')
    args.out.write_text(json.dumps({
        'fixtureFavoritePages': 1000, 'fixtureFavoriteChapters': 10,
        'baseProductSha': 'b76652d66651015858890ace74eb1b721682e0bf',
        'candidateSourceSeal': 'raw/next-favorites-after-release-source.json',
        'limits': 'SQL span is synchronous wall time, not exact CPU time. Cached pages still use ordered data admission. No presented dropped-frame claim. Compare only identical resident sets and record CPU frequency.',
        'runs': runs,
    }, indent=2), encoding='utf-8')
    print('Saved', len(runs), 'matched-residency runs to', args.out)


if __name__ == '__main__':
    main()
