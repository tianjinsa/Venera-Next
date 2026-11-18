"""Explain in-animation frame gaps using an existing probe capture and Perfetto.

The OEM TimerDispatch slices in these traces expose the nominal app wakeup
time. Match both endpoints to FrameTiming.vsyncStart, then look for the missing
pulse and the binder request attributed to the reader by sched_waking.
"""
import argparse
from bisect import bisect_right
from collections import defaultdict
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess

from analyze_cadence import animation_intervals
from analyze_page_window import diagnostic_clock
from summarize import distribution


def trace_events(processor, trace, package):
    if not re.fullmatch(r'[a-z0-9._]+\.readerbenchmark', package):
        raise ValueError('Requires the isolated reader benchmark package')
    sql = f"""
WITH
clock AS (SELECT ts-clock_value AS ns FROM clock_snapshot
          WHERE clock_name='MONOTONIC' ORDER BY ts LIMIT 1),
reader AS (SELECT utid FROM thread JOIN process USING (upid)
           WHERE process.name='{package}' AND is_main_thread=1),
requests AS (
  SELECT s.ts, ready.ts AS wake_ts
  FROM slice s JOIN thread_track tt ON s.track_id=tt.id
  JOIN thread t USING (utid) JOIN process p USING (upid)
  JOIN thread_state run ON run.utid=tt.utid AND run.state='Running'
    AND s.ts>=run.ts AND s.ts<run.ts+run.dur
  JOIN thread_state ready ON ready.utid=run.utid AND ready.state='R'
    AND ready.ts+ready.dur=run.ts
  WHERE p.name='/system/bin/surfaceflinger' AND s.name='requestNextVsync'
    AND ready.waker_utid IN (SELECT utid FROM reader)
)
SELECT 'request' AS kind, ts-ns AS at_ns, CAST(wake_ts-ns AS TEXT) AS detail
FROM requests, clock
UNION ALL
SELECT 'pulse', ts-ns, name FROM slice, clock
WHERE name GLOB 'timerCallback:*VSYNC-app(wakeupTime)*'
UNION ALL
SELECT 'callback', s.ts-ns, '' FROM slice s
JOIN thread_track tt ON s.track_id=tt.id, clock
WHERE s.name='AChoreographer_frameCallback64'
  AND tt.utid IN (SELECT utid FROM reader)
ORDER BY at_ns;
"""
    result = subprocess.run(
        [processor, 'query', '--format', 'csv', str(trace), sql],
        capture_output=True, check=True, encoding='utf-8',
    )
    groups = defaultdict(list)
    for row in csv.DictReader(io.StringIO(result.stdout)):
        at = int(row['at_ns']) / 1000
        if row['kind'] == 'pulse':
            wake = re.search(r'VSYNC-app\(wakeupTime\)\s*=\s*(\d+)', row['detail'])
            if wake:
                groups['pulse'].append((int(wake[1]) / 1000, at))
        elif row['kind'] == 'request':
            groups['request'].append((at, int(row['detail']) / 1000))
        else:
            groups['callback'].append(at)
    return groups


def analyze(report, native):
    if report['droppedEvents']:
        raise ValueError('Frame request stream is incomplete')
    events = defaultdict(list)
    for event in report['events']:
        events[event[1]].append(event)
    if not events['frameBegin']:
        raise ValueError('Capture requires the frame request probe')
    period = 1e6 / report['before']['refreshHz']
    start, end = report['startedUs'], report['stoppedUs']
    frames = sorted(f for f in report['frames'] if start <= f[0] <= end)
    intervals = animation_intervals(report)
    long_count = 0
    active_gaps, details = [], []
    for earlier, later in zip(frames, frames[1:]):
        a, b = earlier[0], later[0]
        gap = b - a
        long_gap = gap > 1.5 * period
        long_count += long_gap
        if not any(lo <= a < b <= later[1] <= hi for lo, hi in intervals):
            continue
        active_gaps.append(gap / 1000)
        if not long_gap:
            continue

        # This OEM encodes the same MONOTONIC wakeup time Flutter records as
        # vsyncStart. The 100 us join allowance is well below one refresh.
        pulses = [(nominal, at) for nominal, at in native.get('pulse', [])
                  if a - 100 <= nominal <= b + 100]
        matched = (len(pulses) >= 3 and abs(pulses[0][0] - a) <= 100
                   and abs(pulses[-1][0] - b) <= 100)
        item = {
            'fromCaptureMs': round((a - start) / 1000, 3),
            'gapMs': gap / 1000,
            'previousUiMs': (earlier[2] - earlier[1]) / 1000,
            'previousRasterMs': (earlier[4] - earlier[3]) / 1000,
            'previousVsyncToBuildMs': (earlier[1] - a) / 1000,
            'nextVsyncToBuildMs': (later[1] - b) / 1000,
            'missedAppPulses': len(pulses) - 2 if matched else None,
            'observedLateNativeRequest': False,
        }
        details.append(item)
        if not matched:
            continue
        missed_dispatch = pulses[1][1]

        def relative_ms(at):
            return round((at - missed_dispatch) / 1000, 4)

        callbacks = [at for at in native.get('callback', [])
                     if a - 100 <= at <= later[1]]
        requests = [e[0] for e in events['frameRequest']
                    if earlier[1] <= e[0] < later[1]]
        draw_ends = [e for e in events['frameEnd']
                     if earlier[2] <= e[0] < later[1]]
        binder = [(at, wake) for at, wake in native.get('request', [])
                  if earlier[1] <= at < later[1]]
        item.update({
            'appCallbacksFromMissedDispatchMs': list(map(relative_ms, callbacks)),
            'dartRequestsFromMissedDispatchMs': list(map(relative_ms, requests)),
            'drawEndsFromMissedDispatchMs': [relative_ms(e[0]) for e in draw_ends],
            'surfaceFlingerRequestsFromMissedDispatchMs': [
                relative_ms(at) for at, _ in binder],
            'binderWakesFromMissedDispatchMs': [relative_ms(wake) for _, wake in binder],
            'precacheReplacementsBeforeNextCallback': sum(
                earlier[1] <= e[0] < later[1] for e in events['cacheReplace']),
        })
        # Require a single accepted Dart request and attributed native request.
        # Two endpoint callbacks leave no intervening native callback in which
        # the engine could have received the pulse but skipped Dart build.
        item['observedLateNativeRequest'] = (
            len(callbacks) == 2
            and callbacks[0] <= earlier[1] < missed_dispatch < callbacks[1]
            and callbacks[1] >= b - 100
            and len(draw_ends) == 1 and draw_ends[0][2]
            and len(requests) == len(binder) == 1
            and requests[0] < missed_dispatch < binder[0][0] < callbacks[1]
        )
    return {
        'name': report['name'],
        'refreshHzAtStart': report['before']['refreshHz'],
        'producedFrames': len(frames),
        'allGapsAboveOneAndHalfPeriods': long_count,
        'sameCommandAnimationVsyncGapMs': distribution(active_gaps),
        'sameAnimationLongGaps': details,
        'observedLateNativeRequests': sum(row['observedLateNativeRequest'] for row in details),
        'stationaryCallbacksWithoutTransientTicker': sum(
            e[5] is False and e[3] == 0 for e in events['frameBegin']
        ),
    }


def stationary_requests(report, diagnostic):
    offset, alignment = diagnostic_clock(report, diagnostic)
    threshold_us = 250
    if alignment['maxDeviationUs'] > threshold_us:
        raise ValueError('Image markers are too imprecise for request pairing')
    decode_ends = sorted(e['atUs'] + e['waitUs'] + offset
                         for e in diagnostic['imageEvents']
                         if e['stage'] == 'precacheWait' and e.get('success', True))
    idle_near_decode = post_frame = 0
    request = None
    for event in report['events']:
        if event[1] == 'frameRequest':
            request = event
        elif event[1] == 'frameBegin':
            if request and event[5] is False and event[3] == 0:
                at, _, _, phase = request
                index = bisect_right(decode_ends, at) - 1
                idle_near_decode += (phase == 0 and index >= 0
                                     and at - decode_ends[index] <= threshold_us)
                post_frame += phase == 4
            request = None
    return {
        'idleRequestWithin250UsAfterPrecache': idle_near_decode,
        'postFrameRequest': post_frame,
        'clockAlignment': alignment,
        'meaning': 'Stationary callback with no transient ticker. Nearby completion '
                   'is a time association; exact request owners need call stacks.',
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('captures', type=Path, nargs='+')
    parser.add_argument('--processor', required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    runs = []
    for folder in args.captures:
        report = json.loads((folder / 'capture.json').read_text(encoding='utf-8'))
        procedure = json.loads((folder / 'procedure.json').read_text(encoding='utf-8'))
        trace = folder / 'trace.pftrace'
        native = trace_events(args.processor, trace, procedure['package'])
        run = analyze(report, native)
        diagnostic = folder / 'production-diagnostics.json'
        if diagnostic.exists():
            data = json.loads(diagnostic.read_text(encoding='utf-8'))
            if any(e['stage'] == 'navigation' for e in data['imageEvents']):
                run['stationaryRequests'] = stationary_requests(report, data)
        with trace.open('rb') as stream:
            run['traceSha256'] = hashlib.file_digest(stream, 'sha256').hexdigest()
        runs.append(run)
    args.out.write_text(json.dumps({
        'method': 'Same command animation only. FrameTiming and OEM wake times are joined '
                  'on CLOCK_MONOTONIC; binder attribution uses the immediate reader-main '
                  'sched_waking event. Unmatched cases remain unknown. No screen FPS inference.',
        'runs': runs,
    }, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
