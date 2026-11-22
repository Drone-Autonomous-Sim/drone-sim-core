# Multi-arch CUDA base (~33 MB compressed on amd64; PyTorch cu128 bundles its own CUDA runtime).
# Override with --build-arg BASE_IMAGE=nvidia/cuda:12.8.2-devel-ubuntu24.04 only if compiling custom .cu kernels.
ARG BASE_IMAGE=nvidia/cuda:12.8.2-base-ubuntu24.04

# ==============================================================================
# Stage 1: sim (~5-6 GB uncompressed) — ROS 2 Jazzy, Gazebo Harmonic, Crazyflie, SLAM/3D Mapping
# Build lightweight CPU-only image via: docker build --target sim -t purc-drone-sim ./docker
# ==============================================================================
FROM ${BASE_IMAGE} AS sim

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all
ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=jazzy

# 1. Basic prerequisites & UTF-8 locale
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl gnupg2 lsb-release ca-certificates build-essential git \
    python3-pip wget software-properties-common locales \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8

# 2. Setup ROS 2 Jazzy apt repository
RUN curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
      -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
      http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/ros2.list

# 3. Core ROS 2 Jazzy, Gazebo Harmonic bridge, OpenCV, & Mesa/OpenGL (Ubuntu 24.04)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-jazzy-desktop \
    ros-jazzy-ros-gz \
    python3-colcon-common-extensions \
    python3-opencv \
    mesa-utils \
    libgl1 \
    libglx-mesa0 \
    libgl1-mesa-dri \
    && rm -rf /var/lib/apt/lists/*

# 4. Crazyflie 2.1 Stack (Crazyswarm2 binaries for real drones + kinematic sim + USB radio libs)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libboost-program-options-dev \
    libusb-1.0-0-dev \
    usbutils \
    python3-yaml \
    python3-scipy \
    python3-usb \
    ros-jazzy-crazyflie \
    ros-jazzy-crazyflie-interfaces \
    ros-jazzy-crazyflie-py \
    ros-jazzy-crazyflie-sim \
    ros-jazzy-crazyflie-examples \
    ros-jazzy-motion-capture-tracking \
    ros-jazzy-tf-transformations \
    ros-jazzy-tf2-tools \
    && rm -rf /var/lib/apt/lists/*

# 5. Autonomous Drone Middleware (LiDAR/PCL, Vision, 2D SLAM, 3D OctoMap, EKF, Cyclone DDS, Diagnostics)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpcl-dev \
    ros-jazzy-pcl-ros \
    ros-jazzy-pcl-conversions \
    ros-jazzy-cv-bridge \
    ros-jazzy-vision-msgs \
    ros-jazzy-slam-toolbox \
    ros-jazzy-octomap-server \
    ros-jazzy-octomap-rviz-plugins \
    ros-jazzy-robot-localization \
    libeigen3-dev \
    libceres-dev \
    ros-jazzy-xacro \
    ros-jazzy-teleop-twist-keyboard \
    ros-jazzy-rmw-cyclonedds-cpp \
    ros-jazzy-foxglove-bridge \
    ros-jazzy-plotjuggler-ros \
    && rm -rf /var/lib/apt/lists/*

# 6. Developer utilities & rosdep
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-rosdep \
    python3-vcstool \
    tmux \
    gdb \
    nano \
    htop \
    iputils-ping \
    && (rosdep init || true) && rosdep update \
    && rm -rf /var/lib/apt/lists/*

# 7. Crazyswarm2 needs link statistics and Ubuntu Noble's NumPy 1.x ABI.
ARG CFLIB_REV=fba61709aeb7536d5f214353ddc74fd78bf872de
RUN git init /opt/crazyflie-lib-python \
    && git -C /opt/crazyflie-lib-python remote add origin https://github.com/bitcraze/crazyflie-lib-python.git \
    && git -C /opt/crazyflie-lib-python fetch --depth 1 origin "${CFLIB_REV}" \
    && git -C /opt/crazyflie-lib-python checkout --detach FETCH_HEAD \
    && pip3 install --no-cache-dir --break-system-packages rowan transforms3d -e /opt/crazyflie-lib-python

# 8. Crazyflie 2.1 Gazebo Harmonic model + ROS 2/Gazebo bridge (verified on ROS 2 Jazzy + Harmonic)
RUN git clone --depth 1 https://github.com/bitcraze/crazyflie-simulation.git /opt/crazyflie-simulation \
    && mkdir -p /opt/cf_ws/src \
    && git clone --depth 1 https://github.com/knmcguire/ros_gz_crazyflie.git /opt/cf_ws/src/ros_gz_crazyflie \
    && bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash \
      && cd /opt/cf_ws \
      && colcon build --symlink-install"

# PX4 software-in-the-loop for Gazebo Harmonic. Inside the container run:
# make -C /opt/PX4-Autopilot px4_sitl gz_x500_depth
ARG PX4_VERSION=v1.17.0
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake ninja-build python3-venv pkg-config protobuf-compiler \
    libssl-dev libxml2-utils libgstreamer-plugins-base1.0-dev \
    && rm -rf /var/lib/apt/lists/* \
    && git clone --branch "${PX4_VERSION}" --depth 1 --recurse-submodules --shallow-submodules \
        https://github.com/PX4/PX4-Autopilot.git /opt/PX4-Autopilot \
    && python3 -m venv --system-site-packages /opt/px4-venv \
    && /opt/px4-venv/bin/pip install --no-cache-dir -r /opt/PX4-Autopilot/Tools/setup/requirements.txt \
    && bash -c 'source /opt/ros/jazzy/setup.bash && source /opt/px4-venv/bin/activate \
        && cd /opt/PX4-Autopilot \
        && GZ_DISTRO=harmonic cmake -S . -B build/px4_sitl_default -G Ninja -DCONFIG=px4_sitl_default \
        && cmake --build build/px4_sitl_default --parallel 2' \
    && test -x /opt/PX4-Autopilot/build/px4_sitl_default/bin/px4 \
    && test -s /opt/PX4-Autopilot/build/px4_sitl_default/rootfs/gz_env.sh

# 9. Runtime defaults: Cyclone DDS + non-destructive Gazebo resource path + auto-sourcing
ENV RMW_IMPLEMENTATION=rmw_cyclonedds_cpp

RUN cat <<'EOF' > /ros_entrypoint.sh
#!/usr/bin/env bash
set -e
source "/opt/ros/${ROS_DISTRO}/setup.bash"
if [ -f "/opt/cf_ws/install/setup.bash" ]; then
    source "/opt/cf_ws/install/setup.bash"
fi
if [ -f "/workspace/ros2_ws/install/setup.bash" ]; then
    source "/workspace/ros2_ws/install/setup.bash"
fi
export GZ_SIM_RESOURCE_PATH="/opt/crazyflie-simulation/simulator_files/gazebo:/workspace/sim/models:${GZ_SIM_RESOURCE_PATH:-}"
exec "$@"
EOF
RUN chmod +x /ros_entrypoint.sh

# Keep Terminal B (`docker exec -it CONTAINER_ID bash`) auto-sourced as well
RUN cat <<'EOF' >> /root/.bashrc
source /opt/ros/jazzy/setup.bash
[ -f /opt/cf_ws/install/setup.bash ] && source /opt/cf_ws/install/setup.bash
[ -f /workspace/ros2_ws/install/setup.bash ] && source /workspace/ros2_ws/install/setup.bash
export GZ_SIM_RESOURCE_PATH="/opt/crazyflie-simulation/simulator_files/gazebo:/workspace/sim/models:${GZ_SIM_RESOURCE_PATH:-}"
EOF

WORKDIR /workspace
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]

# ==============================================================================
# Stage 2: gpu (Default target — ~11-13 GB uncompressed; fits GitHub Actions CI)
# ==============================================================================
FROM sim AS gpu

ARG TARGETARCH
RUN if [ "${TARGETARCH}" = "amd64" ]; then \
        pip3 install --no-cache-dir --break-system-packages \
            torch torchvision --index-url https://download.pytorch.org/whl/cu128; \
    else \
        pip3 install --no-cache-dir --break-system-packages \
            torch torchvision; \
    fi