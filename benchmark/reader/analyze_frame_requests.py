"""Distinguish accepted requests, frame callbacks and non-scrolling tickers.

Callback arrival time is not VSync time or screen presentation. No-next-frame
at draw end is an observation, not a missed frame: an idle reader needs none.
"""
import argparse
import json
from pathlib import Path

from analyze_cadence import animation_intervals, same_interval_gaps
from summarize import distribution


def analyze(report):
    intervals = animation_intervals(report)
    active = lambda at: any(start <= at <= end for start, end in intervals)
    pending, waits, active_waits, begins, no_next = None, [], [], [], []
    for event in sorted(report['events'], key=lambda e: e[0]):
        at, kind = event[:2]
        if kind == 'frameRequest':
            pending = at
        elif kind == 'frameBegin':
            begins.append(event)
            if pending is not None:
                wait = (at - pending) / 1000
                waits.append(wait)
                if active(at):
                    active_waits.append(wait)
                pending = None
        elif kind == 'frameEnd' and not event[2] and active(at):
            no_next.append(at)
    return {
        'name': report['name'], 'callbacks': len(begins),
        'requestToCallbackMs': distribution(waits),
        'activeRequestToCallbackMs': distribution(active_waits),
        'sameAnimationCallbackArrivalGapMs': distribution(same_interval_gaps(
            [(e[0], e[0]) for e in begins], intervals)),
        'callbacksWhileNotScrolling': sum(not e[5] for e in begins),
        'tickerCallbacksWhileNotScrolling': sum(not e[5] and e[3] > 0 for e in begins),
        'drawsWithoutScheduledNextFrameDuringCommandInterval': len(no_next),
        'limits': 'Accepted Flutter frame requests only; callback arrival includes engine wait '
                  'and Dart scheduling, not screen presentation. Command intervals end at jump '
                  'or matching Future completion; touching ballistic motion is not classified. '
                  'An active ticker while the pager is stationary is not proof of its owner.',
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('captures', type=Path, nargs='+')
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    runs = [analyze(json.loads((folder / 'capture.json').read_text())) for folder in args.captures]
    args.out.write_text(json.dumps({'runs': runs}, indent=2) + '\n', encoding='utf-8')
    for run in runs:
        print(run['name'], run['activeRequestToCallbackMs'],
              'stationary ticker callbacks:', run['tickerCallbacksWhileNotScrolling'])
