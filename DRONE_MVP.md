# Drone flight MVP (Ubuntu 24.04 / ROS 2 Jazzy / Gazebo Harmonic)

A local quadcopter with four motor thrust models, gravity, collision geometry,
velocity stabilization, odometry, and a small practice field. No external model
downloads, build step, CUDA, PX4, or Docker are required for this native path.

This is a simplified simulation for learning and prototyping. It does not yet
include a camera, LiDAR, SLAM, battery model, PX4 flight stack, or real hardware
integration. It uses ground-truth odometry for altitude feedback.

## Prerequisites

Install ROS 2 Jazzy using the [official Ubuntu instructions](https://docs.ros.org/en/jazzy/Installation/Ubuntu-Install-Debs.html), then:

```bash
sudo apt update
sudo apt install -y ros-jazzy-desktop ros-jazzy-ros-gz
```

The scripts source `/opt/ros/jazzy/setup.bash` and use the Gazebo Python bindings
provided by these packages. Tested with Gazebo 8.15.0 on Ubuntu ARM64 in UTM.

## Run inside Ubuntu

Terminal 1:

```bash
cd ~/DroneClub/drone-sim-core
./run_sim.sh
```

The drone starts on the orange pad with motors stopped. The orange nose and
orange front propellers mark its forward direction. The world starts unpaused.
The view uses Ogre 1 and software rendering by default for Linux VMs on Macs.
Mouse drag / scroll adjusts the camera. Close older empty-world Gazebo windows
to avoid controlling the wrong simulation.

Terminal 2, choose **one** controller:

```bash
cd ~/DroneClub/drone-sim-core
./control_drone.sh
```

Keep keyboard focus in this terminal, not the Gazebo window:

| Key | Action |
| --- | --- |
| T | Take off to 1.5 m |
| W / S | Forward / backward relative to the drone's nose |
| A / D | Left / right relative to the drone's nose |
| Q / E | Turn left / right |
| R / F | Raise / lower the altitude target in 0.2 m steps (0.4–4 m) |
| Space | Stop horizontal/yaw commands and hold altitude |
| L | Land and stop motors |
| X or Ctrl+C | Land, then exit |

Horizontal flight defaults to **2 m/s** (previously 0.6 m/s). To choose a speed,
run `./control_drone.sh --speed 3` (maximum 3 m/s), or use `--speed 0.6`
for the original pace. Restart Gazebo after updating to load the higher limit.
Altitude, yaw, landing, and the automatic demo retain their original speeds.

Hold movement keys for repeated commands. Horizontal and yaw commands expire
after 0.35 seconds without another keypress while the controller runs. Hover
holds altitude and commands zero horizontal velocity; it is not XY position
hold, so small drift is possible. The controller prints position in metres.

Alternatively, fly an automatic demo:

```bash
./control_drone.sh --demo
```

From a landed start, this takes off to 1.5 m, settles, travels one metre along
world X, returns above its starting point, and lands. It prints `DEMO PASS`
only after reaching its targets and disabling the motors near the ground.

Only one simulator and one controller may run per transport partition. The
launch scripts reject duplicate sessions with an "already running" message;
use the existing window or stop it first. Separate transport partitions can
still run independently. Lock files release automatically when processes exit.

Stop the controller before stopping Gazebo. To reset after a collision, stop
both with Ctrl+C and launch again. Use only one controller at a time. If a
controller is forcibly killed, Gazebo's built-in velocity controller retains
its last command; stop the simulator rather than leaving it unattended.

## Headless validation

```bash
source /opt/ros/jazzy/setup.bash
gz sdf -k sim/drone.sdf
python3 tests/test_session_guard.py
python3 tests/flight_smoke.py
```

The smoke test starts its own headless server in a unique Gazebo transport
partition, exercises takeoff, hover, forward/return motion, yaw, lateral motion,
and landing, then checks the landed altitude and cleans up its server. It also
verifies that a duplicate simulator is rejected and only one position publisher
is present.

For a manual headless run use `./run_sim.sh -s` and the same control script.
The default transport partition is `drone_mvp`; set the same `GZ_PARTITION` in
both terminals to override it. Separate partitions keep these runs independent
of an older `empty.sdf` simulation.

## ROS 2 odometry (optional)

The MVP controls Gazebo directly using Gazebo Transport. To expose odometry
to ROS 2, use a third terminal:

```bash
source /opt/ros/jazzy/setup.bash
export GZ_PARTITION=drone_mvp
ros2 run ros_gz_bridge parameter_bridge '/drone/odometry@nav_msgs/msg/Odometry[gz.msgs.Odometry'
```

Then `ros2 topic echo /drone/odometry` shows the simulated pose and velocity.
Gazebo-native control topics are `/drone/cmd_vel` (`gz.msgs.Twist`, body-frame
linear velocity and yaw rate) and `/drone/enable` (`gz.msgs.Boolean`).

## Troubleshooting

- **Drone jumps between positions:** older simulator processes started before
  the session guard was added can still conflict. Stop all drone-world sessions
  and their controllers, then launch once with `./run_sim.sh`. An empty-world
  simulation using a different transport partition does not conflict.
- **Already running:** use the existing simulator/controller or stop it first.
  Do not delete active lock files to bypass the guard.
- **No fresh odometry / drone not found:** start the simulator, leave it
  unpaused, and use the same partition for simulator and controller.
- **Missing `gz` Python module:** source Jazzy and verify `ros-jazzy-ros-gz`
  is installed. Use Ubuntu's system Python, outside a virtual environment.
- **Cannot open display:** run the GUI from a terminal on Ubuntu's desktop.
  An ordinary SSH session can use `-s` for a headless server.
- **Low graphics performance:** close extra Gazebo instances. On a Linux host
  with working accelerated graphics, try `LIBGL_ALWAYS_SOFTWARE=0 ./run_sim.sh`.

## Files

- `sim/drone.sdf`: self-contained world, quadcopter, motor and control plugins.
- `scripts/drone_control.py`: keyboard control, altitude feedback, demo.
- `run_sim.sh` / `control_drone.sh`: environment and launch wrappers.
- `tests/flight_smoke.py`: real-physics integration check.

The motor and velocity systems are provided by Gazebo; see its
[multicopter example](https://github.com/gazebosim/gz-sim/blob/gz-sim8/examples/worlds/multicopter_velocity_control.sdf).
