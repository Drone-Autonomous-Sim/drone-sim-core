#!/usr/bin/env bash
# fly_x3.sh - fly the X3 drone through the README's Step 6 pattern:
# arm, climb, hover, forward, turn, land, disarm.
#
# Where: Terminal B (inside Docker), with the multicopter world open in Terminal A.
#   bash /workspace/sim/scripts/fly_x3.sh
#
# Every command here is one you have already typed by hand. A script is just
# those commands saved in order so the whole flight is one command.

set -e   # stop at the first command that fails instead of carrying on blindly

# Send one velocity command to X3.
# $1 = forward speed (m/s), $2 = up speed (m/s), $3 = turn rate (rad/s, + is left)
move() {
    gz topic -t /X3/gazebo/command/twist -m gz.msgs.Twist \
        -p "linear: {x: $1, y: 0, z: $2}, angular: {z: $3}"
}

echo "arm"
gz topic -t /X3/enable -m gz.msgs.Boolean -p 'data: true'

echo "climb for 5 s"
move 0 0.3 0
sleep 5
move 0 0 0        # zero velocity = hover
sleep 2

echo "forward for 3 s"
move 0.3 0 0
sleep 3
move 0 0 0
sleep 2

echo "turn left for 3 s"
move 0 0 0.3
sleep 3
move 0 0 0
sleep 2

echo "descend to the ground"
move 0 -0.2 0     # climbed ~1.5 m, so ~8 s at 0.2 m/s; 12 s leaves margin
sleep 12
move 0 0 0

echo "disarm (motors off, only safe on the ground)"
gz topic -t /X3/enable -m gz.msgs.Boolean -p 'data: false'
