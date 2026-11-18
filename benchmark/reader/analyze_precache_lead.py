"""Pair retained image events by capture-local ID; never treat waits as CPU.

Image spans are appended on completion, so their array order is not time order.
Missing or copy-truncated events remain missing; no page identity is inferred.
"""
import argparse
import bisect
import hashlib
import json
from pathlib import Path

from summarize import distribution


def analyze(data):
    events = sorted(data['imageEvents'], key=lambda e: e['atUs'])
    requests = [e['atUs'] for e in events
                if e['stage'] == 'pageTurn' and e['phase'] == 'requested']
    groups = {}
    for event in events:
        if 'image' in event:
            groups.setdefault(event['image'], []).append(event)
    pairs, first_lookups = [], []
    for image, rows in groups.items():
        lookup = next((e for e in rows if e['stage'] == 'cacheLookup'), None)
        precache = next((e for e in rows if e['stage'] == 'precacheWait'), None)
        decode = next((e for e in rows if e['stage'] == 'firstDecodeWait'
                       and e.get('success')), None)
        display = next((e for e in rows if e['stage'] == 'displayWait'), None)
        if lookup and display:
            first_lookups.append(lookup)
        if not lookup or not precache or not decode:
            continue
        # First lookup must belong to this retained load, not a later revisit.
        if not precache['atUs'] <= lookup['atUs'] <= precache['atUs'] + precache['waitUs'] + 1000000:
            continue
        request_index = bisect.bisect_right(requests, lookup['atUs']) - 1
        request = requests[request_index] if request_index >= 0 else None
        pairs.append({
            'image': image, 'firstLookupAtUs': lookup['atUs'],
            'pending': lookup['pending'], 'precacheAtUs': precache['atUs'],
            'decodeDoneAtUs': decode['atUs'] + decode['waitUs'],
            'decodeLeadBeforeLookupUs': lookup['atUs'] - decode['atUs'] - decode['waitUs'],
            # Nearest retained request is a temporal association, not a page-ID join.
            'nearestRequestAtUs': request,
            'precacheLeadBeforeNearestRequestUs': None if request is None else request - precache['atUs'],
        })
    return {
        'durationUs': data['durationUs'],
        'configuration': data['configuration'],
        'omittedEventsForCopy': data.get('omittedEventsForCopy', 0),
        'droppedEvents': data.get('droppedEvents', 0),
        'pairedImages': len(pairs), 'pendingFirstLookups': sum(p['pending'] for p in pairs),
        'firstDisplayLookups': len(first_lookups),
        'pendingFirstDisplayLookups': sum(p['pending'] for p in first_lookups),
        'decodedBeforeFirstLookup': sum(p['decodeLeadBeforeLookupUs'] >= 0 for p in pairs),
        'precacheLeadBeforeNearestRequestMs': distribution([
            p['precacheLeadBeforeNearestRequestUs'] / 1000 for p in pairs
            if p['precacheLeadBeforeNearestRequestUs'] is not None]),
        'decodeLeadBeforeLookupMs': distribution([p['decodeLeadBeforeLookupUs'] / 1000 for p in pairs]),
        'displayWait': data['retainedStageSamples'].get('displayWait'),
        'settle': data['scrollFrameSamples']['settle'],
        'pairs': pairs,
        'limits': 'Retained complete image pairs only; nearest request is temporal, not an exact '
                  'page join. Truncated captures cannot establish full-run counts. VSync gaps '
                  'measure produced frames, not screen FPS. Async spans do not measure CPU.',
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('captures', type=Path, nargs='+')
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    rows = []
    for path in args.captures:
        raw = path.read_bytes()
        text = raw.decode('utf-8-sig')
        data = json.loads(text[text.index('{'):text.rindex('}') + 1])
        result = analyze(data)
        result.update(file=path.name, sha256=hashlib.sha256(raw).hexdigest())
        rows.append(result)
        print(path.name, 'pending', result['pendingFirstDisplayLookups'], '/', result['firstDisplayLookups'],
              'precache lead ms', result['precacheLeadBeforeNearestRequestMs'])
    args.out.parent.mkdir(exist_ok=True, parents=True)
    args.out.write_text(json.dumps({'captures': rows}, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
