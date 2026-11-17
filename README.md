# PURC Drone Simulation

Welcome to the PURC Drone Simulation guide! Use this repository and walkthrough to set up the team's simulation environment, open the 3D simulator (**Gazebo**), and fly your first virtual drone—including taking off, hovering, moving, turning, and landing.

## Table of Contents
- [How Our Setup Works](#how-our-setup-works)
- [Before You Start: Know Which Terminal to Use](#before-you-start-know-which-terminal-to-use)
- [Step 1: One-Time Computer Setup](#step-1-one-time-computer-setup)
- [Step 2: Download the Project & Build the Tools](#step-2-download-the-project--build-the-tools)
- [Step 3: Enter the Docker Workspace](#step-3-enter-the-docker-workspace)
- [Step 4: Download & Open the Drone World](#step-4-download--open-the-drone-world)
- [Step 5: Open a Second Terminal for Flight Controls](#step-5-open-a-second-terminal-for-flight-controls)
- [Step 6: Fly the X3 Drone](#step-6-fly-the-x3-drone)
- [Step 7: Save Your Custom World](#step-7-save-your-custom-world)
- [Step 8: Shut Down & Come Back Later](#step-8-shut-down--come-back-later)
- [Step 9: Fly the Same Pattern From a Script](#step-9-fly-the-same-pattern-from-a-script)
- [Step 10: Fly From ROS 2](#step-10-fly-from-ros-2)
- [Step 11: Your First ROS 2 Node](#step-11-your-first-ros-2-node)
- [Step 12: Hold a Height Using Feedback](#step-12-hold-a-height-using-feedback)
- [First-Flight Checklist](#first-flight-checklist)
- [Troubleshooting](#troubleshooting)
- [Optional: Open the Sensor Lab](#optional-open-the-sensor-lab)
- [Project Reference & Team Workflow](#project-reference--team-workflow)

---

## How Our Setup Works

Instead of making everyone manually install dozens of robotics libraries, our team packages everything: **Ubuntu, ROS 2, and Gazebo**—inside **Docker**. Think of Docker as a self-contained virtual workspace that runs identically on everyone's computer.

* **Building** the Docker image installs the tools once.
* **Running** the Docker container puts you *inside* that workspace, where your project folder appears as `/workspace`.
* All `gz` (Gazebo) and `ros2` commands **only work inside Docker**, not in your regular computer terminal.

---

## Before You Start: Know Which Terminal to Use

You will keep **two terminal windows** open side-by-side:

| Terminal | Purpose | Status |
| :--- | :--- | :--- |
| **Terminal A** | Starts the Docker workspace and launches the 3D Gazebo simulator. | **Leave running** the whole time. |
| **Terminal B** | Connects to that *same* Docker workspace so you can type flight commands. | Used to control the drone. |

> **Windows Users:** Whenever this guide says "Linux terminal," open **Ubuntu via WSL**.

---

## Step 1: One-Time Computer Setup

Follow the instructions for your operating system:

### Windows
1. Install **WSL2 with Ubuntu** and **Docker Desktop**.
2. Open **Docker Desktop**, go to **Settings**, and turn on:
   * The **WSL2 backend**
   * **WSL integration** for Ubuntu
3. Open **PowerShell** and enter Ubuntu:
   ```powershell
   wsl.exe -d Ubuntu --cd ~
   ```
   *(If Ubuntu doesn't open, check its exact installed name with `wsl.exe -l -v` and replace `Ubuntu` above.)*
4. Inside Ubuntu, install Git and the display utility needed to show the simulator window:
   ```bash
   sudo apt-get update
   sudo apt-get install -y git x11-xserver-utils
   ```

### Linux
1. Install **Docker Engine** and **Git**.
2. Open a terminal on your desktop. If you are on Ubuntu, install the same packages shown above:
   ```bash
   sudo apt-get update
   sudo apt-get install -y git x11-xserver-utils
   ```

### macOS
* Use a Linux virtual machine (VM) running a graphical **Ubuntu 24.04** desktop, then follow the **Linux** steps above.
* **Check with a team lead first:** Our current graphics and NVIDIA CUDA setup requires separate testing on Macs (especially Apple Silicon).

### Verify Docker is Ready
**Where:** Regular Linux/WSL terminal

Run:
```bash
docker version
```
You should see version details listed under both **Client** and **Server**. If **Server** is missing or shows an error, open Docker Desktop (or start the Docker service) and try again.

---

## Step 2: Download the Project & Build the Tools

**Where:** Terminal A (Regular Linux/WSL terminal)

1. Download the project code and enter the folder *(skip `git clone` if you already have the folder)*:
   ```bash
   git clone https://github.com/Drone-Autonomous-Sim/drone-sim-core.git
   cd drone-sim-core
   ```
2. Make the launcher script executable and build the Docker environment:
   ```bash
   chmod +x run_docker.sh
   docker build -t purc-drone-sim ./docker
   ```

> **Note:** The first build downloads several gigabytes of robotics tools and will take a while. Let it finish completely before moving on. You do **not** need to rebuild when editing simulation worlds later.

---

## Step 3: Enter the Docker Workspace

**Where:** Terminal A (Regular Linux/WSL terminal, inside `drone-sim-core`)

Start the workspace using **one** of these commands:
* **Standard (Most computers):**
  ```bash
  IMAGE=purc-drone-sim ./run_docker.sh
  ```
* **NVIDIA GPU (Only if Docker GPU support is already configured on your PC):**
  ```bash
  IMAGE=purc-drone-sim GPU=1 ./run_docker.sh
  ```

Your terminal prompt will change, meaning you are now **inside Docker**. Confirm everything is working:
```bash
pwd
source /opt/ros/jazzy/setup.bash
command -v gz
```
* `pwd` should output `/workspace`.
* `command -v gz` should output a file path ending in `gz`.

*(If you get an error here, stop and check [Troubleshooting](#troubleshooting) before continuing.)*

---

## Step 4: Download & Open the Drone World

**Where:** Terminal A (Inside Docker)

1. Create a worlds folder and download the test world file (you only need to do this once):
   ```bash
   mkdir -p /workspace/sim/worlds

   curl -fL --retry 3 --connect-timeout 20 \
     https://raw.githubusercontent.com/gazebosim/gz-sim/568410a5e7a085a9bd67c9a0c142a78864323926/examples/worlds/multicopter_velocity_control.sdf \
     -o /workspace/sim/worlds/multicopter_velocity_control.sdf
   ```
2. Verify the file downloaded properly (if this fails, re-run the `curl` command above):
   ```bash
   ls -lh /workspace/sim/worlds/multicopter_velocity_control.sdf
   ```
3. Launch Gazebo:
   ```bash
   gz sim -r -v 4 /workspace/sim/worlds/multicopter_velocity_control.sdf
   ```

### What You Should See
* A Gazebo window opens showing a floor and two drones: **X3** (4 rotors) and **X4** (6 rotors). We will fly **X3** first.
* **First-time launch:** Keep your internet connected—Gazebo needs a moment to download the 3D drone models before they appear.
* **Camera & Playback tips:** Make sure simulation time is ticking in the bottom-right corner (click **Play** if paused). To center your view on a drone, click its name in the right-hand **Entity Tree** and select **Move to** or **Follow**.

**Leave Terminal A running and open a new terminal window for Step 5.**

---

## Step 5: Open a Second Terminal for Flight Controls

**Where:** Terminal B (Start in a new regular Linux/WSL terminal)

1. *(Windows only)* Open a second PowerShell window and enter Ubuntu:
   ```powershell
   wsl.exe -d Ubuntu --cd ~
   ```
2. Find the ID of your currently running Docker workspace:
   ```bash
   docker ps --filter ancestor=purc-drone-sim
   ```
3. Copy the **CONTAINER ID** printed in the first column, replace `CONTAINER_ID` in the command below, and run it:
   ```bash
   docker exec -it CONTAINER_ID bash
   source /opt/ros/jazzy/setup.bash
   ```

Terminal B is now connected to the **exact same Docker container** as Terminal A.  
*(Warning: Do **not** run `./run_docker.sh` again in Terminal B—that creates a separate, disconnected container.)*

---

## Step 6: Fly the X3 Drone

**Where:** Terminal B (Inside Docker)

### How Drone Commands Work
* **Speed, not coordinates:** These commands tell the drone how fast to move (in meters per second), not where to go. For example, `0.3` means **0.3 m/s**.
* **Commands persist:** Once you tell the drone to move, it **keeps moving in that direction until you send a stop (`0`) command**.
* Each test block below sends a movement command, waits a few seconds (`sleep`), and then sends a hover command. Copy and paste the **entire block** at once.

### 1. Turn On (Arm) the Drone
```bash
gz topic -t /X3/enable -m gz.msgs.Boolean -p 'data: true'
```

### 2. Take Off and Hover
Climbs upward for 5 seconds, then levels off:
```bash
gz topic -t /X3/gazebo/command/twist -m gz.msgs.Twist \
  -p 'linear: {x: 0, y: 0, z: 0.3}, angular: {z: 0}'
sleep 5
gz topic -t /X3/gazebo/command/twist -m gz.msgs.Twist \
  -p 'linear: {x: 0, y: 0, z: 0}, angular: {z: 0}'
```
* **Check:** X3 rises, stays level, and holds its altitude. *(Note: `sleep 5` uses real-world seconds—if your computer runs the simulation slowly, the drone won't climb as high.)*

### 3. Move Forward and Hover
Flies forward (the direction the drone's front is facing) for 3 seconds, then stops:
```bash
gz topic -t /X3/gazebo/command/twist -m gz.msgs.Twist \
  -p 'linear: {x: 0.3, y: 0, z: 0}, angular: {z: 0}'
sleep 3
gz topic -t /X3/gazebo/command/twist -m gz.msgs.Twist \
  -p 'linear: {x: 0, y: 0, z: 0}, angular: {z: 0}'
```

### 4. Turn and Hover
Rotates left for 3 seconds, then stops turning:
```bash
gz topic -t /X3/gazebo/command/twist -m gz.msgs.Twist \
  -p 'linear: {x: 0, y: 0, z: 0}, angular: {z: 0.3}'
sleep 3
gz topic -t /X3/gazebo/command/twist -m gz.msgs.Twist \
  -p 'linear: {x: 0, y: 0, z: 0}, angular: {z: 0}'
```

### 5. Emergency Stop / Hover Anytime
If the drone is drifting away or you cancel a script early, run this to stop all movement:
```bash
gz topic -t /X3/gazebo/command/twist -m gz.msgs.Twist \
  -p 'linear: {x: 0, y: 0, z: 0}, angular: {z: 0}'
```
> **Important:** Pressing `Ctrl+C` in Terminal B only cancels your terminal script—it does **not** tell the drone to stop flying. Always send the zero-velocity command above (or click Pause in Gazebo) to halt the drone. Slight hovering drift is normal.

### 6. Land and Shut Off Motors
1. Command X3 to descend slowly:
   ```bash
   gz topic -t /X3/gazebo/command/twist -m gz.msgs.Twist \
     -p 'linear: {x: 0, y: 0, z: -0.2}, angular: {z: 0}'
   ```
2. Watch Gazebo until X3 touches down on the floor, then turn off its motors:
   ```bash
   gz topic -t /X3/enable -m gz.msgs.Boolean -p 'data: false'
   ```
   *(Never run `data: false` while the drone is in the air—it will drop like a rock. To fly again, re-enable it with `data: true`.)*

### Experimenting with Custom Movements
Change the numbers inside the `twist` command to fly in other directions (leave unused values at `0`):

| Parameter | Positive Value (`+`) | Negative Value (`-`) | Units |
| :--- | :--- | :--- | :--- |
| `linear.x` | Forward | Backward | meters/sec |
| `linear.y` | Left | Right | meters/sec |
| `linear.z` | Up | Down | meters/sec |
| `angular.z` | Turn Left (Counter-clockwise) | Turn Right (Clockwise) | radians/sec |

* **Want to fly the larger X4 drone instead?** Replace `/X3/` with `/X4/` in every command (including the `enable` command).

---

## Step 7: Save Your Custom World

If you add obstacles or rearrange objects in Gazebo, save your changes:

1. Land the drone and click **Pause** in Gazebo.
2. Open the **top-left menu** in Gazebo and click **Save World** (or **Save World As**). *(Do not choose "Save Window Layout".)*
3. Save it to this exact path:
   ```text
   /workspace/sim/worlds/my_world.sdf
   ```
4. Confirm the file was saved in **Terminal B**:
   ```bash
   ls -lh /workspace/sim/worlds/my_world.sdf
   ```

To open your saved world later, stop Gazebo (`Ctrl+C` in Terminal A) and run:
```bash
gz sim -r -v 4 /workspace/sim/worlds/my_world.sdf
```
*(Saving a world preserves the 3D objects and layout, not your flight path.)*

---

## Step 8: Shut Down & Come Back Later

### How to Close Everything Cleanly
1. Land the drone.
2. In **Terminal A**, press `Ctrl+C` to close Gazebo.
3. In **Terminal B**, type `exit`.
4. In **Terminal A**, type `exit`.

> **Where your files live:** Anything saved inside `/workspace` is stored directly in your `drone-sim-core` folder on your computer and is safe. Files saved anywhere else inside Docker are deleted when Terminal A closes.

### How to Restart Next Time
1. Open a Linux/WSL terminal inside `drone-sim-core` and launch Docker:
   ```bash
   IMAGE=purc-drone-sim ./run_docker.sh
   ```
   *(Add `GPU=1` before `./run_docker.sh` if you used GPU mode earlier.)*
2. Inside Docker, load ROS 2 and launch Gazebo (no need to download the world file again):
   ```bash
   source /opt/ros/jazzy/setup.bash
   gz sim -r -v 4 /workspace/sim/worlds/multicopter_velocity_control.sdf
   ```
3. Follow [Step 5](#step-5-open-a-second-terminal-for-flight-controls) to connect Terminal B for flight controls.

## Step 9: Fly the Same Pattern From a Script

**Where:** Terminal B (Inside Docker), with the drone world open in Terminal A and X3 on the ground.

Typing six commands for every test flight gets old. A script is just those commands saved in a file and run in order. The repo includes one that does all of Step 6:
```bash
bash /workspace/sim/scripts/fly_x3.sh
```

### What You Should See
* Terminal B prints each phase (`arm`, `climb for 5 s`, `forward for 3 s`, ...) as it starts.
* X3 arms, climbs, hovers, flies forward, turns left, descends to the floor, and switches its motors off. The whole flight takes about 30 seconds.

### Read the Script
Open `sim/scripts/fly_x3.sh` in any editor. It is under 50 lines, half of them comments, and every `gz topic` line is one you typed in Step 6. The only new idea is `move`, a three-line shortcut so the velocity command is written once instead of six times.

Each of those `gz topic` lines has the same three parts: `-t` is the topic, which is just a name for a channel of messages; `-m` is the message type; `-p` is the message's contents. So `-t /X3/gazebo/command/twist` says *where*, `-m gz.msgs.Twist` says *what kind*, and `-p 'linear: {...}'` gives *the values*. Gazebo's own walkthrough of that command is the [Moving the robot](https://gazebosim.org/docs/harmonic/moving_robot/) page, five minutes well spent.

Change a number in the script, run it again, watch what happens: every later step in this guide starts the same way.

> **If X3 is already in the air**, land it first (Step 6.6); the script assumes it starts on the ground.
> **If the script stops partway**, send the hover command from Step 6.5, land, and re-run.

---

## Step 10: Fly From ROS 2

**Where:** Terminal B (Inside Docker) for the bridge, plus a new **Terminal C** opened the same way as Step 5. Drone world open in Terminal A, X3 on the ground.

So far you have talked to Gazebo directly. That is fine for one drone in a simulator. The real drone's software will be several programs that have to talk to each other: one reading the lidar, one building a map, one planning a path, one talking to the flight controller. If each of those had to know how to connect to every other, adding or replacing one would mean changing all of them, and swapping the simulated lidar for the real one would mean rewriting the map builder. **ROS 2** is the standard way robotics software avoids that. It has two core ideas. A **node** is one program with one job. A **topic** is a named channel; nodes *publish* messages to topics and *subscribe* to topics, and never need to know who is on the other end. So the map-building node subscribes to a lidar topic and does not care whether the lidar is simulated or real. (The ROS 2 docs introduce both in [Understanding nodes](https://docs.ros.org/en/jazzy/Tutorials/Beginner-CLI-Tools/Understanding-ROS2-Nodes/Understanding-ROS2-Nodes.html) and [Understanding topics](https://docs.ros.org/en/jazzy/Tutorials/Beginner-CLI-Tools/Understanding-ROS2-Topics/Understanding-ROS2-Topics.html).)

Gazebo has its own topics, the ones you used in Step 6, and ROS 2 cannot see them. A small program called the **bridge** copies messages between the two systems and converts the message type on the way. The file `sim/bridge/x3.yaml` tells it which three topics to copy and what to call each on the ROS side. Here is what this step builds, left to right:

```text
+-------------------------+     +---------------------+     +-------------------------------+
|  ROS 2 side (Terminal C)|     |       bridge        |     |   Gazebo side (Terminal A)    |
|                         |     |                     |     |                               |
|  ros2 topic pub  -------+---->|  Twist  ->  Twist   +---->|  /X3/gazebo/command/twist     |
|    to /x3/cmd_vel       |     |                     |     |    X3 moves                   |
|                         |     |                     |     |                               |
|  ros2 topic echo <------+-----+ Odometry <- Odometry|<----+  /model/x3/odometry           |
|    on /x3/odom          |     |                     |     |    X3 reports its position    |
|                         |     |                     |     |                               |
+-------------------------+     +---------------------+     +-------------------------------+
 topic names: ours to            copies every message,       topic names: fixed by
 choose (in x3.yaml)             converts its type           the world file
```

1. In Terminal B, start the bridge and leave it running:
   ```bash
   ros2 run ros_gz_bridge parameter_bridge --ros-args -p config_file:=/workspace/sim/bridge/x3.yaml
   ```
   It prints one `Creating ... bridge` line per topic, then waits.
2. Open Terminal C like Step 5 (`docker ps`, `docker exec`, `source`) and list the ROS topics:
   ```bash
   ros2 topic list
   ```
   You should see `/x3/enable`, `/x3/cmd_vel` and `/x3/odom`.
3. Arm and take off:
   ```bash
   ros2 topic pub --once /x3/enable std_msgs/msg/Bool "{data: true}"
   ros2 topic pub --once /x3/cmd_vel geometry_msgs/msg/Twist "{linear: {z: 0.3}}"
   ```
4. After a few seconds, hover, then ask the drone where it is:
   ```bash
   ros2 topic pub --once /x3/cmd_vel geometry_msgs/msg/Twist "{}"
   ros2 topic echo --once /x3/odom --field pose.pose.position
   ```
   `z` is the height in metres.
5. Land, wait until X3 is on the floor, then disarm:
   ```bash
   ros2 topic pub --once /x3/cmd_vel geometry_msgs/msg/Twist "{linear: {z: -0.2}}"
   ```
   ```bash
   ros2 topic pub --once /x3/enable std_msgs/msg/Bool "{data: false}"
   ```

### What the Commands Mean
`ros2 topic pub` is the ROS 2 twin of `gz topic -p`: topic name, message type, then the message as YAML. `--once` means publish one message and exit. Any field you leave out is zero, which is why `"{}"` is the hover command. The two message types are standard ROS ones: a `Twist` is a velocity split into linear and angular parts, and an `Odometry` is an estimate of position and velocity. Their definitions are one short file each, [Twist.msg](https://github.com/ros2/common_interfaces/blob/jazzy/geometry_msgs/msg/Twist.msg) and [Odometry.msg](https://github.com/ros2/common_interfaces/blob/jazzy/nav_msgs/msg/Odometry.msg).

### Read the Config
Open `sim/bridge/x3.yaml`. Each entry has five fields: the ROS-side name, the Gazebo-side name, the two message types, and `direction`, which is `ROS_TO_GZ`, `GZ_TO_ROS` or `BIDIRECTIONAL`. The ROS-side names (`/x3/...`) are ours to choose; the Gazebo-side names are fixed by the world file; `cmd_vel` is the name ROS programs conventionally use for a velocity command. The full list of fields is in the [ros_gz_bridge README](https://github.com/gazebosim/ros_gz/blob/ros2/ros_gz_bridge/README.md).

The point of the whole step: `/x3/cmd_vel` is now a ROS 2 topic, so **any ROS 2 program that publishes a Twist to it flies the drone**.

> **`ros2 topic pub` just sits there** saying it is waiting for a subscriber: the bridge is not running. Check Terminal B.
> **`ros2 topic list` shows nothing** or only `/parameter_events` and `/rosout`: Terminal C was not sourced, or the bridge is not running. Sourcing is what makes the `ros2` commands exist in a terminal, and it has to be done in every new one.

---

## Step 11: Your First ROS 2 Node

**Where:** Terminal C (Inside Docker), with the world open in Terminal A, the bridge from Step 10 running in Terminal B, and X3 on the ground.

Everything so far was typed by hand. A ROS 2 program that sends those messages itself is a **node**, the "one program, one job" idea from Step 10. The repo has one whose one job is: arm X3, climb for 5 seconds, then hover.
```bash
python3 /workspace/sim/nodes/hover.py
```

### What You Should See
* X3 arms and climbs for 5 seconds, then holds about 1.5 m up.
* After 6 seconds the node prints `hovering; land with the Step 10 commands` and exits. X3 keeps hovering: Gazebo holds the last velocity command (zero) until told otherwise.
* Land and disarm with the commands in Step 10.5.

### Read the Node
Open `sim/nodes/hover.py`. It is 50 lines, and its shape is the shape of every ROS 2 node:
1. `class Hover(Node)` creates the node; `super().__init__("hover")` gives it its name.
2. `create_publisher` opens the two topics from Step 10, `/x3/enable` and `/x3/cmd_vel`. The `10` at the end is the queue size, how many unsent messages to hold.
3. `create_timer(0.1, self.tick)` makes ROS call `tick()` ten times a second.
4. `tick()` decides what to send this time: climb for the first 50 ticks, zeros after that.
5. `main()` initialises ROS, creates the node, and keeps it spinning so the timer fires.

That is the same skeleton as the official [publisher tutorial](https://docs.ros.org/en/jazzy/Tutorials/Beginner-Client-Libraries/Writing-A-Simple-Py-Publisher-And-Subscriber.html), with a drone instead of a string message. Change the `50` to `100` and X3 climbs twice as high. Move the `0.3` from `cmd.linear.z` to `cmd.linear.x` and it goes forward instead of up. Every later node adds to this skeleton; none replaces it.

> **`ModuleNotFoundError: No module named 'rclpy'`:** Terminal C was not sourced. Run `source /opt/ros/jazzy/setup.bash` and try again.
> **The node runs but X3 does not move:** the bridge is not running in Terminal B, or Gazebo is paused.

---

## Step 12: Hold a Height Using Feedback

**Where:** Terminal C (Inside Docker), with the world open in Terminal A, the bridge from Step 10 running in Terminal B, and X3 on the ground.

`hover.py` flew blind: climb for 5 seconds and hope the height is right. This node reads the drone's position back from `/x3/odom` and corrects, which is what every controller does, from this one to the real autopilot:
```bash
python3 /workspace/sim/nodes/altitude_hold.py
```

### What You Should See
* Once a second the node prints the height, the target (2 m) and the climb speed it chose.
* The climb speed starts at +0.50 m/s and shrinks as X3 gets closer, until the height reads 2.00 m and the speed reads 0.
* It runs until you press `Ctrl+C`. X3 keeps hovering afterwards; land with Step 10.5.

### Read the Node
Open `sim/nodes/altitude_hold.py`. Compared with `hover.py`, two things are new.

**1. A subscriber.** Publishing is only half of ROS 2. `create_subscription(Odometry, "/x3/odom", self.on_odom, 10)` asks ROS to call `on_odom()` whenever a position message arrives on that topic. That is how a node reads anything: it does not ask, it gets called. Sensor data, robot position, anything that streams continuously, arrives this way.

**2. A feedback loop.** `tick()` computes `error = TARGET - height` and commands `speed = GAIN * error`, capped at 0.5 m/s. Far below the target: climb fast. Nearly there: climb slowly. At the target: stop. Output proportional to error is the simplest kind of feedback, a [proportional controller](https://en.wikipedia.org/wiki/Proportional_control), and it is the first thing inside every autopilot.

Two numbers to play with: `TARGET` (try 1.0 or 3.0) and `GAIN` (try 3.0, and watch it overshoot and wobble before settling). Those two experiments are most of what a controls course teaches in its first week.

> **The node prints nothing:** it has not received a position yet. Check the bridge is running and that `ros2 topic echo --once /x3/odom` shows data.
> **X3 climbs past the target and keeps going:** `GAIN` is negative or the bridge is sending stale data. Reset both numbers to the values in the file.

---

## First-Flight Checklist

Complete these milestones to verify your setup works:

- [ ] Docker builds and starts without errors
- [ ] Gazebo opens and both drones (X3 and X4) appear
- [ ] X3 takes off and hovers
- [ ] X3 moves forward and stops
- [ ] X3 turns and stops
- [ ] X3 lands safely before its motors are disabled
- [ ] A saved world file (`my_world.sdf`) reopens properly
- [ ] `fly_x3.sh` completes a full flight and X3 ends on the floor with motors off
- [ ] X3 takes off from a `ros2 topic pub` command and `/x3/odom` reports its height
- [ ] `hover.py` takes X3 off and leaves it hovering
- [ ] `altitude_hold.py` reports `height 2.00 m` and holds there

**Need help?** Message a team lead with the **step number** that failed and copy-paste the exact terminal error. If you modified flight behavior, include a short screen recording.

---

## Troubleshooting

Click the error that matches what you see:

<details>
<summary><strong>“gz” or “ros2”: command not found</strong></summary>

You are likely running the command in your regular computer terminal instead of inside Docker. Enter Docker using [Step 3](#step-3-enter-the-docker-workspace) (Terminal A) or [Step 5](#step-5-open-a-second-terminal-for-flight-controls) (Terminal B), then run:
```bash
source /opt/ros/jazzy/setup.bash
command -v gz
command -v ros2
```
</details>

<details>
<summary><strong>“Failed to authorize local X11 access” or “cannot open display”</strong></summary>

Docker cannot connect to your screen to open the Gazebo window.

In your **regular Ubuntu terminal (outside Docker)**, check your display settings:
```bash
echo "$DISPLAY"
xhost
```
* If `xhost` is missing, install `x11-xserver-utils` (see [Step 1](#step-1-one-time-computer-setup)).
* On Windows (WSLg), `DISPLAY` should read `:0`. Check that the display socket `X0` exists:
  ```bash
  ls -la /tmp/.X11-unix/
  ls -la /mnt/wslg/.X11-unix/
  ```
* If `/mnt/wslg/.X11-unix/` is missing `X0`, save your work, open **PowerShell**, and run `wsl.exe --shutdown` to restart WSL (you may also need to reopen Docker Desktop afterward). If only `/tmp/.X11-unix/` is missing `X0`, follow Microsoft's WSLg display troubleshooting guide.
</details>

<details>
<summary><strong>Docker says the image is missing, or reports a GPU error</strong></summary>

* Verify [Step 2](#step-2-download-the-project--build-the-tools) finished without errors and that you used the exact name `purc-drone-sim` in both the `build` and `run_docker.sh` commands.
* If `GPU=1` fails, run `IMAGE=purc-drone-sim ./run_docker.sh` without `GPU=1`. GPU mode requires working NVIDIA host drivers and the NVIDIA Container Toolkit.
* If Gazebo opens with a black screen or OpenGL error, check Gazebo's graphics troubleshooting documentation.
</details>

<details>
<summary><strong>“No such file” or a 3D model fails to load</strong></summary>

List all world files currently inside `/workspace` to verify exact filenames:
```bash
find /workspace -type f \( -iname '*.sdf' -o -iname '*.world' \)
```
* If the default world is missing, re-download it using [Step 4](#step-4-download--open-the-drone-world).
* Make sure you have an active internet connection the first time you launch a world so Gazebo can fetch drone models. Always save custom worlds inside `/workspace` so they aren't lost when a container closes.
</details>

<details>
<summary><strong>The drone appears in Gazebo, but ignores flight commands</strong></summary>

Make sure:
1. Gazebo is **playing** (not paused).
2. Terminal B is attached to the **same container** as Terminal A ([Step 5](#step-5-open-a-second-terminal-for-flight-controls)).
3. You opened `multicopter_velocity_control.sdf` (the optional sensor lab does not include a flying drone).
4. You sent the `/X3/enable` command (`data: true`).

To check if Gazebo is listening for your commands, run in **Terminal B**:
```bash
gz topic -l
gz topic -i -t /X3/gazebo/command/twist
```
You should see a subscriber listed under the twist topic. If none appears, check Terminal A for plugin or model loading errors.
</details>

---

## Optional: Open the Sensor Lab

Our repo also includes a stationary sensor testbed (camera, lidar, and IMU—no flying drone). Stop the drone world (`Ctrl+C` in Terminal A), then run inside **Terminal A (Docker)**:
```bash
source /workspace/PURC_Gazebo_Starter/purc_gazebo_starter/scripts/env.sh
gz sim -r -v 4 "$PURC_LAB_ROOT/worlds/purc_lab.sdf"
```

---

## Project Reference & Team Workflow

* **Software inside the Docker image:** Ubuntu 24.04, ROS 2 Jazzy, Gazebo Harmonic, OpenCV, `colcon`, and PyTorch with CUDA support.
* **Flight stack status:** This guide uses Gazebo's built-in velocity controller. **PX4** autopilot and **SLAM** integration are separate development tasks.
* **Target physical hardware:** Jetson Orin Nano, Livox Mid-360 lidar, OAK-D Lite camera, and Pixhawk 6X flight controller. *(Note: The sensor lab uses generic simulated sensors, not exact hardware replicas.)*
* **Contributing code:**
  * Always create a **feature branch**, test your changes, and open a **Pull Request (PR)** for review—never push directly to `main`.
  * Do not commit large downloaded models or screen recordings to Git.
  * Our automated CI checks verify that the Docker image builds, so a team member must still run the [First-Flight Checklist](#first-flight-checklist) manually to confirm graphics and flight behavior work properly.