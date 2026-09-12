# PURC Autonomous Drone Team: Simulation Core

Welcome to the simulation repository for the Princeton University Robotics Club (PURC) Autonomous Drone Team.

This repository contains our Dockerized simulation environment. To ensure seamless collaboration across our team, this container provides a unified, pre-configured ROS 2 and Gazebo workspace that operates identically across Windows, macOS, and Linux distributions.

This virtual testbed allows us to safely develop, compile, and validate our 3D SLAM algorithms, computer vision models, and flight control logic before deploying to our physical hardware stack (NVIDIA Jetson Orin Nano, Livox Mid-360 LiDAR, Luxonis OAK-D Lite, and Pixhawk 6X).

---

## Getting Started (Pre-Meeting Setup)

To participate in our hands-on onboarding sessions, please complete these prerequisites on your personal machine before the meeting:

### 1. System Prerequisites
*   **Windows Users:** Install [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) and [Docker Desktop](https://www.docker.com/products/docker-desktop/). Ensure Docker is configured to use the WSL2 backend in the settings.
*   **macOS Users:** Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and [XQuartz](https://www.xquartz.org/) (required for forwarding GUI applications like Gazebo and RViz to your Mac display).
*   **Linux Users:** Install [Docker Engine](https://docs.docker.com/engine/install/) and the Docker Compose plugin natively via your package manager.

### 2. Initialization
Once Docker is running on your machine, open your terminal and run the following commands to initialize the workspace:

```bash
# Clone the repository
git clone <YOUR-REPOSITORY-URL-HERE>
cd drone-sim-core-main

# Grant execution permissions to the script
chmod +x run_docker.sh

# Execute the build and run script
./run_docker.sh
```
> **Note:** The initial build will take several minutes as it downloads the ROS 2 base image and compiles our required dependencies.

---

## 📂 Repository Structure

```
├── .gitignore
├── README.md
├── docker/                 # Dockerfile and docker-compose configurations
├── src/                    # ROS2 Workspace
│   ├── drone_control/      # ECE: Flight dynamics, PID, navigation
│   ├── drone_perception/   # CS: Neural net integration, CUDA kernels
│   └── drone_description/  # ECE: URDF models and simulated sensors
└── models/                 # AI model weights (.pt, .onnx)
```
> **Note:** The current structure is missing some of these directories; they will be added later.
---

## 🛠️ Subteam Focus Areas

As we scale the project, development within this simulation environment will be divided into the following domains:

- **Autonomy & SLAM (ROS 2 / C++):** Testing Fast-LIO / Point-LIO pipelines, occupancy voxel grids, and 3D path planning algorithms in Gazebo.
- **Perception & ML (PyTorch / Python):** Validating object detection models, semantic segmentation, and simulated camera feeds.
- **Embedded Systems (PX4 / MAVLink):** Tuning PID parameters, testing failsafe logic, and simulating telemetry feedback loops.

---

## 🤝 Contribution Guidelines

With a team of over 20 members, we adhere to strict version control standards to prevent merge conflicts and broken builds.

### 1. Branching Strategy

- **`main`:** The stable branch. Code here must successfully build and pass all simulation tests. Do not push directly to `main`.
- **Feature Branches:** Create a new branch for every task or feature. Use the naming convention `subteam/feature-name` (e.g., `slam/fast-lio-integration` or `perception/yolo-model-update`).

### 2. Workflow

1. Pull the latest changes from `main`:

   ```bash
   git pull origin main
   ```

2. Create your feature branch:

   ```bash
   git checkout -b your-branch-name
   ```

3. Write and test your code inside the Docker container.

4. Commit your changes with descriptive messages:

   ```bash
   git commit -m "Added voxel grid mapping node"
   ```

5. Push your branch:

   ```bash
   git push origin your-branch-name
   ```

6. Open a Pull Request (PR) on GitHub and request a review from a subteam lead.

---

## ⚙️ Troubleshooting & FAQs

If you encounter errors during the initial setup phase, try these common fixes before reaching out to a team lead:

- **GUI Not Opening / X11 Errors:** If Gazebo or RViz fails to launch with a `cannot open display` error, ensure your local X server (e.g., XQuartz or VcXsrv) is running in the background and is explicitly configured to allow local network connections.

- **Permission Denied on Script:** If `./run_docker.sh` fails to execute, ensure you ran the `chmod +x run_docker.sh` command listed in the initialization steps.

- **Volume Mount Issues:** Verify that the source directory paths defined inside the `docker-compose.yml` configuration correctly map to your local operating system's directory structure.

- **Stale Cache / Build Failures:** If package dependencies fail during the build step, force a clean rebuild by running:

   ```bash
   docker-compose build --no-cache
   ```