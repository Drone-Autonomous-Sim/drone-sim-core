#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"
source /opt/ros/jazzy/setup.bash
export GZ_PARTITION="${GZ_PARTITION:-drone_mvp}"
exec python3 scripts/drone_control.py "$@"
