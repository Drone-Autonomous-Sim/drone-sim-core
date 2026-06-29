# Autonomous Drone Simulation Core

This repository contains the simulation infrastructure, perception network, and control kinematics for our autonomous drone project.

## Architecture

Simulation: Gazebo

Middleware: ROS2 Jazzy

Machine Learning: PyTorch, CUDA

Control/Kinematics: PX4 / Custom PID

## Repository Structure

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

## Development Workflow

Never push to main directly.

Create a feature branch: git checkout -b feature/your-feature-name

Commit your changes: git commit -m "feat: added basic camera sensor to URDF"

Push and open a Pull Request.

Require at least 1 approval to merge.
