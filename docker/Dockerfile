FROM nvidia/cuda:12.2.2-devel-ubuntu24.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=jazzy

# Install basic prerequisites
RUN apt-get update && apt-get install -y \
    curl gnupg2 lsb-release build-essential git \
    python3-pip python3-colcon-common-extensions \
    wget software-properties-common locales \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8

# Setup ROS 2 Jazzy repository
RUN curl -sSL [https://raw.githubusercontent.com/ros/rosdistro/master/ros.key](https://raw.githubusercontent.com/ros/rosdistro/master/ros.key) -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] [http://packages.ros.org/ros2/ubuntu](http://packages.ros.org/ros2/ubuntu) $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Install ROS 2 Jazzy and Gazebo Harmonic Integration
RUN apt-get update && apt-get install -y \
    ros-jazzy-desktop \
    ros-jazzy-ros-gz \
    && rm -rf /var/lib/apt/lists/*

# Install Computer Science ML Stack
RUN pip3 install --no-cache-dir --break-system-packages torch torchvision torchaudio opencv-python numpy

# Auto-source ROS 2
RUN echo "source /opt/ros/jazzy/setup.bash" >> /root/.bashrc

WORKDIR /workspace
