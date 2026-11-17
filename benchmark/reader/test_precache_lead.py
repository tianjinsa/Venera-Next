import unittest

from analyze_precache_lead import analyze


class LeadTest(unittest.TestCase):
    def test_finished_spans_are_sorted_by_start_and_decode_end_is_used(self):
        data = {
            'durationUs': 200000, 'configuration': {},
            'retainedStageSamples': {}, 'scrollFrameSamples': {'settle': {}},
            'imageEvents': [
                {'stage': 'pageTurn', 'phase': 'requested', 'atUs': 100000},
                {'stage': 'cacheLookup', 'image': 1, 'atUs': 115000, 'pending': True},
                {'stage': 'firstDecodeWait', 'image': 1, 'atUs': 70000,
                 'waitUs': 60000, 'success': True},
                {'stage': 'precacheWait', 'image': 1, 'atUs': 59000, 'waitUs': 71000},
                {'stage': 'displayWait', 'image': 1, 'atUs': 115001, 'waitUs': 15000},
                {'stage': 'cacheLookup', 'image': 1, 'atUs': 130001, 'pending': False},
            ],
        }
        result = analyze(data)
        self.assertEqual(result['precacheLeadBeforeNearestRequestMs']['p50'], 41)
        self.assertEqual(result['decodeLeadBeforeLookupMs']['p50'], -15)
        self.assertEqual(result['pendingFirstDisplayLookups'], 1)

    def test_copy_omission_does_not_invent_a_decode_or_preload(self):
        data = {
            'durationUs': 200000, 'configuration': {}, 'omittedEventsForCopy': 120,
            'retainedStageSamples': {}, 'scrollFrameSamples': {'settle': {}},
            'imageEvents': [
                {'stage': 'cacheLookup', 'image': 2, 'atUs': 100000, 'pending': True},
                {'stage': 'displayWait', 'image': 2, 'atUs': 100001, 'waitUs': 20000},
            ],
        }
        result = analyze(data)
        self.assertEqual(result['firstDisplayLookups'], 1)
        self.assertEqual(result['pendingFirstDisplayLookups'], 1)
        self.assertEqual(result['pairedImages'], 0)
        self.assertEqual(result['omittedEventsForCopy'], 120)


if __name__ == '__main__':
    unittest.main()
