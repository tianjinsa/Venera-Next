"""Small validity checks for measurement semantics, not app performance tests."""
import copy
import unittest
from summarize import summarize


class MeasurementValidity(unittest.TestCase):
    def setUp(self):
        self.report = {
            'name': 'known_measurement', 'mode': 'release',
            'startedUs': 1000000, 'stoppedUs': 2000000,
            'frames': [
                [1050000, 1053000, 1054000, 1054100, 1056100],
                [1058333, 1061333, 1063333, 1063500, 1066500],
                [1066666, 1069666, 1072666, 1072800, 1076800],
            ],
            'events': [[1100150, 'volume', 2], [1150200, 'volume', 2]],
            'native': {'keys': [[1100000000, 0, 0, 0, 42, 25, 0], [1150000000, 0, 0, 0, 42, 25, 1]], 'cpuTimeMs': 80},
            'calibration': [{'dartBeginUs': 1000000, 'dartEndUs': 1000020, 'monoNs': 1000010000}],
            'droppedEvents': 0, 'before': {}, 'after': {},
        }

    def test_frame_execution_delay_and_presentation_are_separate(self):
        result = summarize(self.report)
        self.assertEqual(result['uiMs']['p50'], 2)
        self.assertEqual(result['rasterMs']['p50'], 3)
        self.assertEqual(result['vsyncToBuildMs']['p50'], 3)
        self.assertEqual(result['producedVsyncGapMs']['p50'], 8.333)
        self.assertIn('Requires SurfaceFlinger', result['actualPresentation'])

    def test_out_of_order_delivery_and_outside_frames_do_not_invent_gaps(self):
        report = copy.deepcopy(self.report)
        report['frames'].reverse()
        report['frames'].append([4000000, 4000001, 4090000, 4090001, 4100000])
        self.assertEqual(summarize(report)['uiMs'], summarize(self.report)['uiMs'])
        self.assertEqual(summarize(report)['producedVsyncGapMs'], summarize(self.report)['producedVsyncGapMs'])

    def test_incomplete_input_pairing_does_not_invent_channel_latency(self):
        result = summarize(self.report)
        self.assertEqual(result['nativeToDartMs']['p50'], .175)
        self.report['events'].pop()
        self.assertEqual(summarize(self.report)['nativeToDartMs'], {'n': 0})

    def test_held_sequence_is_recorded_without_claiming_adb_equivalence(self):
        result = summarize(self.report)
        self.assertEqual(result['nativeRepeatCounts'], [0, 1])
        self.assertEqual(result['nativeDownTimeCount'], 1)
        self.assertEqual(result['nativeKeyIntervalMs']['p50'], 50)
        self.assertEqual(result['cpuMsPerSecond'], 80)

    def test_new_drag_during_settling_is_distinct_from_idle_and_multitouch(self):
        self.report['events'] += [
            [1200000, 'pointerDown', 10.0, False, 0],
            [1300000, 'pointerDown', 10.4, True, 0],
            [1400000, 'pointerDown', 10.6, True, 1],
        ]
        result = summarize(self.report)
        self.assertEqual(result['pointerDowns'], 3)
        self.assertEqual(result['newDragWhileScrolling'], 1)


if __name__ == '__main__':
    unittest.main()
