"""Compare controller alignment during input; never infer screen presentation."""
import argparse
import bisect
import json
from pathlib import Path

from summarize import distribution


def analyze(report, injected=None, tolerance=.001):
    calibration = min(report['calibration'], key=lambda c: c['dartEndUs'] - c['dartBeginUs'])
    offset = (calibration['dartBeginUs'] + calibration['dartEndUs']) / 2 - calibration['monoNs'] / 1000
    if injected:
        start = injected['events'][0][1] / 1000 + offset
        stop = injected['events'][-1][1] / 1000 + offset
        window = 'actual injected first DOWN through UP'
    else:
        keys = report['native']['keys']
        if not keys:
            raise ValueError('Requires key input or an injected input window')
        start, stop = keys[0][0] / 1000 + offset, keys[-1][0] / 1000 + offset
        window = 'native first through last DOWN; UP not recorded'
    start, stop = max(start, report['startedUs']), min(stop, report['stoppedUs'])
    if stop <= start:
        raise ValueError('No valid input window')
    points = [(report['startedUs'], float(report['before']['page']))]
    points += [(e[0], e[2]) for e in report['events'] if e[1] == 'position' and e[2] is not None]
    points.sort()
    times = [p[0] for p in points]

    def aligned(value):
        return abs(value - round(value)) <= tolerance

    i = max(0, bisect.bisect_right(times, start) - 1)
    previous = start
    state = aligned(points[i][1])
    segment_start = start
    aligned_us = 0
    segments = []
    for timestamp, value in points[i + 1:] + [(stop, points[-1][1])]:
        end = min(timestamp, stop)
        if state:
            aligned_us += max(0, end - previous)
        next_state = aligned(value)
        if state and (not next_state or end == stop):
            segments.append(max(0, end - segment_start) / 1000)
        elif not state and next_state:
            segment_start = end
        state = next_state
        previous = end
        if end == stop:
            break
    frames = [f for f in report['frames'] if start <= f[2] <= stop]
    near = sum(aligned(points[max(0, bisect.bisect_right(times, f[2]) - 1)][1]) for f in frames)
    return {
        'window': window, 'windowMs': round((stop - start) / 1000, 3),
        'tolerancePages': tolerance,
        'controllerAlignedTimePct': round(aligned_us / (stop - start) * 100, 3),
        'observedAlignedSegmentsMs': distribution(segments),
        'producedUiFrames': len(frames), 'framesWithAlignedControllerAtUiFinish': near,
        'framesWithAlignedControllerPct': round(near / len(frames) * 100, 3) if frames else None,
        'calibrationRttUs': calibration['dartEndUs'] - calibration['dartBeginUs'],
        'limits': 'Controller observations use a step function; UI-finish positions proxy frame content only in these key-input windows. Neither controller time nor produced-frame counts measure SurfaceFlinger presentation or screen FPS.',
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    args = parser.parse_args()
    report = json.loads((args.capture / 'capture.json').read_text())
    source = args.capture / 'input-events.json'
    injected = json.loads(source.read_text()) if source.exists() else None
    result = analyze(report, injected)
    (args.capture / 'viewport-alignment.json').write_text(json.dumps(result, indent=2))
    print(args.capture.name, json.dumps(result))


if __name__ == '__main__':
    main()
