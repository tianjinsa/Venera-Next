"""Summarize clock-aligned SurfaceView present fences, preserving idle gaps."""
import argparse
import json
from pathlib import Path

from summarize import distribution

PENDING_FENCE = (1 << 63) - 1


def analyze(report, latency):
    c = min(report['calibration'], key=lambda c: c['dartEndUs'] - c['dartBeginUs'])
    offset = (c['dartBeginUs'] + c['dartEndUs']) / 2 - c['monoNs'] / 1000
    start, stop = [(report[key] - offset) * 1000 for key in ['startedUs', 'stoppedUs']]
    rows, overflows = {}, []
    previous = set()
    periods = set()
    for sample in latency['samples']:
        periods.add(sample['periodNs'])
        valid = {(d, a, r) for d, a, r in sample['rows'] if 0 < d < PENDING_FENCE and 0 < a < PENDING_FENCE and 0 < r < PENDING_FENCE}
        if previous and valid and not (previous & valid) and len(valid) >= 127:
            overflows.append(sample['hostStartedNs'])
        for row in valid:
            rows[(row[0], row[2])] = row
        previous = valid
    presented = sorted((row for row in rows.values() if start <= row[1] <= stop), key=lambda row: row[1])
    gaps = [(b[1] - a[1]) / 1e6 for a, b in zip(presented, presented[1:])]
    query_cost = [s['queryDurationMs'] for s in latency['samples']]
    sample_gaps = [(b['hostStartedNs'] - a['hostStartedNs']) / 1e9 for a, b in zip(latency['samples'], latency['samples'][1:])]
    return {
        'presentedSurfaceBuffers': len(presented), 'periodNs': sorted(periods),
        'actualPresentGapMs': distribution(gaps),
        'actualMinusDesiredMs': distribution([(r[1] - r[0]) / 1e6 for r in presented]),
        'readyToActualPresentMs': distribution([(r[1] - r[2]) / 1e6 for r in presented]),
        'possibleRingOverflows': len(overflows), 'sampleErrors': len(latency['errors']),
        'queryWallMs': distribution(query_cost), 'hostSampleGapSeconds': distribution(sample_gaps),
        'clockCalibrationRttUs': c['dartEndUs'] - c['dartBeginUs'],
        'limits': latency['limits'], 'actualDroppedFrameCount': None,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    args = parser.parse_args()
    result = analyze(json.loads((args.capture / 'capture.json').read_text()),
                     json.loads((args.capture / 'surface-latency.json').read_text()))
    (args.capture / 'presentation-summary.json').write_text(json.dumps(result, indent=2))
    print(args.capture.name, json.dumps(result))


if __name__ == '__main__':
    main()
