import unittest

from analyze_frame_requests import analyze


class FrameRequestsTest(unittest.TestCase):
    def test_request_wait_and_stationary_ticker_are_separate(self):
        report = {
            'name': 'callbacks', 'stoppedUs': 100000,
            'events': [
                [0, 'animate'], [1000, 'frameRequest', 1, 0],
                [8333, 'frameBegin', 8000, 1, 1.1, True],
                [9000, 'frameRequest', 1, 1], [10000, 'frameEnd', True, 1],
                [16666, 'frameBegin', 16000, 1, 1.3, True],
                [17000, 'jump'], [18000, 'frameRequest', 1, 0],
                [25000, 'frameBegin', 24000, 1, 2.0, False],
                [26000, 'frameEnd', False, 0],
            ],
        }
        result = analyze(report)
        self.assertEqual(result['callbacks'], 3)
        self.assertEqual(result['activeRequestToCallbackMs']['n'], 2)
        self.assertEqual(result['sameAnimationCallbackArrivalGapMs']['max'], 8.333)
        self.assertEqual(result['tickerCallbacksWhileNotScrolling'], 1)
        self.assertEqual(result['drawsWithoutScheduledNextFrameDuringCommandInterval'], 0)


if __name__ == '__main__':
    unittest.main()
