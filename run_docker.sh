#!/bin/bash
xhost +si:localuser:root

docker run -it --rm \
    --net=host \
    --gpus all \
    --env="DISPLAY=$DISPLAY" \
    --env="WAYLAND_DISPLAY=$WAYLAND_DISPLAY" \
    --env="XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir" \
    --env="XAUTHORITY=/root/.Xauthority" \
    --volume="/tmp/.X11-unix:/tmp/.X11-unix:ro" \
    --volume="/mnt/wslg:/mnt/wslg:ro" \
    --volume="$HOME/.Xauthority:/root/.Xauthority:ro" \
    --volume="$(pwd):/workspace" \
    --device=/dev/dxg \
    drone-sim-core-drone_sim bash
