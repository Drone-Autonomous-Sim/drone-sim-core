#!/usr/bin/env bash

set -Eeuo pipefail

IMAGE="${IMAGE:-drone-sim-core-drone_sim}"
GPU="${GPU:-0}"
DRY_RUN="${DRY_RUN:-0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM=""
AUTHORIZED_X11=0

die() {
    echo "run_docker.sh: $*" >&2
    exit 1
}

warn() {
    echo "run_docker.sh: warning: $*" >&2
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

is_dry_run() {
    [[ "${DRY_RUN}" == "1" ]]
}

detect_platform() {
    if [[ -n "${SIMULATE_PLATFORM:-}" ]]; then
        printf '%s\n' "${SIMULATE_PLATFORM}"
        return
    fi

    case "$(uname -s)" in
        Darwin) printf '%s\n' "macos" ;;
        Linux)
            if grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease 2>/dev/null || \
                grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
                printf '%s\n' "wsl"
            else
                printf '%s\n' "linux"
            fi
            ;;
        *) printf '%s\n' "unknown" ;;
    esac
}

add_xauthority_if_present() {
    if [[ -f "${HOME}/.Xauthority" ]]; then
        DOCKER_ARGS+=(--env="XAUTHORITY=/root/.Xauthority")
        DOCKER_ARGS+=(--volume="${HOME}/.Xauthority:/root/.Xauthority:ro")
    fi
}

cleanup_x11_authorization() {
    if [[ ${AUTHORIZED_X11} -ne 1 ]]; then
        return
    fi

    case "${PLATFORM}" in
        macos)
            xhost -localhost >/dev/null 2>&1 || true
            xhost -127.0.0.1 >/dev/null 2>&1 || true
            ;;
        linux|wsl)
            xhost -si:localuser:root >/dev/null 2>&1 || true
            xhost -local:root >/dev/null 2>&1 || true
            ;;
    esac
}

trap cleanup_x11_authorization EXIT

allow_x11_linux_like() {
    if is_dry_run; then
        return
    fi

    require_command xhost

    xhost +si:localuser:root >/dev/null 2>&1 || \
        xhost +local:root >/dev/null 2>&1 || \
        die "failed to authorize local X11 access for the container"
    AUTHORIZED_X11=1
}

allow_x11_macos() {
    if is_dry_run; then
        return
    fi

    if [[ -x /opt/X11/bin/xhost ]]; then
        export PATH="/opt/X11/bin:${PATH}"
    elif [[ -x /usr/X11/bin/xhost ]]; then
        export PATH="/usr/X11/bin:${PATH}"
    fi

    require_command xhost
    require_command open
    require_command pgrep

    if ! pgrep -xq Xquartz && ! pgrep -xq X11.bin; then
        open -a XQuartz >/dev/null 2>&1 || die "failed to start XQuartz"
    fi

    local attempt
    for attempt in {1..50}; do
        if pgrep -xq Xquartz || pgrep -xq X11.bin; then
            break
        fi
        sleep 0.2
    done

    pgrep -xq Xquartz || pgrep -xq X11.bin || die "XQuartz is not running"

    xhost +localhost >/dev/null 2>&1 || die "failed to authorize localhost in XQuartz"
    xhost +127.0.0.1 >/dev/null 2>&1 || true
    AUTHORIZED_X11=1
}

add_gpu_args() {
    [[ "${GPU}" == "1" ]] || return 0

    case "${PLATFORM}" in
        linux|wsl)
            DOCKER_ARGS+=(--gpus all)
            ;;
        macos)
            warn "GPU=1 is not supported on macOS Docker Desktop; continuing without GPU passthrough"
            ;;
        *)
            die "GPU=1 is unsupported for platform '${PLATFORM}'"
            ;;
    esac
}

PLATFORM="$(detect_platform)"

if ! is_dry_run; then
    require_command docker
fi

DOCKER_ARGS=(
    run
    --interactive
    --tty
    --rm
    --workdir=/workspace
    --volume="${SCRIPT_DIR}:/workspace"
    --env=QT_X11_NO_MITSHM=1
)

case "${PLATFORM}" in
    macos)
        allow_x11_macos
        DOCKER_ARGS+=(
            --env="DISPLAY=${DISPLAY:-host.docker.internal:0}"
            --env=QT_QUICK_BACKEND=software
            --env=QT_XCB_GL_INTEGRATION=none
            --env=LIBGL_ALWAYS_SOFTWARE=1
            --env=MESA_GL_VERSION_OVERRIDE=3.3
            --env=MESA_GLSL_VERSION_OVERRIDE=330
        )
        ;;
    wsl)
        DOCKER_ARGS+=(--net=host)

        if [[ -n "${DISPLAY:-}" ]] || is_dry_run; then
            DOCKER_ARGS+=(--env="DISPLAY=${DISPLAY:-:0}")
            if [[ -d /tmp/.X11-unix ]] || is_dry_run; then
                DOCKER_ARGS+=(--volume="/tmp/.X11-unix:/tmp/.X11-unix:ro")
                allow_x11_linux_like
            elif ! is_dry_run; then
                die "DISPLAY is set but /tmp/.X11-unix is missing"
            fi
        fi

        if ([[ -d /mnt/wslg ]] || is_dry_run) && \
            [[ -n "${WAYLAND_DISPLAY:-}" && -n "${XDG_RUNTIME_DIR:-}" ]] && \
            ([[ -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]] || is_dry_run); then
            DOCKER_ARGS+=(--env="WAYLAND_DISPLAY=${WAYLAND_DISPLAY}")
            DOCKER_ARGS+=(--env="XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}")
            DOCKER_ARGS+=(--volume="${XDG_RUNTIME_DIR}:${XDG_RUNTIME_DIR}:rw")
        fi

        if [[ -d /mnt/wslg ]]; then
            DOCKER_ARGS+=(--volume="/mnt/wslg:/mnt/wslg:ro")
        fi

        if [[ -e /dev/dxg ]]; then
            DOCKER_ARGS+=(--device=/dev/dxg)
        fi

        add_xauthority_if_present

        if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]] && ! is_dry_run; then
            die "no GUI protocol detected (set DISPLAY or WAYLAND_DISPLAY in WSL2)"
        fi
        ;;
    linux)
        local_gui_count=0

        if [[ -n "${DISPLAY:-}" ]]; then
            if [[ -d /tmp/.X11-unix ]]; then
                DOCKER_ARGS+=(--env="DISPLAY=${DISPLAY}")
                DOCKER_ARGS+=(--volume="/tmp/.X11-unix:/tmp/.X11-unix:ro")
                allow_x11_linux_like
                local_gui_count=$((local_gui_count + 1))
            elif ! is_dry_run; then
                die "DISPLAY is set but /tmp/.X11-unix is missing"
            fi
        fi

        if [[ -n "${WAYLAND_DISPLAY:-}" && -n "${XDG_RUNTIME_DIR:-}" ]]; then
            WAYLAND_SOCKET="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"
            if [[ -S "${WAYLAND_SOCKET}" ]] || is_dry_run; then
                DOCKER_ARGS+=(--env="WAYLAND_DISPLAY=${WAYLAND_DISPLAY}")
                DOCKER_ARGS+=(--env="XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}")
                DOCKER_ARGS+=(--volume="${XDG_RUNTIME_DIR}:${XDG_RUNTIME_DIR}:rw")
                local_gui_count=$((local_gui_count + 1))
            elif ! is_dry_run; then
                die "WAYLAND_DISPLAY is set but socket is missing: ${WAYLAND_SOCKET}"
            fi
        fi

        if [[ ${local_gui_count} -eq 0 ]] && ! is_dry_run; then
            die "neither usable X11 nor Wayland GUI forwarding is available"
        fi

        add_xauthority_if_present
        ;;
    *)
        die "unsupported platform '${PLATFORM}'"
        ;;
esac

add_gpu_args

if is_dry_run; then
    printf 'docker'
    printf ' %q' "${DOCKER_ARGS[@]}" "${IMAGE}" bash
    printf '\n'
    exit 0
fi

docker "${DOCKER_ARGS[@]}" "${IMAGE}" bash
