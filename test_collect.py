import unittest
from unittest.mock import patch

from collect import Collector, cpu_percent, cpu_ticks, memory_info, network_rates, storage_info


class TelemetryTests(unittest.TestCase):
    def test_cpu_excludes_double_counted_guest(self):
        self.assertEqual(cpu_ticks("cpu 100 10 20 200 5 2 3 0 50 5\n"), (340, 205))

    def test_cpu_delta_and_warmup(self):
        self.assertIsNone(cpu_percent(None, (100, 50)))
        self.assertIsNone(cpu_percent((100, 50), (100, 50)))
        self.assertEqual(cpu_percent((100, 50), (200, 75)), 75)

    def test_memory_uses_available_not_free(self):
        data = memory_info("MemTotal: 1000 kB\nMemFree: 100 kB\nMemAvailable: 400 kB\nSwapTotal: 200 kB\nSwapFree: 150 kB")
        self.assertEqual(data["percent"], 60)
        self.assertEqual(data["used"], 600 * 1024)
        self.assertEqual(data["swapUsed"], 50 * 1024)

    def test_network_elapsed_and_new_interface(self):
        result = network_rates({"eth0": (100, 200)}, {"eth0": (500, 400), "wlan0": (9999, 9999)}, 2)
        self.assertEqual((result["download"], result["upload"]), (200, 100))

    def test_network_counter_reset(self):
        result = network_rates({"eth0": (1000, 2000)}, {"eth0": (0, 0)}, 2)
        self.assertEqual((result["download"], result["upload"]), (0, 0))

    def test_btrfs_subvolumes_not_duplicated(self):
        mountinfo = "1 0 259:2 /@ / rw - btrfs /dev/nvme0n1p2 rw\n2 0 259:2 /@home /home rw - btrfs /dev/nvme0n1p2 rw"
        with patch("collect.read", return_value=mountinfo):
            rows = storage_info()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["mount"], "/")

    def test_real_snapshot(self):
        state = Collector().snapshot()
        self.assertGreater(state["memory"]["total"], 0)
        self.assertIn("gpus", state)
        self.assertIn("fans", state)
        self.assertIn("temperatures", state)


if __name__ == "__main__":
    unittest.main()
