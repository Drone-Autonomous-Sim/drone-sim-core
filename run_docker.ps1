<#
.SYNOPSIS
    Start the PURC drone-sim container from Windows (Docker Desktop, WSL2 backend).

.DESCRIPTION
    Windows counterpart of run_docker.sh. It does not need an Ubuntu WSL distro:
    Gazebo/RViz windows are shown through WSLg, whose display sockets Docker Desktop
    exposes to containers under /run/desktop/mnt/host/wslg.

    Build the image first (from this folder):   docker build -t purc-drone-sim ./docker
    (If you used `docker compose build` instead, pass -Image drone-sim-core-drone_sim.)

    Gazebo/RViz render with Mesa software OpenGL (llvmpipe) in both modes: Docker
    Desktop's VM cannot hand the WSL DirectX (d3d12) bridge to containers, so hardware
    OpenGL is not available here. -Gpu still gives CUDA to PyTorch.

.PARAMETER Gpu
    Pass the NVIDIA GPU through (--gpus all) for CUDA/PyTorch.

.PARAMETER Image
    Image to run. Default matches the README's build command (purc-drone-sim).

.PARAMETER DryRun
    Print the docker command instead of running it.

.PARAMETER Command
    Command to run inside the container instead of an interactive bash shell.
    Put it after "--" so its own flags are not parsed by PowerShell.

.EXAMPLE
    .\run_docker.ps1
    .\run_docker.ps1 -Gpu
    .\run_docker.ps1 -Gpu -- gz sim -r empty.sdf
    .\run_docker.ps1 -DryRun
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$Gpu,
    [string]$Image = "purc-drone-sim",
    [switch]$DryRun,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Command = @("bash")
)

$ErrorActionPreference = "Stop"

$repo = $PSScriptRoot
$wslg = "/run/desktop/mnt/host/wslg"

$dockerArgs = @(
    "run", "--interactive", "--tty", "--rm",
    "--workdir=/workspace",
    "--volume=${repo}:/workspace",
    # WSLg display: X11 socket plus the Wayland/PulseAudio runtime dir
    "--volume=${wslg}/.X11-unix:/tmp/.X11-unix",
    "--volume=${wslg}:/mnt/wslg",
    "--env=DISPLAY=:0",
    "--env=WAYLAND_DISPLAY=wayland-0",
    "--env=XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir",
    "--env=PULSE_SERVER=/mnt/wslg/PulseServer",
    "--env=QT_X11_NO_MITSHM=1",
    # No GPU OpenGL inside Docker Desktop containers; make Mesa pick llvmpipe up front
    "--env=LIBGL_ALWAYS_SOFTWARE=1"
)

if ($Gpu) {
    $dockerArgs += @("--gpus", "all")
}

$dockerArgs += $Image
$dockerArgs += $Command

if ($DryRun) {
    Write-Output ("docker " + ($dockerArgs -join " "))
    exit 0
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "docker not found. Install and start Docker Desktop first."
}

& docker @dockerArgs
exit $LASTEXITCODE
