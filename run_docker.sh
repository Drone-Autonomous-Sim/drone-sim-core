#!/usr/bin/env bash
# Launch the sim container with GUI forwarding on macOS (XQuartz) and WSL2 (WSLg).
set -euo pipefail

IMAGE="${IMAGE:-drone-sim-core-drone_sim}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

detect_platform() {
  if [[ -n "${SIMULATE_PLATFORM:-}" ]]; then
    echo "${SIMULATE_PLATFORM}"
    return
  fi
  case "$(uname -s)" in
    Darwin) echo macos ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null || [[ -d /mnt/wslg ]]; then
        echo wsl
      else
        echo linux
      fi
      ;;
    *) echo unknown ;;
  esac
}

ensure_macos_display() {
  if [[ -x /opt/X11/bin/xhost ]]; then
    export PATH="/opt/X11/bin:${PATH}"
  elif [[ -x /usr/X11/bin/xhost ]]; then
    export PATH="/usr/X11/bin:${PATH}"
  fi

  if ! command -v xhost >/dev/null 2>&1; then
    echo "XQuartz is required on macOS. Install it from https://www.xquartz.org/ and reopen the terminal." >&2
    exit 1
  fi

  if ! pgrep -xq Xquartz && ! pgrep -xq X11.bin; then
    open -a XQuartz
    # XQuartz needs a moment to create the display socket.
    local i
    for i in $(seq 1 30); do
      if [[ -d /tmp/.X11-unix ]]; then
        break
      fi
      sleep 0.2
    done
  fi

  # Docker Desktop on Mac reaches the host X server via TCP, not Unix sockets.
  xhost +localhost >/dev/null
}

PLATFORM="$(detect_platform)"

DOCKER_ARGS=(
  run -it --rm
  --volume="${SCRIPT_DIR}:/workspace"
  --env="QT_X11_NO_MITSHM=1"
)

case "${PLATFORM}" in
  macos)
    if [[ "${DRY_RUN:-0}" != 1 ]]; then
      ensure_macos_display
    fi
    # host.docker.internal is the Docker Desktop VM's route to XQuartz.
    # XQuartz has no usable GPU GLX for Gazebo/Qt, so force software drawing.
    DOCKER_ARGS+=(
      --env="DISPLAY=host.docker.internal:0"
      --env="XDG_RUNTIME_DIR=/tmp/runtime-root"
      --env="QT_QUICK_BACKEND=software"
      --env="QT_XCB_GL_INTEGRATION=none"
      --env="LIBGL_ALWAYS_SOFTWARE=1"
      --env="MESA_GL_VERSION_OVERRIDE=3.3"
      --env="MESA_GLSL_VERSION_OVERRIDE=330"
      --volume="/tmp/.X11-unix:/tmp/.X11-unix:ro"
    )
    if [[ -f "${HOME}/.Xauthority" ]]; then
      DOCKER_ARGS+=(
        --env="XAUTHORITY=/root/.Xauthority"
        --volume="${HOME}/.Xauthority:/root/.Xauthority:ro"
      )
    fi
    ;;
  wsl)
    if [[ "${DRY_RUN:-0}" != 1 ]]; then
      xhost +si:localuser:root >/dev/null 2>&1 || xhost +local: >/dev/null 2>&1 || true
    fi
    DOCKER_ARGS+=(
      --net=host
      --env="DISPLAY=${DISPLAY:-:0}"
      --env="WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-}"
      --env="XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir"
      --volume="/tmp/.X11-unix:/tmp/.X11-unix:ro"
    )
    if [[ -d /mnt/wslg ]]; then
      DOCKER_ARGS+=(--volume="/mnt/wslg:/mnt/wslg:ro")
    fi
    if [[ -f "${HOME}/.Xauthority" ]]; then
      DOCKER_ARGS+=(
        --env="XAUTHORITY=/root/.Xauthority"
        --volume="${HOME}/.Xauthority:/root/.Xauthority:ro"
      )
    fi
    if [[ -e /dev/dxg ]]; then
      DOCKER_ARGS+=(--device=/dev/dxg)
    fi
    if [[ "${DRY_RUN:-0}" != 1 ]] && docker info 2>/dev/null | grep -qi nvidia; then
      DOCKER_ARGS+=(--gpus all)
    fi
    ;;
  linux)
    if [[ "${DRY_RUN:-0}" != 1 ]]; then
      xhost +si:localuser:root >/dev/null 2>&1 || xhost +local:root >/dev/null 2>&1 || true
    fi
    DOCKER_ARGS+=(
      --net=host
      --env="DISPLAY=${DISPLAY:-:0}"
      --volume="/tmp/.X11-unix:/tmp/.X11-unix:ro"
    )
    if [[ -f "${HOME}/.Xauthority" ]]; then
      DOCKER_ARGS+=(
        --env="XAUTHORITY=/root/.Xauthority"
        --volume="${HOME}/.Xauthority:/root/.Xauthority:ro"
      )
    fi
    if [[ "${DRY_RUN:-0}" != 1 ]] && docker info 2>/dev/null | grep -qi nvidia; then
      DOCKER_ARGS+=(--gpus all)
    fi
    ;;
  *)
    echo "Unsupported platform: $(uname -s). Use macOS with XQuartz or WSL2/Linux." >&2
    exit 1
    ;;
esac

if [[ "${DRY_RUN:-0}" == 1 ]]; then
  printf 'docker'
  printf ' %q' "${DOCKER_ARGS[@]}" "${IMAGE}" bash
  printf '\n'
  exit 0
fi

exec docker "${DOCKER_ARGS[@]}" "${IMAGE}" bash
