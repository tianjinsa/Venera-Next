"""Focus real-chapter evidence on a page range using numeric command markers.

The phase clock is aligned only if every cache-replacement marker pairs with
its immediately following production diagnostic marker. It is not inferred
from FrameTiming callback delivery or wall time.
"""
import argparse
import json
from pathlib import Path
import statistics

from analyze_cadence import analyze as cadence
from analyze_frame_requests import analyze as requests
from summarize import distribution


def diagnostic_clock(report, diagnostic):
    raw = [e for e in report['events'] if e[1] == 'cacheReplace']
    relative = [e for e in diagnostic['imageEvents']
                if e['stage'] == 'navigation' and e['phase'] == 'precacheStarted']
    if len(raw) != len(relative) or not raw:
        raise ValueError('Cannot align incomplete navigation markers')
    origin_page = raw[0][2] - relative[0]['pageOffset']
    if any((a[2] - origin_page, a[3] - origin_page) !=
           (b['pageOffset'], b['targetOffset']) for a, b in zip(raw, relative)):
        raise ValueError('Navigation marker correspondence is ambiguous')
    offsets = [a[0] - b['atUs'] for a, b in zip(raw, relative)]
    offset = statistics.median(offsets)
    uncertainty = max(abs(o - offset) for o in offsets)
    if uncertainty > 500:
        raise ValueError('Navigation marker delay too large for this alignment')
    return offset, {
        'pairs': len(raw), 'maxDeviationUs': uncertainty,
        'meaning': 'Median adjacent marker offset; includes small unmeasured call overhead',
    }


def analyze(report, diagnostic, low=1, high=50):
    commands = [e for e in report['events'] if e[1] == 'request']
    in_range = [e for e in commands if low <= e[3] <= high]
    if not in_range:
        raise ValueError('No commands into requested page range')
    start = in_range[0][0]
    end = next((e[0] for e in commands if e[0] > start and not low <= e[3] <= high),
               report['stoppedUs'])
    cropped = dict(report, startedUs=start, stoppedUs=end,
                   events=[e for e in report['events'] if start <= e[0] <= end])
    frames = [f for f in report['frames'] if start <= f[0] <= end]
    first = {}
    for event in report['events']:
        if event[1] == 'displayResolveStatus':
            first.setdefault(event[2], event)
    displays = [e for e in first.values() if start <= e[0] < end]
    result = {
        'name': report['name'], 'requestedRange': [low, high],
        'selectedRange': sorted({e[2] for e in cropped['events'] if e[1] == 'selected'}),
        'seconds': (end - start) / 1e6,
        'uiMs': distribution([(f[2] - f[1]) / 1000 for f in frames]),
        'rasterMs': distribution([(f[4] - f[3]) / 1000 for f in frames]),
        'cadence': cadence(cropped), 'frameRequests': requests(cropped),
        'firstDisplayLookups': len(displays),
        'firstDisplayReady': sum(e[3] or (e[4] and not e[5]) for e in displays),
        'firstDisplayPending': sum(e[5] for e in displays),
    }
    offset, result['clockAlignment'] = diagnostic_clock(report, diagnostic)
    result['imageWaitMs'] = {
        stage: distribution([e['waitUs'] / 1000 for e in diagnostic['imageEvents']
                             if e['stage'] == stage and start <= e['atUs'] + offset < end])
        for stage in ['displayWait', 'firstDecodeWait', 'localRead', 'sourceRead', 'precacheWait']
    }
    result['limits'] = 'Command-bounded page window, not image-content visibility or CPU time. '
    result['limits'] += 'A reverse run need not reach all pages in the requested range.'
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('captures', type=Path, nargs='+')
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    rows = [analyze(json.loads((p / 'capture.json').read_text()),
                    json.loads((p / 'production-diagnostics.json').read_text())) for p in args.captures]
    args.out.write_text(json.dumps({'runs': rows}, indent=2) + '\n', encoding='utf-8')
    for row in rows:
        print(row['name'], row['firstDisplayReady'], '/', row['firstDisplayLookups'],
              row['imageWaitMs']['displayWait'])
