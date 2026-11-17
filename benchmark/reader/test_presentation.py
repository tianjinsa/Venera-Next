import unittest

from analyze_presentation import analyze, PENDING_FENCE
from surface_capture import find_layer, parse_latency


class PresentationTest(unittest.TestCase):
    def test_selects_only_the_exact_benchmark_blast_layer(self):
        text = '\n'.join(['RequestedLayerState{SurfaceView[other/Activity](BLAST)#1 parentId=2}',
                          'RequestedLayerState{SurfaceView[example.readerbenchmark/Activity](BLAST)#3 parentId=4}',
                          'RequestedLayerState{Background for SurfaceView[example.readerbenchmark/Activity]#5 parentId=6}'])
        self.assertEqual(find_layer(text, 'example.readerbenchmark'), 'SurfaceView[example.readerbenchmark/Activity](BLAST)#3')
        with self.assertRaises(ValueError):
            find_layer(text + '\n' + text, 'example.readerbenchmark')

    def test_requires_three_integer_columns_and_refresh_period(self):
        self.assertEqual(parse_latency('8333333\n1\t2\t3\n')['rows'], [[1, 2, 3]])
        for bad in ['error', '8333333\n1 2', '8333333\na b c']:
            with self.assertRaises(ValueError):
                parse_latency(bad)

    def test_deduplicates_overlap_and_filters_pending_old_and_future_fences(self):
        report = {'startedUs': 10000, 'stoppedUs': 50000,
                  'calibration': [{'dartBeginUs': 0, 'dartEndUs': 0, 'monoNs': 0}]}
        sample = {'periodNs': 8333333, 'hostStartedNs': 0, 'queryDurationMs': 1,
                  'rows': [[1, 2, 3], [10000000, 18000000, 11000000],
                           [20000000, 26000000, 22000000], [40000000, PENDING_FENCE, 41000000],
                           [50000000, 60000000, 51000000], [0, 0, 0]]}
        latency = {'samples': [sample, dict(sample, hostStartedNs=500000000)], 'errors': [], 'limits': 'Includes idle; not dropped frames'}
        result = analyze(report, latency)
        self.assertEqual(result['presentedSurfaceBuffers'], 2)
        self.assertEqual(result['actualPresentGapMs']['p50'], 8)
        self.assertEqual(result['actualMinusDesiredMs']['p50'], 7)
        self.assertIsNone(result['actualDroppedFrameCount'])


if __name__ == '__main__':
    unittest.main()
