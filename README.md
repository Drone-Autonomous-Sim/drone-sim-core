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