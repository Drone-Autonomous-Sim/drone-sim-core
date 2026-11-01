#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"
if [[ ! -f /opt/ros/jazzy/setup.bash ]]; then
    echo 'Install ROS 2 Jazzy and ros-jazzy-ros-gz on Ubuntu 24.04 first.' >&2
    exit 1
fi
source /opt/ros/jazzy/setup.bash
export GZ_PARTITION="${GZ_PARTITION:-drone_mvp}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
# Software rendering is the portable default for Apple Silicon Linux VMs.
# Set LIBGL_ALWAYS_SOFTWARE=0 to try an accelerated Linux GPU.
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"
# A GUI-only client may attach to an existing server without taking its lock.
for arg in "$@"; do
    if [[ "$arg" == -g || "$arg" == --gui-only ]]; then
        exec gz sim -r "$PWD/sim/drone.sdf" "$@"
    fi
done
exec "$PWD/scripts/run_exclusive.sh" simulator gz sim -r "$PWD/sim/drone.sdf" "$@"
