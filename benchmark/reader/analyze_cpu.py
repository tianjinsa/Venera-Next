"""Summarize sampled CPU stacks inside the numeric probe's exact time window."""
import argparse
from collections import Counter
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    args = parser.parse_args()
    report = json.loads((args.capture / 'capture.json').read_text(encoding='utf-8'))
    vm = args.capture.with_name(args.capture.name + '-vm')
    cpu = json.loads((vm / 'cpu.json').read_text(encoding='utf-8'))
    inclusive, exclusive = Counter(), Counter()
    samples = [sample for sample in cpu['samples'] if report['startedUs'] <= sample['timestamp'] <= report['stoppedUs']]
    for sample in samples:
        # VM Service documents stack[0] as the current (leaf) function.
        inclusive.update(set(sample['stack']))
        exclusive.update(sample['stack'][:1])
    def function(index):
        value = cpu['functions'][index]
        item = value.get('function', {})
        owner = item.get('owner', {}).get('name', '')
        return {'name': owner + '.' + item.get('name', value.get('name', 'unknown')), 'url': value.get('resolvedUrl'), 'inclusiveSamples': inclusive[index], 'exclusiveSamples': exclusive[index]}
    result = {
        'roiSamples': len(samples), 'samplePeriodUs': cpu['samplePeriod'],
        'vmTags': dict(Counter(sample.get('vmTag') for sample in samples)),
        'topInclusive': [function(index) for index, count in inclusive.most_common(40)],
        'topExclusive': [function(index) for index, count in exclusive.most_common(40)],
        'applicationFunctions': [function(index) for index, count in inclusive.most_common() if '/code/' in (cpu['functions'][index].get('resolvedUrl') or '')][:40],
        'meaning': 'CPU samples only; inclusive stacks overlap and are not summed as independent durations',
    }
    (vm / 'cpu-summary.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print('Saved ROI CPU summary:', vm / 'cpu-summary.json')


if __name__ == '__main__':
    main()
