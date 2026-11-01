#!/usr/bin/env python3
"""Keyboard control and a repeatable flight demo for the Gazebo-only MVP."""
import argparse
import math
import select
import sys
import termios
import threading
import time
import tty

from gz.msgs10.boolean_pb2 import Boolean
from gz.msgs10.odometry_pb2 import Odometry
from gz.msgs10.twist_pb2 import Twist
from gz.transport13 import Node


def clamp(value, limit):
    return max(-limit, min(limit, value))


class Drone:
    def __init__(self):
        self.node = Node()
        self.velocity = self.node.advertise('/drone/cmd_vel', Twist)
        self.enable = self.node.advertise('/drone/enable', Boolean)
        self.lock = threading.Lock()
        self.state = None
        self.received = 0
        self.node.subscribe(Odometry, '/drone/odometry', self.on_odometry)

    def on_odometry(self, msg):
        p, q = msg.pose.position, msg.pose.orientation
        yaw = math.atan2(2 * (q.w*q.z + q.x*q.y), 1 - 2*(q.y*q.y + q.z*q.z))
        with self.lock:
            self.state = (p.x, p.y, p.z, yaw)
            self.received = time.monotonic()

    def pose(self):
        with self.lock:
            if self.state is None or time.monotonic() - self.received > 3:
                raise RuntimeError('No fresh odometry. Start ./run_sim.sh and unpause Gazebo.')
            return self.state

    def wait(self):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            try:
                self.pose()
                # Allow transport discovery before sending the enable message.
                if self.velocity.has_connections() and self.enable.has_connections():
                    return
            except RuntimeError:
                pass
            time.sleep(.1)
        raise RuntimeError('Drone not found. Start ./run_sim.sh first (same GZ_PARTITION).')

    def armed(self, active):
        self.enable.publish(Boolean(data=active))

    def command(self, x=0., y=0., z=0., yaw=0.):
        msg = Twist()
        msg.linear.x, msg.linear.y, msg.linear.z = x, y, z
        msg.angular.z = yaw
        self.velocity.publish(msg)

    def hold(self, height, x=0., y=0., yaw=0.):
        z = self.pose()[2]
        self.command(x, y, clamp(1.5 * (height-z), .6), yaw)

    def land(self):
        print('\nLanding...', flush=True)
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            z = self.pose()[2]
            if z < .17:
                self.command()
                self.armed(False)
                print('Landed; motors disabled.', flush=True)
                return
            self.command(z=-min(.4, max(.12, z*.6)))
            time.sleep(.05)
        raise RuntimeError('Landing timed out; inspect Gazebo before continuing.')


def reach(drone, target, timeout=35):
    """Reach an absolute world position using body-frame velocity commands."""
    deadline = time.monotonic() + timeout
    settled = None
    while time.monotonic() < deadline:
        x, y, z, yaw = drone.pose()
        dx, dy, dz = target[0]-x, target[1]-y, target[2]-z
        bx = math.cos(yaw)*dx + math.sin(yaw)*dy
        by = -math.sin(yaw)*dx + math.cos(yaw)*dy
        drone.hold(target[2], clamp(bx, .5), clamp(by, .5))
        if math.sqrt(dx*dx + dy*dy + dz*dz) < .15:
            settled = settled or time.monotonic()
            if time.monotonic() - settled > 1:
                return
        else:
            settled = None
        time.sleep(.05)
    raise RuntimeError(f'Failed to reach {target}; last pose: {drone.pose()}')


def demo(drone):
    x, y, z, _ = drone.pose()
    if z > .25:
        raise RuntimeError('Demo requires a landed drone. Land first or restart the simulator.')
    drone.armed(True)
    for label, target in [
        ('Take off and hover at 1.5 m', (x, y, 1.5)),
        ('Fly one metre forward', (x+1, y, 1.5)),
        ('Return above the landing point', (x, y, 1.5)),
    ]:
        print(label, flush=True)
        reach(drone, target)
        print('Reached:', tuple(round(v, 3) for v in drone.pose()[:3]), flush=True)
    drone.land()
    print('DEMO PASS: takeoff, hover, translation, return, landing.', flush=True)


def keyboard(drone):
    if not sys.stdin.isatty():
        raise RuntimeError('Keyboard mode needs an interactive terminal. Use --demo for automation.')
    print('T takeoff | W/S forward/back | A/D left/right | Q/E yaw\n'
          'R/F raise/lower height | SPACE hover | L land | X quit (lands first)\n'
          'Hold movement keys to move. Released keys expire after 0.35 s.\n'
          'Orange nose points forward. Click THIS terminal to control the drone.', flush=True)
    settings = termios.tcgetattr(sys.stdin)
    height, flying = drone.pose()[2], False
    movement, expires, status_at = (0., 0., 0.), 0., 0.
    try:
        tty.setcbreak(sys.stdin.fileno())
        while True:
            if select.select([sys.stdin], [], [], .05)[0]:
                key = sys.stdin.read(1).lower()
                if key in ('x', '\x03'):
                    break
                if key == 't':
                    drone.armed(True)
                    height, flying = 1.5, True
                elif key == 'l':
                    if flying:
                        drone.land()
                    flying, movement = False, (0., 0., 0.)
                elif key == ' ':
                    movement = (0., 0., 0.)
                elif key in ('r', 'f') and flying:
                    height = max(.4, min(4., height + (.2 if key == 'r' else -.2)))
                elif key in 'wasdqe' and flying:
                    movement = {'w': (.6, 0., 0.), 's': (-.6, 0., 0.),
                                'a': (0., .6, 0.), 'd': (0., -.6, 0.),
                                'q': (0., 0., .6), 'e': (0., 0., -.6)}[key]
                    expires = time.monotonic() + .35
            if time.monotonic() > expires:
                movement = (0., 0., 0.)
            if flying:
                drone.hold(height, *movement)
            else:
                drone.pose()  # Detect a stopped or disconnected simulator.
            if time.monotonic() > status_at:
                x, y, z, _ = drone.pose()
                print(f'\rPosition ({x:+.2f}, {y:+.2f}, {z:.2f}) m | target {height:.1f} m    ', end='', flush=True)
                status_at = time.monotonic() + .5
    finally:
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, settings)
        if flying:
            drone.land()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--demo', action='store_true', help='Run the takeoff / move / return / land demo')
    args = parser.parse_args()
    drone = Drone()
    try:
        drone.wait()
        if args.demo:
            try:
                demo(drone)
            except (RuntimeError, KeyboardInterrupt):
                drone.land()
                raise
        else:
            keyboard(drone)
    except (RuntimeError, KeyboardInterrupt) as exc:
        print(f'\nStopped: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
