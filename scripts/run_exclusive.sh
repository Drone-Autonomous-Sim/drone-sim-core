#!/usr/bin/env bash
# Keep one simulator and one controller per Gazebo transport partition.
set -eo pipefail
role="$1"
shift
runtime_dir="/run/user/$(id -u)"
if [[ ! -d "$runtime_dir" || ! -w "$runtime_dir" ]]; then
    runtime_dir="$HOME/.cache/drone-mvp"
    mkdir -p "$runtime_dir"
fi
partition_id="$(printf '%s' "${GZ_PARTITION:?GZ_PARTITION must be set}" | sha256sum)"
partition_id="${partition_id%% *}"
lock_file="$runtime_dir/drone-mvp-${role}-${partition_id}.lock"
if flock --nonblock --conflict-exit-code 73 "$lock_file" "$@"; then
    exit 0
else
    status=$?
    if [[ "$status" == 73 ]]; then
        echo "A drone $role is already running in partition '$GZ_PARTITION'." >&2
        echo "Use that session, or stop it before launching another." >&2
    fi
    exit "$status"
fi
