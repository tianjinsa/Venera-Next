"""Summarize numeric probe records; frame budget is not presentation FPS."""
import argparse
from collections import Counter
import json
import math
from pathlib import Path


def distribution(values):
    data = sorted(values)
    if not data:
        return {'n': 0}
    def percentile(p):
        index = (len(data) - 1) * p
        lo, hi = math.floor(index), math.ceil(index)
        return round(data[lo] + (data[hi] - data[lo]) * (index - lo), 4)
    return {'n': len(data), 'p50': percentile(.5), 'p95': percentile(.95), 'p99': percentile(.99), 'max': round(data[-1], 4)}


def summarize(report):
    frames = sorted(f for f in report['frames'] if report['startedUs'] <= f[0] <= report['stoppedUs'])
    events = report['events']
    counts = Counter(event[1] for event in events)
    seconds = (report['stoppedUs'] - report['startedUs']) / 1e6
    ui = [(f[2] - f[1]) / 1000 for f in frames]
    raster = [(f[4] - f[3]) / 1000 for f in frames]
    delay = [(f[1] - f[0]) / 1000 for f in frames]
    gaps = [(b[0] - a[0]) / 1000 for a, b in zip(frames, frames[1:])]
    keys = report['native']['keys']
    key_intervals = [(b[0] - a[0]) / 1e6 for a, b in zip(keys, keys[1:])]
    repeated_intervals = [(b[0] - a[0]) / 1e6 for a, b in zip(keys, keys[1:]) if a[6] > 0 and b[6] == a[6] + 1]
    dart_keys = [event for event in events if event[1] == 'volume']
    repeats = [event for event in events if event[1] == 'request' and event[4] is not None]
    requests = [event for event in events if event[1] == 'request']
    same_target = sum(a[3] == b[3] for a, b in zip(requests, requests[1:]))
    changes = [event for event in events if event[1] == 'setPage' and event[2] != event[3]]
    redundant = sum(event[2] == event[3] for event in events if event[1] == 'setPage')
    stale = sum(event[2] != event[3] for event in events if event[1] == 'animationEnd')
    calibration = min(report['calibration'], key=lambda c: c['dartEndUs'] - c['dartBeginUs'])
    clock_offset = (calibration['dartBeginUs'] + calibration['dartEndUs']) / 2 - calibration['monoNs'] / 1000
    latencies = []
    # Only pair complete captures. Otherwise ordinal pairing can invent latency.
    if len(keys) == len(dart_keys):
        latencies = [(event[0] - key[0] / 1000 - clock_offset) / 1000 for key, event in zip(keys, dart_keys)]
    slow_run = longest = 0
    for value in ui:
        slow_run = slow_run + 1 if value > 1000 / 120 else 0
        longest = max(longest, slow_run)
    return {
        'name': report['name'], 'mode': report['mode'], 'seconds': round(seconds, 3),
        'frames': len(frames), 'uiMs': distribution(ui), 'rasterMs': distribution(raster),
        'vsyncToBuildMs': distribution(delay), 'producedVsyncGapMs': distribution(gaps),
        'uiOver8_333msPct': round(sum(v > 1000 / 120 for v in ui) / len(ui) * 100, 3) if ui else None,
        'longestConsecutiveSlowUi': longest,
        'nativeKeys': len(keys), 'dartKeys': len(dart_keys),
        'nativeKeysPerSecond': round(len(keys) / seconds, 3),
        'nativeKeyIntervalMs': distribution(key_intervals),
        'sustainedRepeatIntervalMs': distribution(repeated_intervals),
        'sustainedRepeatHz': round(1000 / distribution(repeated_intervals)['p50'], 3) if repeated_intervals and distribution(repeated_intervals)['p50'] > 0 else None,
        'nativeRepeatCounts': [key[6] for key in keys],
        'nativeDownTimeCount': len(set(key[4] for key in keys)),
        'nativeToDartMs': distribution(latencies),
        'clockCalibrationRttUs': calibration['dartEndUs'] - calibration['dartBeginUs'],
        'requestsWhilePending': len(repeats), 'successiveSameTarget': same_target,
        'pageChanges': len(changes), 'pageChangesPerSecond': round(len(changes) / seconds, 3),
        'redundantPageChanges': redundant, 'supersededAnimationCompletions': stale,
        'eventCounts': dict(counts), 'droppedEvents': report['droppedEvents'],
        'cpuTimeMs': report['native']['cpuTimeMs'],
        'cpuMsPerSecond': round(report['native']['cpuTimeMs'] / seconds, 3),
        'before': report['before'], 'after': report['after'],
        'actualPresentation': 'Requires SurfaceFlinger FrameTimeline, not inferred from FrameTiming',
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('captures', type=Path, nargs='+')
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    reports = [summarize(json.loads(p.read_text(encoding='utf-8'))) for p in args.captures]
    result = json.dumps(reports, indent=2, ensure_ascii=False)
    if args.out:
        args.out.write_text(result, encoding='utf-8')
    print(result)


if __name__ == '__main__':
    main()
