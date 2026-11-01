#!/usr/bin/env bash
# Source this in every container terminal that launches Gazebo or spawns models.
PURC_LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PURC_LAB_ROOT
export GZ_SIM_RESOURCE_PATH="${PURC_LAB_ROOT}/models:${PURC_LAB_ROOT}/worlds${GZ_SIM_RESOURCE_PATH:+:${GZ_SIM_RESOURCE_PATH}}"
