"""Separate command-animation cadence from intentional gaps between commands.

Animation intervals come from the same numeric observers in Prime and Next.
They exclude touch ballistic activity, which requires a different phase source.
Neither produced-frame gaps nor present-fence gaps count dropped screen frames.
"""
import argparse
import json
from pathlib import Path

from analyze_presentation import PENDING_FENCE
from summarize import distribution


def animation_intervals(report):
    intervals, start = [], None
    for event in sorted(report['events'], key=lambda e: e[0]):
        at, name = event[:2]
        if name == 'animate':
            if start is not None:
                intervals.append((start, at))
            start = at
        elif name == 'jump' or (name == 'animationEnd' and event[2] == event[3]):
            if start is not None:
                intervals.append((start, at))
                start = None
    if start is not None:
        intervals.append((start, report['stoppedUs']))
    return intervals


def same_interval_gaps(points, intervals):
    """points are (classification timestamp us, measured timestamp us)."""
    points = sorted(points)
    return [(b[1] - a[1]) / 1000 for a, b in zip(points, points[1:])
            if any(start <= a[0] < b[0] <= end for start, end in intervals)]


def analyze(report, latency=None):
    intervals = animation_intervals(report)
    frames = sorted(f for f in report['frames']
                    if report['startedUs'] <= f[0] <= report['stoppedUs'])
    active_gaps = same_interval_gaps([(f[0], f[0]) for f in frames], intervals)
    period_ms = 1000 / report['before']['refreshHz']
    active = [f for f in frames if any(s <= f[0] <= e for s, e in intervals)]
    result = {
        'name': report['name'], 'commandAnimationIntervals': len(intervals),
        'allProducedVsyncGapMs': distribution([(b[0] - a[0]) / 1000
                                              for a, b in zip(frames, frames[1:])]),
        'sameAnimationProducedVsyncGapMs': distribution(active_gaps),
        'sameAnimationGapsAboveOneAndHalfRefreshPeriods':
            sum(gap > period_ms * 1.5 for gap in active_gaps),
        'activeVsyncToBuildMs': distribution([(f[1] - f[0]) / 1000 for f in active]),
        'activeUiMs': distribution([(f[2] - f[1]) / 1000 for f in active]),
        'activeRasterMs': distribution([(f[4] - f[3]) / 1000 for f in active]),
        'allUiExecutionMs': round(sum(f[2] - f[1] for f in frames) / 1000, 3),
        'sameAnimationPositionUpdateGapMs': distribution(same_interval_gaps(
            [(e[0], e[0]) for e in report['events'] if e[1] == 'position'], intervals)),
        'limits': 'Only instrumented command animate start through jump or matching completion. '
                  'Stale completion never closes a newer animation. Intervals are not exact '
                  'ticker ticks or screen visibility. Touch ballistic activity is not classified. '
                  'No screen FPS or dropped-frame rate is inferred.',
    }
    if latency:
        clock = min(report['calibration'], key=lambda c: c['dartEndUs'] - c['dartBeginUs'])
        offset = (clock['dartBeginUs'] + clock['dartEndUs']) / 2 - clock['monoNs'] / 1000
        rows = set(tuple(row) for sample in latency['samples'] for row in sample['rows']
                   if all(0 < value < PENDING_FENCE for value in row))
        # Frame-ready time selects the interval, avoiding presentation latency
        # shifting an animation's final buffer into the next static interval.
        points = [(ready / 1000 + offset, actual / 1000 + offset)
                  for _, actual, ready in rows]
        result['sameAnimationReadyBuffersActualPresentGapMs'] = distribution(
            same_interval_gaps(points, intervals))
        result['presentFenceClassification'] = 'Interval by ready time; gap by actual present time. '
        result['presentFenceClassification'] += 'No per-buffer frame ID mapping; includes pipeline latency.'
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('captures', type=Path, nargs='+')
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    rows = []
    for folder in args.captures:
        report = json.loads((folder / 'capture.json').read_text())
        surface = folder / 'surface-latency.json'
        rows.append(analyze(report, json.loads(surface.read_text()) if surface.exists() else None))
    args.out.write_text(json.dumps({'runs': rows}, indent=2) + '\n', encoding='utf-8')
    for row in rows:
        print(row['name'], 'same-animation vsync:', row['sameAnimationProducedVsyncGapMs'])


if __name__ == '__main__':
    main()
