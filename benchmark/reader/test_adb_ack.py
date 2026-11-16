"""Regression checks for persisted ACKs across reboot and same-name commands."""
import unittest
from unittest.mock import patch

from adb_benchmark import Device


class AcknowledgementTest(unittest.TestCase):
    def test_launch_accepts_new_ack_after_device_clock_restarts(self):
        device = Device('unused-adb', 'next')
        old = {'command': 'ping', 'timelineUs': 9000000}
        fresh = {'command': 'ping', 'timelineUs': 1000}
        with patch.object(device, 'read_json', side_effect=[old, old, fresh]), \
                patch.object(device, 'run', return_value='') as run, \
                patch('adb_benchmark.time.sleep'):
            self.assertEqual(device.launch(), fresh)
        self.assertTrue(any('broadcast' in call.args for call in run.call_args_list))

    def test_second_position_does_not_reuse_first_position_ack(self):
        device = Device('unused-adb', 'next')
        first = {'command': 'position', 'timelineUs': 1000, 'page': 161}
        second = {'command': 'position', 'timelineUs': 2000, 'page': 160}
        with patch.object(device, 'read_json', side_effect=[first, first, second]), \
                patch.object(device, 'run', return_value=''), \
                patch('adb_benchmark.time.sleep'):
            device.command('position', page=160)
            self.assertEqual(device.wait_status('position')['page'], 160)


if __name__ == '__main__':
    unittest.main()
