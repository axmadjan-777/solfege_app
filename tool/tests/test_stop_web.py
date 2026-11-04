"""Ensure stopping one checkout cannot terminate another checkout's server."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class StopWebTest(unittest.TestCase):
    def test_only_process_with_matching_working_directory_is_stopped(self):
        with tempfile.TemporaryDirectory(prefix="solfege stop test ") as temp:
            current = Path(temp) / "current copy"
            other = Path(temp) / "other copy"
            current.mkdir()
            other.mkdir()
            shutil.copy2(ROOT / "stop_web.sh", current / "stop_web.sh")
            processes = []
            try:
                for directory in (current, other):
                    process = subprocess.Popen(
                        [sys.executable, "-u", "-c",
                         'import time; print("ready", flush=True); time.sleep(30)',
                         "flutter_tools.snapshot", "run", "-d", "web-server"],
                        cwd=directory, stdout=subprocess.PIPE, text=True,
                    )
                    processes.append(process)
                    self.assertEqual(process.stdout.readline().strip(), "ready")
                result = subprocess.run(
                    ["bash", "stop_web.sh"], cwd=current,
                    capture_output=True, text=True, timeout=10,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(processes[0].wait(timeout=5), -15)
                self.assertIsNone(processes[1].poll())
            finally:
                for process in processes:
                    if process.poll() is None:
                        process.terminate()
                    process.wait(timeout=5)
                    process.stdout.close()


if __name__ == "__main__":
    unittest.main()
