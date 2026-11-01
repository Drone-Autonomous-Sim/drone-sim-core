#!/usr/bin/env python3
"""Run the real Gazebo physics backend in an isolated transport partition."""
import math
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
os.environ['GZ_PARTITION'] = 'drone_test_' + uuid.uuid4().hex
sys.path.insert(0, str(ROOT / 'scripts'))
from drone_control import Drone, demo, reach  # noqa: E402


def main():
    with tempfile.TemporaryFile(mode='w+') as log:
        server = subprocess.Popen([str(ROOT / 'run_sim.sh'), '-s'],
                                  stdout=log, stderr=log, start_new_session=True)
        try:
            drone = Drone()
            drone.wait()
            # Regression: a second server used to interleave poses and make the drone jump.
            duplicate = subprocess.run([str(ROOT / 'run_sim.sh'), '-s'],
                                       capture_output=True, text=True, timeout=5)
            assert duplicate.returncode == 73, duplicate.stderr
            assert 'already running' in duplicate.stderr, duplicate.stderr
            publishers, _ = drone.node.topic_info('/drone/odometry')
            assert len(publishers) == 1, f'Expected one odometry publisher, got {len(publishers)}'
            print('PASS: duplicate simulator rejected; exactly one position publisher.', flush=True)
            demo(drone)
            time.sleep(1)
            x, y, z, yaw = drone.pose()
            assert z < .17 and math.hypot(x, y) < .2, drone.pose()
            # Check yaw and lateral thrust too; the demo exercises forward motion.
            drone.armed(True)
            reach(drone, (0, 0, 1.5))
            yaw_start, start = drone.pose()[3], time.monotonic()
            while time.monotonic() - start < 2:
                drone.hold(1.5, yaw=.5)
                time.sleep(.05)
            yaw_end = drone.pose()[3]
            delta = math.atan2(math.sin(yaw_end-yaw_start), math.cos(yaw_end-yaw_start))
            assert delta > .3, f'Yaw did not respond: {delta}'
            # Verify actual displacement at the new default speed, not only XML limits.
            start = time.monotonic()
            sample = None
            while time.monotonic() - start < 4:
                drone.hold(1.5, x=2.0)
                if sample is None and time.monotonic() - start > 2.5:
                    sample = (time.monotonic(), drone.pose())
                time.sleep(.05)
            elapsed = time.monotonic() - sample[0]
            end = drone.pose()
            speed = math.hypot(end[0]-sample[1][0], end[1]-sample[1][1]) / elapsed
            assert 1.6 < speed < 2.4, f'Unexpected horizontal speed: {speed:.2f} m/s'
            assert abs(end[2] - 1.5) < .2, f'Altitude lost at speed: {end}'
            print(f'PASS: measured horizontal speed {speed:.2f} m/s with altitude hold.')
            reach(drone, (0, 1, 1.5))
            drone.land()
            time.sleep(1)
            assert drone.pose()[2] < .17, drone.pose()
            print('PASS: grounded start, takeoff, hover, forward, return, yaw, lateral, landed stop.')
        finally:
            if server.poll() is None:
                os.killpg(server.pid, signal.SIGINT)
                try:
                    server.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    os.killpg(server.pid, signal.SIGKILL)
                    server.wait()
            log.seek(0)
            if sys.exc_info()[0]:
                print(log.read()[-6000:], file=sys.stderr)


if __name__ == '__main__':
    main()
