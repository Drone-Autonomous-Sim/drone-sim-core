#!/usr/bin/env python3
"""Check session exclusion, partition isolation, and release after termination."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import unittest
import uuid

GUARD = Path(__file__).resolve().parents[1] / 'scripts/run_exclusive.sh'


class SessionGuardTest(unittest.TestCase):
    def test_exclusion_isolation_and_release(self):
        env = dict(os.environ, GZ_PARTITION='guard_test_' + uuid.uuid4().hex)
        for role in ('simulator', 'controller'):
            with self.subTest(role=role):
                proc = subprocess.Popen(
                    [str(GUARD), role, sys.executable, '-u', '-c',
                     'import time; print("ready"); time.sleep(30)'],
                    env=env, stdout=subprocess.PIPE, text=True, start_new_session=True)
                try:
                    self.assertEqual(proc.stdout.readline().strip(), 'ready')
                    duplicate = subprocess.run([str(GUARD), role, 'true'],
                                               env=env, capture_output=True, text=True, timeout=5)
                    self.assertEqual(duplicate.returncode, 73)
                    self.assertIn('already running', duplicate.stderr)
                    other = dict(env, GZ_PARTITION=env['GZ_PARTITION'] + '_other')
                    subprocess.run([str(GUARD), role, 'true'], env=other, check=True, timeout=5)
                    other_role = 'controller' if role == 'simulator' else 'simulator'
                    subprocess.run([str(GUARD), other_role, 'true'], env=env, check=True, timeout=5)
                finally:
                    os.killpg(proc.pid, signal.SIGTERM)
                    proc.wait(timeout=5)
                    proc.stdout.close()
                subprocess.run([str(GUARD), role, 'true'], env=env, check=True, timeout=5)

    def test_child_exit_status_is_preserved(self):
        env = dict(os.environ, GZ_PARTITION='exit_test_' + uuid.uuid4().hex)
        result = subprocess.run([str(GUARD), 'controller', 'bash', '-c', 'exit 7'],
                                env=env, timeout=5)
        self.assertEqual(result.returncode, 7)


if __name__ == '__main__':
    unittest.main()
