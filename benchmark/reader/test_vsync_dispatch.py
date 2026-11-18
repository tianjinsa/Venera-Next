import unittest

from analyze_vsync_dispatch import analyze


class VsyncDispatchTest(unittest.TestCase):
    def test_requires_evidence_of_missed_dispatch_and_late_native_request(self):
        report = {
            'name': 'animation', 'before': {'refreshHz': 120},
            'startedUs': 0, 'stoppedUs': 70_000, 'droppedEvents': 0,
            'frames': [
                [10_000, 10_500, 13_000, 13_100, 14_000],
                [26_666, 27_000, 31_000, 31_200, 32_000],
                [60_000, 61_000, 62_000, 62_100, 63_000],
            ],
            'events': [
                [9000, 'animate'],
                [10_550, 'frameBegin', 18_333, 1, 1, True],
                [10_600, 'frameRequest', 0, 1], [18_600, 'frameEnd', True, 1],
                [27_100, 'frameBegin', 35_000, 1, 1.1, True],
                [40_000, 'jump'],
                [61_100, 'frameBegin', 68_333, 0, 2, False],
            ],
        }
        native = {
            'pulse': [(10_000, 10_100), (18_333, 18_450), (26_666, 26_770)],
            'callback': [10_200, 26_900],
            'request': [(18_900, 18_800)],
        }
        result = analyze(report, native)
        self.assertEqual(result['allGapsAboveOneAndHalfPeriods'], 2)
        self.assertEqual(result['observedLateNativeRequests'], 1)
        gap, = result['sameAnimationLongGaps']
        self.assertEqual(gap['previousUiMs'], 2.5)
        self.assertEqual(gap['missedAppPulses'], 1)
        self.assertEqual(gap['surfaceFlingerRequestsFromMissedDispatchMs'], [.45])

        # An intermediate native callback could instead have been rejected
        # after delivery. It cannot prove a late request.
        received = dict(native, callback=[10_200, 18_500, 26_900])
        self.assertEqual(analyze(report, received)['observedLateNativeRequests'], 0)

        # An unrelated/missing binder wake must remain unattributed.
        self.assertEqual(analyze(report, dict(native, request=[]))[
            'observedLateNativeRequests'], 0)


if __name__ == '__main__':
    unittest.main()
