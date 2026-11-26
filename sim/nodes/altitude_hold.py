#!/usr/bin/env python3
"""altitude_hold.py - climb to a target height and stay there, using feedback.

Where: Terminal C (inside Docker), world open in Terminal A, bridge from
Step 10 running in Terminal B:
    python3 /workspace/sim/nodes/altitude_hold.py
Ctrl+C stops the node; X3 keeps hovering. Land with the Step 10 commands.

hover.py flew blind: climb for 5 s and hope. This node reads the drone's
position back from /x3/odom and corrects. That read-decide-command loop is
what every controller does, from this one to the real autopilot.

Subscribers: https://docs.ros.org/en/jazzy/Concepts/Basic/About-Topics.html
Proportional control: https://en.wikipedia.org/wiki/Proportional_control
"""
import rclpy
from rclpy.node import Node
from std_msgs.msg import Bool
from geometry_msgs.msg import Twist
from nav_msgs.msg import Odometry

TARGET = 2.0     # metres above the floor. Change it and run again.
GAIN = 0.5       # climb speed per metre of error. Try 3.0 and watch it overshoot.
MAX_SPEED = 0.5  # m/s, so a big error does not become a big jump


class AltitudeHold(Node):
    def __init__(self):
        super().__init__("altitude_hold")
        self.enable_pub = self.create_publisher(Bool, "/x3/enable", 10)
        self.cmd_pub = self.create_publisher(Twist, "/x3/cmd_vel", 10)
        self.create_subscription(Odometry, "/x3/odom", self.on_odom, 10)
        self.height = None                         # unknown until odom arrives
        self.ticks = 0
        self.create_timer(0.1, self.tick)

    def on_odom(self, msg):
        # ROS calls this each time a message arrives on /x3/odom
        self.height = msg.pose.pose.position.z

    def tick(self):
        if self.height is None:
            return                                 # no measurement yet, send nothing
        self.enable_pub.publish(Bool(data=True))
        error = TARGET - self.height               # positive means too low
        speed = GAIN * error                       # proportional: push harder when further away
        speed = max(-MAX_SPEED, min(MAX_SPEED, speed))
        cmd = Twist()
        cmd.linear.z = speed
        self.cmd_pub.publish(cmd)
        self.ticks += 1
        if self.ticks % 10 == 0:                   # once a second
            self.get_logger().info(
                f"height {self.height:.2f} m  target {TARGET:.2f} m  climb {speed:+.2f} m/s")


def main():
    rclpy.init()
    node = AltitudeHold()
    try:
        rclpy.spin(node)                           # run until Ctrl+C
    except KeyboardInterrupt:
        pass
    rclpy.try_shutdown()                           # tidy up (Ctrl+C may have started this already)


if __name__ == "__main__":
    main()
