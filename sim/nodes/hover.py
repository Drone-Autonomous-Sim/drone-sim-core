#!/usr/bin/env python3
"""hover.py - the smallest useful ROS 2 program: arm X3, climb for 5 s, hover.

Where: Terminal C (inside Docker), with the world open in Terminal A and the
bridge from Step 10 running in Terminal B:
    python3 /workspace/sim/nodes/hover.py

A ROS 2 program is called a node. Every node has the skeleton you see here:
create the node, create publishers, run a timer, keep spinning so the timer
fires. Later nodes only add subscribers and more logic inside tick().

The official tutorial this follows:
https://docs.ros.org/en/jazzy/Tutorials/Beginner-Client-Libraries/Writing-A-Simple-Py-Publisher-And-Subscriber.html
"""
import rclpy
from rclpy.node import Node
from std_msgs.msg import Bool
from geometry_msgs.msg import Twist


class Hover(Node):
    def __init__(self):
        super().__init__("hover")                      # this node's name in ROS
        self.enable_pub = self.create_publisher(Bool, "/x3/enable", 10)
        self.cmd_pub = self.create_publisher(Twist, "/x3/cmd_vel", 10)
        self.ticks = 0
        self.finished = False
        self.create_timer(0.1, self.tick)              # call tick() 10 times a second

    def tick(self):
        cmd = Twist()                                  # every field starts at 0
        if self.ticks < 50:                            # first 5 s: arm and climb
            # Arm on every tick, not just once: a node's first message can go
            # out before the bridge has noticed the new publisher.
            self.enable_pub.publish(Bool(data=True))
            cmd.linear.z = 0.3
        self.cmd_pub.publish(cmd)                      # after 5 s: zeros = hover
        self.ticks += 1
        if self.ticks == 60:
            self.get_logger().info("hovering; land with the Step 10 commands")
            self.finished = True


def main():
    rclpy.init()
    node = Hover()
    while rclpy.ok() and not node.finished:
        rclpy.spin_once(node, timeout_sec=0.1)         # let the timer fire
    rclpy.shutdown()


if __name__ == "__main__":
    main()
