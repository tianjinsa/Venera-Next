"""Collect sanitized numeric results from an explicit, completed capture list.

Raw traces, device IDs, filesystem paths and application payloads stay local.
CPU placement/present-fence analyzers may be run first; missing data stays absent.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

from analyze_viewport import analyze as viewport_alignment
from analyze_frame_requests import analyze as frame_requests
from summarize import distribution, summarize


def collect(folder):
    report = json.loads((folder / 'capture.json').read_text())
    result = summarize(report)
    result['cacheExecutionPhaseCounts'] = dict(Counter(e[4] for e in report['events']
                                                     if e[1] == 'cache' and len(e) > 4))
    selected = [e for e in report['events'] if e[1] == 'selectionImageStatus']
    display = [e for e in report['events'] if e[1] == 'displayResolveStatus']
    if selected or display:
        first_display = {}
        for event in display:
            first_display.setdefault(event[2], event)
        result['imageReadinessProxies'] = {
            'acceptedSelectionsObserved': len(selected),
            'selectionsWithAllImagesReady': sum(e[4] == e[3] for e in selected),
            'selectionsWithPendingImages': sum(e[5] > 0 for e in selected),
            'displayResolves': len(display),
            'displayResolvesReady': sum(e[3] or (e[4] and not e[5]) for e in display),
            'displayResolvesPending': sum(e[5] for e in display),
            'firstDisplayLookups': len(first_display),
            'firstDisplayReady': sum(e[3] or (e[4] and not e[5]) for e in first_display.values()),
            'firstDisplayPending': sum(e[5] for e in first_display.values()),
            'meaning': 'Lookup-only decoded/live cache status, not proof of screen content or blank-frame count',
        }
    diagnostics = folder / 'production-diagnostics.json'
    if diagnostics.exists():
        data = json.loads(diagnostics.read_text())
        result['productionDiagnostics'] = {
            key: data[key] for key in ['limits', 'droppedEvents', 'omittedEventsForCopy',
                                      'droppedFrames', 'retainedStageSamples']
        }
        result['productionDiagnostics']['scrollFrameSamples'] = {
            key: data['scrollFrameSamples'][key]
            for key in ['drag', 'settle', 'droppedPhases']
        }
    if any(e[1] == 'frameBegin' for e in report['events']):
        result['frameRequests'] = frame_requests(report)
    cap = folder / 'test-cache-cap-status.json'
    if cap.exists():
        initial = json.loads((folder / 'initial-status.json').read_text())
        result['automaticCacheLimitBytesBeforeTestCap'] = initial['cacheLimitBytes']
        result['testCacheLimitBytes'] = json.loads(cap.read_text())['cacheLimitBytes']
    procedure = json.loads((folder / 'procedure.json').read_text())
    result['procedure'] = {
        k: Path(v).name if isinstance(v, str) and k in ('key_timing', 'key_dex', 'touch_dex') else v
        for k, v in procedure.items() if k not in ('adb', 'serial', 'out')
    }
    repeats = result.pop('nativeRepeatCounts')
    result['repeatCountRange'] = [min(repeats), max(repeats)] if repeats else None
    for filename, key in [('presentation-summary.json', 'presentation'),
                          ('input-validation.json', 'nativeInputValidation'),
                          ('touch-validation.json', 'touchValidation'),
                          ('frame-states-summary.json', 'frameThreadStates')]:
        path = folder / filename
        if path.exists():
            result[key] = json.loads(path.read_text())
    placement = folder / 'cpu-schedule.json'
    if placement.exists():
        result['cpuPlacement'] = json.loads(placement.read_text())['rows']
    result['dumpsysMemoryKb'], result['batteryTemperatureTenthsC'] = {}, {}
    for phase in ['before', 'after']:
        memory = (folder / (phase + '-meminfo.txt')).read_text()
        result['dumpsysMemoryKb'][phase] = {
            label: int(found[1]) for label in ['PSS', 'RSS']
            if (found := re.search(r'TOTAL ' + label + r':\s*(\d+)', memory))
        }
        battery = (folder / (phase + '-battery.txt')).read_text()
        match = re.search(r'temperature:\s*(\d+)', battery)
        result['batteryTemperatureTenthsC'][phase] = int(match[1]) if match else None
    input_path = folder / 'input-events.json'
    injected = json.loads(input_path.read_text()) if input_path.exists() else None
    if injected and 'durationMs' in injected:
        downs = [e for e in injected['events'] if e[4] == 0]
        result['touchInput'] = {
            'durationMs': injected['durationMs'], 'afterUpGapMs': injected['gapMs'],
            'plannedDownCadenceMs': injected['durationMs'] + injected['gapMs'],
            'actualDownCadenceMs': distribution([(b[1] - a[1]) / 1e6 for a, b in zip(downs, downs[1:])]),
            'injectionLatenessMs': distribution([(e[1] - e[0]) / 1e6 for e in injected['events']]),
        }
    if injected or report['native']['keys']:
        result['viewportAlignment'] = viewport_alignment(report, injected)
    surface = folder / 'surface-latency.json'
    if surface.exists():
        result['processCooldownSeconds'] = json.loads(surface.read_text()).get('freshProcessCooldownSeconds', 0)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('captures', type=Path, nargs='*')
    parser.add_argument('--series', type=Path)
    parser.add_argument('--product-sha', required=True)
    parser.add_argument('--prime-sha')
    parser.add_argument('--candidate-patch', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--limits', required=True)
    args = parser.parse_args()
    series = json.loads(args.series.read_text()) if args.series else None
    folders = args.captures
    if series:
        if folders:
            parser.error('Choose explicit captures or one series manifest')
        completed = series['completed']
        folders = [args.series.parent / (r['name'] if isinstance(r, dict) else r) for r in completed]
    if not folders:
        parser.error('Requires completed captures')
    result = {'productSha': args.product_sha, 'primeSha': args.prime_sha,
              'limits': args.limits, 'runs': [collect(folder) for folder in folders]}
    if series:
        result['series'] = series
    if args.candidate_patch:
        result['candidatePatch'] = {'file': args.candidate_patch.name,
                                    'sha256': hashlib.sha256(args.candidate_patch.read_bytes()).hexdigest()}
    args.out.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print('Collected', len(folders), 'completed captures into', args.out.name)


if __name__ == '__main__':
    main()
