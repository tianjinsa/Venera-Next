import unittest

from analyze_viewport import analyze


class ControllerAlignmentTest(unittest.TestCase):
    def test_alignment_time_and_produced_frames_have_distinct_denominators(self):
        report = {
            'startedUs': 0, 'stoppedUs': 1000000, 'before': {'page': 1},
            'calibration': [{'dartBeginUs': 0, 'dartEndUs': 0, 'monoNs': 0}],
            'events': [[200000, 'position', 1.2], [300000, 'position', 2],
                       [600000, 'position', 2.4], [800000, 'position', 3]],
            'frames': [[0, 0, timestamp] for timestamp in [100000, 250000, 450000, 700000, 900000]],
        }
        injected = {'events': [[0, 0], [1000000000, 1000000000]]}
        result = analyze(report, injected)
        self.assertEqual(result['controllerAlignedTimePct'], 70)
        self.assertEqual(result['framesWithAlignedControllerPct'], 60)
        self.assertEqual(result['observedAlignedSegmentsMs']['n'], 3)

    def test_native_down_span_does_not_claim_a_release_timestamp(self):
        report = {
            'startedUs': 0, 'stoppedUs': 1000000, 'before': {'page': 1},
            'calibration': [{'dartBeginUs': 0, 'dartEndUs': 0, 'monoNs': 0}],
            'events': [], 'frames': [],
            'native': {'keys': [[100000000], [900000000]]},
        }
        result = analyze(report)
        self.assertEqual(result['windowMs'], 800)
        self.assertIn('UP not recorded', result['window'])
        self.assertIsNone(result['framesWithAlignedControllerPct'])


if __name__ == '__main__':
    unittest.main()
