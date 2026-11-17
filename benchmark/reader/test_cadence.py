import unittest

from analyze_cadence import analyze, animation_intervals


class CadenceValidity(unittest.TestCase):
    def test_static_dwell_does_not_become_animation_gap(self):
        report = {
            'name': 'two_commands', 'startedUs': 0, 'stoppedUs': 100000,
            'before': {'refreshHz': 120},
            'events': [[0, 'animate'], [25000, 'jump'], [75000, 'animate'],
                       [100000, 'animationEnd', 2, 2]],
            'frames': [[at, at + 50, at + 100, at + 110, at + 200]
                       for at in [0, 8333, 16666, 75000, 83333, 91666]],
        }
        result = analyze(report)
        self.assertEqual(result['sameAnimationProducedVsyncGapMs']['max'], 8.333)
        self.assertEqual(result['sameAnimationProducedVsyncGapMs']['n'], 4)
        self.assertGreater(result['allProducedVsyncGapMs']['max'], 50)
        self.assertEqual(result['sameAnimationGapsAboveOneAndHalfRefreshPeriods'], 0)

    def test_stale_completion_cannot_hide_new_animation_gap(self):
        report = {
            'stoppedUs': 50000,
            'events': [[0, 'animate'], [10000, 'jump'], [20000, 'animate'],
                       [30000, 'animationEnd', 1, 2], [45000, 'animationEnd', 2, 2]],
        }
        self.assertEqual(animation_intervals(report), [(0, 10000), (20000, 45000)])


if __name__ == '__main__':
    unittest.main()
