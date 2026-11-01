# PURC Drone Team: Gazebo testing and importing guide

Prepared for Mohid Malik and Princeton University Robotics Club, October 31, 2026.

Repository reviewed: https://github.com/Drone-Autonomous-Sim/drone-sim-core

Snapshot: `main` at `f8c59109facb41db7f5285e34bcaa37c8a6e17e6`.

## 1. What the repository currently provides

It provides a Docker build recipe for Ubuntu 24.04, ROS 2 Jazzy, Gazebo Harmonic integration, colcon, OpenCV, and a CUDA PyTorch stack. It also provides a script that starts a container and forwards its graphical windows to the host.

It does **not** yet contain a drone, environment, ROS package, flight controller, SLAM pipeline, sensor configuration, or simulation test suite. The `src/drone_control`, `src/drone_perception`, and `src/drone_description` folders shown in the README are planned structure. There are no `package.xml`, `.sdf`, `.urdf`, or `.xacro` files in the reviewed repository.

This means you can use the image as a starting workspace, but the club still needs shared simulation assets and tests. Merely starting Gazebo does not start a drone or connect sensors to ROS.

### What was actually checked

| Check | Result | Meaning |
|---|---|---|
| Read all six tracked files | Completed | Reviewed the complete repository snapshot, not only its README. |
| Bash syntax | Passed | `run_docker.sh` parses as Bash. |
| Compose and workflow YAML | Passed | Both parse as YAML; this is not Docker's runtime validation. |
| Launcher tests | 50 checks passed | Dry runs for Linux, WSL and macOS; GPU flags; paths with spaces; image override; missing display handling; mocked Docker/X11 invocation and cleanup. |
| Latest successful GitHub build | Reviewed | Run 36280023306 succeeded September 26, 2026. Logs show an image build. Its Dockerfile matches the current one after normalizing line endings. |
| New starter examples | XML/YAML/shell/reference checks passed | These checks do not validate physics, rendering, SDF semantics, plugin loading, or actual ROS messages. |
| Fresh image build, Gazebo GUI, sensors and flight | **Not executed here** | This workspace has no Docker, ROS 2 or Gazebo. Local verification is required. |

The test harness uses mock executables for Docker and X11. None of those 50 checks runs a simulator. Native Wayland runtime forwarding was not tested. The existing GitHub workflow builds the image only; it does not launch Gazebo, spawn a drone, inspect sensors or test flight. It also skips its build job when the actor is `Sea-farer`.

### Setup issues to address

- The README clone command contains literal `<` and `>` characters. Bash treats these as redirection; use the corrected command below.
- Use the current Compose command, `docker compose`, instead of assuming the old standalone `docker-compose` executable exists.
- `docker-compose.yml` always requests an NVIDIA GPU when starting its service. `run_docker.sh` requests one only when `GPU=1`. These are different startup paths.
- The launcher does **not** assign the Compose name `gazebo_drone_sim`. Use `docker ps` to find the launcher-created container.
- The default image name in the launcher depends on the expected Compose project name. An explicit image tag avoids folder-name surprises.
- The image and package versions are not fully pinned. A successful build last month is useful evidence, not proof that every future build is identical.
- The macOS branch attempts XQuartz, while the README recommends a Linux VM. Neither Apple Silicon builds nor VM graphics have been verified by this review. The CUDA image and CUDA wheels make a universal Mac setup an assumption requiring testing.
- Changes under `/workspace` persist because it is a mounted repository. Packages installed interactively elsewhere in the container and Fuel downloads under `/root/.gz` disappear when the `--rm` container exits.

Do not advertise the current setup as operating identically on all three operating systems until a member has passed the same acceptance checklist on each supported platform.

## 2. The pieces, in plain language

| Piece | What it does |
|---|---|
| Docker image | A packaged Linux software installation. Building it installs the tools. |
| Container | A running instance of that installation. Gazebo and ROS run inside it. |
| World, usually `.sdf` | The entire scene: ground, lighting, physics settings, objects and robots. |
| Model | One reusable thing: drone, building, tree, sensor rig or obstacle. |
| Mesh, such as `.dae` or `.stl` | A shape. It does not define working motors, sensors or flight behavior. |
| SDF | XML describing a world or model, including its simulation properties. |
| URDF/Xacro | Robot descriptions often used by ROS; Gazebo can import supported URDF descriptions, but simulation still needs suitable inertias, collisions and systems. |
| Gazebo system/plugin | A component that adds physics, sensor generation, motor forces, control or another behavior. |
| Gazebo Transport topic | A named channel used inside Gazebo to send commands or sensor readings. |
| ROS topic | A corresponding channel used by ROS programs. |
| `ros_gz_bridge` | A translator between selected ROS and Gazebo message types. It does not create a missing sensor or controller. |
| PX4 SITL | PX4 autopilot software running on a computer instead of a physical flight controller. |
| TF | ROS's description of where coordinate frames are relative to one another. |

A model loading successfully establishes only that it can be inserted. A useful drone also needs physically reasonable mass and inertia, collision geometry, rotor joints and force systems, working sensors, and a controller with correctly connected commands.

## 3. Prepare a member's machine

### Windows

Use the Ubuntu terminal inside WSL2 for the Linux commands in this guide. Run Docker Desktop with the WSL2 backend and enable integration for that Ubuntu distribution. Current WSL supports Linux GUI applications through WSLg; do not begin by installing another X server or replacing WSLg's `DISPLAY` value.

In PowerShell, check WSL and update if needed:

```powershell
wsl --status
wsl --update
```

In Ubuntu, install basic host-side tools:

```bash
sudo apt-get update
sudo apt-get install -y git x11-xserver-utils
docker version
docker compose version
echo "$DISPLAY"
```

`x11-xserver-utils` supplies `xhost`, which the launcher requires for its X11 path. Keep the checkout in the WSL Linux filesystem, for example `~/drone-sim-core`, for normal Linux file behavior and performance.

### Linux

Use a graphical desktop session and install Docker Engine, the Compose plugin, Git and `xhost` using the distribution's instructions. On Ubuntu, `xhost` is provided by `x11-xserver-utils`. Verify `docker version` works before starting the project. An SSH terminal with no display will not satisfy the current GUI launcher.

NVIDIA passthrough requires a working host driver and Docker GPU configuration. Installing CUDA in the image does not configure those host components. Start without `GPU=1` unless passthrough is already configured.

### macOS

The repository README recommends a Linux VM. Use a graphical Ubuntu 24.04 VM with Docker inside it and run the Linux instructions there. Confirm Gazebo's graphics requirements before promising that VM to the whole team. Apple Silicon architecture, image compatibility and graphics performance require a separate trial. A shared Linux workstation accessed remotely is another practical route.

The script also contains an XQuartz route for direct macOS execution. That code path passing a dry run does not establish that Gazebo renders correctly on a Mac.

## 4. Build and enter the current image

Commands in this subsection run on the host Linux terminal: WSL Ubuntu, Linux desktop, or the Linux VM.

```bash
git clone https://github.com/Drone-Autonomous-Sim/drone-sim-core.git
cd drone-sim-core
git switch -c sim/first-gazebo-test
chmod +x run_docker.sh

docker build -t purc-drone-sim -f docker/Dockerfile .
IMAGE=purc-drone-sim ./run_docker.sh
```

This builds the same Dockerfile directly and gives its result a predictable name. It avoids starting the Compose service with its mandatory NVIDIA reservation. The first build can be large and slow because it includes CUDA development tools and PyTorch.

If NVIDIA passthrough is configured and desired, use this **instead of** the final command:

```bash
IMAGE=purc-drone-sim GPU=1 ./run_docker.sh
```

The final command opens a shell **inside the container**. Subsequent `ros2` and `gz` commands run there. Keep that shell open.

If using the README's Compose build instead, `docker compose build` is suitable; make sure `IMAGE` names the image that was actually produced. Do not mix the two startup methods during your first test.

### Open additional terminals in the same container

Gazebo occupies its terminal while running. You need another terminal for commands and another for the bridge.

Open a new **host** terminal:

```bash
docker ps --format 'table {{.ID}}\t{{.Image}}\t{{.Names}}'
docker exec -it CONTAINER_ID bash
```

Replace `CONTAINER_ID` with the ID printed for the `purc-drone-sim` container. Repeat `docker exec` for later terminals. Do not run `./run_docker.sh` again merely to obtain a second shell: that starts another container.

In each container terminal:

```bash
source /opt/ros/jazzy/setup.bash
cd /workspace
```

The launcher does not use the Compose container name `gazebo_drone_sim`.

## 5. First test: can Gazebo run at all?

Inside the container:

```bash
echo "$ROS_DISTRO"
ros2 pkg prefix ros_gz_sim
ros2 pkg prefix ros_gz_bridge
gz sim --help
ros2 launch ros_gz_sim gz_sim.launch.py gz_args:="empty.sdf -r -v 4"
```

Expected: Jazzy is selected, the packages are found, and a Gazebo window opens with a ground plane. `-r` starts the simulation; `-v 4` prints detailed logs. Try pause and play and confirm simulation time advances.

In a second container terminal:

```bash
gz topic -l
gz service -l
```

You should see simulation topics and `/world/...` services. `ros2 topic list` may still contain few topics: Gazebo's internal topics are separate until bridged.

Use Ctrl+C in the first terminal to stop this world before launching the next one. For onboarding, run one Gazebo server at a time.

## 6. Use the included starter lab

The companion ZIP contains `purc_gazebo_starter/`. Extract it and copy that directory into the root of the cloned repository. This is a proposed set of examples; it is **not already in GitHub**, and its Gazebo runtime behavior has not been executed in this review.

The host layout should now include `drone-sim-core/purc_gazebo_starter/worlds/purc_lab.sdf`. In the container, the same file is `/workspace/purc_gazebo_starter/worlds/purc_lab.sdf`.

Included files:

| Path | Purpose |
|---|---|
| `worlds/purc_lab.sdf` | Ground, an orange wall, physics systems and a stationary sensor rig. |
| `models/test_box/` | Dynamic cube for gravity, collision and insertion tests. |
| `models/sensor_rig/` | Generic RGB camera, 3D lidar and IMU attached to a stationary model. |
| `config/sensors.yaml` | Gazebo-to-ROS bridge mappings for clock and sensors. |
| `scripts/env.sh` | Adds this example's model and world directories to Gazebo's search path. |

In **each container terminal used for the lab**:

```bash
source /opt/ros/jazzy/setup.bash
source /workspace/purc_gazebo_starter/scripts/env.sh
```

The search path tells Gazebo where a reference such as `model://sensor_rig` can be found. It must be set before the Gazebo server starts.

Validate the SDF with the installed tool, then launch it in Terminal A:

```bash
gz sdf -k "$PURC_LAB_ROOT/worlds/purc_lab.sdf"
gz sdf -k "$PURC_LAB_ROOT/models/sensor_rig/model.sdf"
gz sdf -k "$PURC_LAB_ROOT/models/test_box/model.sdf"
gz sim -r -v 4 "$PURC_LAB_ROOT/worlds/purc_lab.sdf"
```

Expected: a grey floor, orange wall and small stationary sensor rig. The rig is intentionally fixed in midair; this isolates sensor setup from flight dynamics. It is not a drone, a Livox Mid-360 model or an OAK-D Lite model.

In Terminal B, insert a cube above the ground:

```bash
ros2 run ros_gz_sim create \
  -world purc_lab \
  -file "$PURC_LAB_ROOT/models/test_box/model.sdf" \
  -name falling_box \
  -x -2 -y 0 -z 3
```

Expected: the blue cube falls and rests on the floor. A half-meter cube on a floor at z=0 should settle with its center near z=0.25. It should not pass through the floor. If repeating the command, delete the old cube in the GUI or use a different name.

The `-world` argument is the XML world name, `purc_lab`, not the filename. `-file` is an absolute path inside the container. Spawning requires the running world to provide its UserCommands system, included in this example.

## 7. Import environments and objects

### Try objects interactively with Fuel

1. Open a working world in Gazebo.
2. Open the top-right plugin menu and select **Resource Spawner**.
3. Expand **Fuel resources**, select a provider, and search for an object.
4. Download a small model with the cloud button.
5. Select it and click in the scene to place it.
6. Use translation/rotation tools to position it. Ensure its bottom is on the ground.
7. Check collisions and sensor visibility, not just appearance.

Start with a small building, box or tree. Large scenes can introduce long downloads, missing dependencies and poor rendering performance before you have established that the basic setup works.

Fuel is an asset collection. A visually detailed building may have simplistic collision geometry, and a UAV asset may contain no flight controller.

### Make the scene repeatable

Interactive placement is useful for exploration. For a team experiment, save the world and inspect the saved SDF, or explicitly add an `<include>` inside its `<world>` element:

```xml
<include>
  <uri>model://test_box</uri>
  <name>obstacle_box</name>
  <pose>2 1 0.25 0 0 0</pose>
  <static>true</static>
</include>
```

This example uses the supplied local cube as a fixed obstacle. The pose is `x y z roll pitch yaw`; distances are meters and angles are radians. The center is 0.25 meters high because the cube is 0.5 meters tall.

For a Fuel asset, paste its actual include URL from Fuel. Prefer a specific model version when reproducibility matters. Check the saved world for machine-specific paths, missing resources and assets not included in Git.

### Import downloaded local models

A typical model directory contains `model.config`, `model.sdf`, and any referenced `meshes/` or `materials/` directories. Keep the whole directory together. For this starter, put it under:

```text
purc_gazebo_starter/models/my_building/
```

Then include `model://my_building` in the world. The existing environment script adds the parent `models/` directory to `GZ_SIM_RESOURCE_PATH`. Restart Gazebo after changing that search path.

### Open an existing complete world

Place its SDF under `worlds/` and keep all referenced assets in your resource paths:

```bash
gz sim -r -v 4 /workspace/purc_gazebo_starter/worlds/my_environment.sdf
```

`my_environment.sdf` is a placeholder for the actual file you imported. A complete world is loaded at startup; it is not spawned with the model-creation command.

### Import Blender or CAD work

Export meshes in a supported format, such as DAE or STL, then reference them from a model SDF. Add suitable collision geometry, material references, scale and, for moving bodies, mass/inertia. A mesh file alone is not a usable flight simulation. Use simple collision shapes when a detailed triangle mesh is unnecessary.

For terrain, verify scale, heightmap dependencies, ground collision and traversable space before adding the aircraft.

## 8. Check sensors before attempting SLAM

Run the starter lab in Terminal A. In Terminal B:

```bash
gz topic -l
gz topic -i -t /purc/camera/image
gz topic -i -t /purc/lidar/points
gz topic -i -t /purc/imu
gz topic -e -t /purc/imu
```

Use Ctrl+C to stop an echo. Expected: camera images, lidar point clouds, and IMU messages. The lidar system normally adds `/points` to its configured base topic. If your installed release publishes a different name, discover it with `gz topic -l` and update the YAML to match the actual name and type. Do not assume a topic exists because it appears in a config file.

The scene needs the Sensors system for camera/GPU-lidar data and the Imu system for the IMU. Those are included in the starter world. Camera and GPU lidar still need a functioning rendering backend even if the GUI itself is closed.

Start the bridge in Terminal B:

```bash
ros2 run ros_gz_bridge parameter_bridge --ros-args \
  -p config_file:="$PURC_LAB_ROOT/config/sensors.yaml"
```

In Terminal C:

```bash
ros2 topic list -t
ros2 topic echo /clock --once
ros2 topic echo /purc/imu --once --qos-reliability best_effort
ros2 topic echo /purc/lidar/points --once --field header --qos-reliability best_effort
ros2 topic hz /purc/camera/image
```

Expected target settings are 15 camera frames, 10 lidar scans and 100 IMU updates per simulated second. Lower observed wall-clock rates may reflect a simulation running slower than real time, computer load or subscriber overhead. Measure before increasing resolution or sensor frequency.

Use RViz for the point cloud:

```bash
rviz2 --ros-args -p use_sim_time:=true
```

Read the point cloud's `header.frame_id` from the earlier command. For this first diagnostic, set RViz's **Fixed Frame** to that exact value, add a **PointCloud2** display, and select `/purc/lidar/points`. You should see returns from the wall and floor. This frame choice is only a simple sensor check. A moving robot needs an actual TF tree; it is not a substitute for odometry or map frames.

For camera viewing, use an Image display or `rqt_image_view` if installed:

```bash
ros2 run rqt_image_view rqt_image_view
```

If that optional package is missing, add `ros-jazzy-rqt-image-view` to the Dockerfile and rebuild, rather than asking every member to install it manually in a disposable container.

Before connecting a SLAM algorithm, verify timestamps, `use_sim_time`, lidar-to-IMU transforms, units, frame conventions and the exact input message type. A generic `PointCloud2` stream does not satisfy an algorithm that specifically requires Livox custom packets, point timing or ring metadata. The supplied lidar is a generic 16-layer scan and does not recreate the Mid-360's scan pattern. The RGB camera does not recreate OAK-D depth, calibration or onboard inference.

## 9. Import and fly a drone

### Importing a drone model

For a local SDF drone, keep the complete model directory under the shared model path. Spawn it like the cube, using its actual file:

```bash
ros2 run ros_gz_sim create \
  -world purc_lab \
  -file /workspace/purc_gazebo_starter/models/my_drone/model.sdf \
  -name drone_1 -x 0 -y -3 -z 0.5
```

`my_drone` is an example name; that model is not included. Set the spawn height for the imported model's actual dimensions, with no collision overlap. Verify its SDF and required plugins before starting.

For a plain URDF, the create executable can also accept the description file. Expand Xacro into URDF first using a compatible Xacro installation. Importing a ROS robot description does not automatically supply an aerodynamic model, working propellers or an autopilot.

A falling UAV may simply lack a controller or motor-force systems. A permanently floating UAV may be static or have gravity disabled. Both can look plausible in a screenshot without providing flight dynamics.

### Start with Gazebo's reference velocity-control example

Stop the starter world first. Inside the container, try:

```bash
gz sim -r -v 4 multicopter_velocity_control.sdf
```

Gazebo ships example worlds; this one contains a controller and motor-force systems. If your image cannot locate it, retrieve the Harmonic branch's example into the mounted workspace:

```bash
mkdir -p /workspace/sim/worlds
curl -fL \
  https://raw.githubusercontent.com/gazebosim/gz-sim/gz-sim8/examples/worlds/multicopter_velocity_control.sdf \
  -o /workspace/sim/worlds/multicopter_velocity_control.sdf
gz sim -r -v 4 /workspace/sim/worlds/multicopter_velocity_control.sdf
```

This upstream example also downloads Fuel drone assets, so it needs network access on first use. Record the downloaded file's checksum and asset versions before adopting it as the team's reference. It was inspected in source, not flown during this review.

In another terminal in the **same** container:

```bash
gz topic -l
gz topic -t /X3/enable -m gz.msgs.Boolean -p 'data: true'
gz topic -t /X3/gazebo/command/twist -m gz.msgs.Twist \
  -p 'linear: {x: 0, y: 0, z: 0.3}, angular: {z: 0}'
```

The last command requests upward velocity, not a target altitude. After a short climb, send a hover request:

```bash
gz topic -t /X3/gazebo/command/twist -m gz.msgs.Twist \
  -p 'linear: {x: 0, y: 0, z: 0}, angular: {z: 0}'
```

Then try slow forward motion, followed by another zero command:

```bash
gz topic -t /X3/gazebo/command/twist -m gz.msgs.Twist \
  -p 'linear: {x: 0.2, y: 0, z: 0}, angular: {z: 0}'
```

Velocity is expressed in the vehicle's body frame. Forward follows the drone's heading. A command may remain active until replaced; closing the publishing terminal does not establish that the controller stops. Zero velocity is a hover request, not a precise position-hold guarantee. Do not disable the controller in flight to request hover: disabling it removes thrust and the drone falls.

These topic names are for the inspected upstream X3 example. Other aircraft can use different topics and message types.

To send this example's velocity command from ROS, run a separate bridge:

```bash
ros2 run ros_gz_bridge parameter_bridge \
  '/X3/gazebo/command/twist@geometry_msgs/msg/Twist]gz.msgs.Twist'
```

Then, from another terminal:

```bash
ros2 topic pub --once /X3/gazebo/command/twist geometry_msgs/msg/Twist \
  '{linear: {x: 0.0, y: 0.0, z: 0.3}, angular: {x: 0.0, y: 0.0, z: 0.0}}'
```

Publish another message with z=0 after the climb. This ROS command bridge is distinct from the sensor bridge used for the starter lab.

### Put a working drone into a custom environment

Start by copying the **working drone example world**. Add obstacle/environment includes to it while preserving the drone's controller, motor systems, namespaces and world systems. Load that copy and repeat the flight test.

This is more dependable than dropping a Fuel drone's appearance into an arbitrary scene: in the inspected example, key motor/controller plugins are attached in the world file's `<include>`. Copying only the underlying model asset can omit those systems.

For several drones, give each model, command namespace and sensor namespace a unique name. Renaming an entity alone does not update hard-coded plugin topics. Validate one aircraft before attempting multi-vehicle operation.

## 10. Add PX4 for autopilot and Pixhawk-related work

The Gazebo reference controller is useful for learning commands and building a test scene. It uses simulator ground truth for control. It does not validate PX4's estimator, arming checks, flight modes, failsafes or Pixhawk firmware behavior.

For the team's Pixhawk direction, add a maintained PX4 SITL workflow after the basic lab succeeds. A maintainer should:

1. Select and pin a PX4 release and its compatible Gazebo setup. PX4 v1.17.0 is one inspected release with an Ubuntu 24.04 setup script.
2. Build and test its toolchain in an appropriate image or clean supported Ubuntu environment. Do not blindly layer another Gazebo installation over ROS vendor packages in the current image.
3. Confirm the basic supported X500 target works before changing the aircraft or environment.
4. Verify arming, takeoff, hold and landing with QGroundControl or PX4's supported interfaces.
5. Add the custom world while retaining PX4-compatible model systems.
6. Add ROS control interfaces with matching `px4_msgs`/middleware versions and test their time/frame conventions.
7. Commit the complete image/launch instructions and a repeatable smoke test.

**After PX4 and its dependencies have been installed**, the official entry point is:

```bash
cd /path/to/PX4-Autopilot
make px4_sitl gz_x500
```

A supported alternative environment can be selected, for example:

```bash
PX4_GZ_WORLD=windy make px4_sitl gz_x500
```

These are PX4 commands, not commands that currently work from the club repository by itself. For custom worlds, follow the selected PX4 release's resource-path and startup instructions. Do not start an unrelated Gazebo server alongside PX4's default startup and accidentally create two simulation servers.

## 11. Record results and make tests repeatable

Once the starter sensor bridge works, record a small ROS bag in another container terminal:

```bash
mkdir -p /workspace/artifacts
ros2 bag record --use-sim-time \
  -o /workspace/artifacts/lab_session_001 \
  /clock /purc/imu /purc/lidar/points /purc/camera/image
```

Stop with Ctrl+C, then inspect:

```bash
ros2 bag info /workspace/artifacts/lab_session_001
```

Use a new output directory each time. The four topics are for the supplied starter sensor rig, not the upstream X3 or PX4 model. For later SLAM recordings, include `/tf`, `/tf_static`, calibration and appropriate ground-truth topics too. Coordinate replay carefully: do not publish competing live and replay clocks into the same ROS system.

For every experiment record: Git commit, world and model versions, image identity, platform/GPU, hypothesis, command, duration in simulation time, expected outcome, actual outcome and logs/bag location. A screenshot alone does not prove that a controller or sensor worked.

### Suggested first acceptance tests

| Test | Action | Observable pass condition |
|---|---|---|
| Setup | Build image and open empty world | Image builds; window opens; simulation time advances. |
| Import | Spawn local cube | Model appears at the requested position. |
| Physics | Drop cube from 3 m | It falls and rests on the floor rather than passing through it. |
| Environment | Add and save an obstacle | It reappears after a fresh launch from the saved SDF. |
| Sensors | Run starter lab | Nonempty camera, lidar and IMU messages exist in Gazebo. |
| Bridge | Start configured bridge | Expected typed messages and clock arrive in ROS. |
| Scene response | Move the wall, then restart | Images and lidar geometry change consistently with the wall's new position. |
| Flight demo | Command climb, then zero velocity | Aircraft climbs, then approximately stops climbing while remaining upright. Record altitude over a chosen interval. |
| Custom scene | Add obstacles to working flight world | Existing control still works; objects appear with suitable collisions. |
| Recording | Save and inspect a short bag | Relevant topics have messages and useful timestamps. |
| PX4, later | Take off, hold, land in SITL | Correct mode/state transitions and logged behavior in the selected PX4 setup. |

Only call the setup member-ready after at least one local machine has passed these tests. Record platform-specific results instead of extrapolating a Linux success to every laptop.

## 12. Common failures and the next thing to check

| Symptom | Likely cause or next check |
|---|---|
| Clone command fails near `<` or `>` | Remove the angle brackets; use the corrected clone command. |
| `docker-compose` not found | Use `docker compose`; or the direct build command above. |
| NVIDIA device-driver reservation error | Compose startup requests NVIDIA unconditionally. Use the launcher without `GPU=1`, or configure GPU passthrough. |
| Launcher image not found | Build the explicit `purc-drone-sim` tag and set `IMAGE=purc-drone-sim`. |
| `xhost` not found | Install `x11-xserver-utils` on the Ubuntu host/WSL distribution. |
| No display or window | Check host/WSLg/VM display, X11 socket and authorization before debugging the world. |
| Ogre/OpenGL error or black window | Check graphics driver/backend and logs. `LIBGL_ALWAYS_SOFTWARE=1 gz sim ...` can diagnose acceleration problems, with lower performance. |
| Simple world works, sensors fail | Check Sensors/Imu systems, rendering backend, active simulation and sensor topics. |
| `model://...` cannot be found | Add the parent models directory to `GZ_SIM_RESOURCE_PATH` before launching the server; retain meshes/materials. |
| Creation command waits or times out | Check the world name, running server and UserCommands system. |
| Model visible but passes through things | Inspect collision geometry, not only visual geometry. |
| Drone falls immediately | Check gravity, mass/inertia, motor forces, controller state, command topic and plugins. |
| Gazebo has sensors but ROS does not | Check bridge process, topic names, message types, direction and QoS. |
| ROS point cloud exists but RViz is empty | Check Fixed Frame/TF, PointCloud2 topic, QoS, timestamps and point size. |
| SLAM reports missing data despite a point cloud | Check required custom message, per-point time/ring fields, IMU synchronization and transforms. |
| Work disappears after exit | Keep code/assets/results under `/workspace`; bake dependencies into the image; persist external caches intentionally. |

For a physics-only server test without GUI forwarding, run from the host:

```bash
docker run --rm -it \
  -v "$PWD:/workspace" -w /workspace purc-drone-sim \
  bash -lc 'source /opt/ros/jazzy/setup.bash; gz sim -s -r -v 4 empty.sdf'
```

This intentionally bypasses the GUI launcher. A camera or GPU lidar can still require EGL/OpenGL and an appropriate device/backend in server-only operation. Server-only mode is not proof that rendering sensors can work without graphics configuration.

## 13. Organize the first member session

1. **Before the meeting:** one lead proves image build and GUI on the platforms the club will support. Resolve graphics issues before assigning autonomy work.
2. **First 15 minutes:** every member launches the empty world and learns which terminal is the host and which is the container.
3. **Next 20 minutes:** spawn the cube, inspect gravity/collisions, import one Fuel object, save and reload the scene.
4. **Next 20 minutes:** start the supplied sensor rig and bridge; inspect an image, point cloud and IMU message.
5. **Final 20 minutes:** use the reference flight world; command a slow climb, hover request and forward movement. Add one obstacle while preserving the working drone configuration.
6. **Afterward:** each member submits a small branch with its world/config, a short result note and evidence. Separate environment, sensor, flight-control and SLAM integration tasks.

For the repository itself, the next useful additions are a documented reference world, a working drone configuration, repeatable resource paths, sensor/TF bridge configuration, a CPU-friendly setup path, a pinned optional GPU image, platform acceptance results and a headless simulation smoke test in CI. Build success alone should not be called a simulation test.

## Sources and review evidence

- Current repository files: https://github.com/Drone-Autonomous-Sim/drone-sim-core/tree/f8c59109facb41db7f5285e34bcaa37c8a6e17e6
- Latest reviewed successful build: https://github.com/Drone-Autonomous-Sim/drone-sim-core/actions/runs/36280023306
- ROS/Gazebo pairing: https://gazebosim.org/docs/harmonic/ros_installation/
- Fuel and local models: https://gazebosim.org/docs/harmonic/fuel_insert/
- Spawning from ROS: https://gazebosim.org/docs/harmonic/ros2_spawn_model/
- ROS bridge: https://gazebosim.org/docs/harmonic/ros2_integration/
- Sensors: https://gazebosim.org/docs/harmonic/sensors/
- Reference flight example inspected: https://github.com/gazebosim/gz-sim/blob/gz-sim8/examples/worlds/multicopter_velocity_control.sdf
- Controller behavior and limitations: https://gazebosim.org/api/sim/8/classgz_1_1sim_1_1systems_1_1MulticopterVelocityControl.html
- PX4 SITL: https://docs.px4.io/v1.17/en/sim_gazebo_gz/
- PX4 Ubuntu setup: https://docs.px4.io/v1.17/en/dev_setup/dev_env_linux_ubuntu
- WSL GUI support: https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps
- Graphics troubleshooting: https://gazebosim.org/docs/harmonic/troubleshooting/

No commits, branches, issues or pull requests were written to GitHub in this review.
