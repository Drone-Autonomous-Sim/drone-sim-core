#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"
source /opt/ros/jazzy/setup.bash
export GZ_PARTITION="${GZ_PARTITION:-drone_mvp}"
exec "$PWD/scripts/run_exclusive.sh" controller python3 scripts/drone_control.py "$@"
