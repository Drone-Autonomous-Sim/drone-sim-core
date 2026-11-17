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

.PARAMETER NoAutoStart
    Do not start or repair Docker Desktop; fail immediately if the engine is down.

.NOTES
    If the Docker engine is not reachable, the script starts Docker Desktop and waits.
    When Docker Desktop has crashed on "listening on unix://...dockerInference: The file
    cannot be accessed by the system" (stale socket files left by an unclean shutdown),
    it first moves %LOCALAPPDATA%\Docker\run and %LOCALAPPDATA%\docker-secrets-engine
    aside (renamed with a timestamp, nothing deleted) and clears the *.lock files.

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
    [switch]$NoAutoStart,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Command = @("bash")
)

$ErrorActionPreference = "Stop"

function Test-DockerEngine {
    # Probe via cmd so docker's stderr never becomes a PowerShell error under
    # $ErrorActionPreference = "Stop" (Windows PowerShell 5.1 wraps native stderr).
    $v = & cmd /c 'docker version --format "{{.Server.Version}}" 2>nul'
    return ($LASTEXITCODE -eq 0 -and $v)
}

function Wait-DockerEngine([int]$Seconds) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-DockerEngine) { return $true }
        Start-Sleep -Seconds 3
    }
    return Test-DockerEngine
}

function Get-DockerDesktopExe {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\DockerDesktop\Docker Desktop.exe"),
        (Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe")
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}

function Repair-DockerDesktop {
    # Stop whatever is left of a crashed Docker Desktop, then move the folders that
    # hold its stale AF_UNIX socket files out of the way so it can recreate them.
    $names = @("Docker Desktop", "com.docker.backend", "com.docker.build",
               "com.docker.dev-envs", "docker-secrets-engine")
    Get-Process -Name $names -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    # A leftover docker-desktop VM from the crashed instance keeps the new one from
    # attaching; Docker Desktop recreates it on start.
    & cmd /c 'wsl.exe --terminate docker-desktop 2>nul' | Out-Null
    Start-Sleep -Seconds 3

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $folders = @(
        (Join-Path $env:LOCALAPPDATA "Docker\run"),
        (Join-Path $env:LOCALAPPDATA "docker-secrets-engine")
    )
    foreach ($d in $folders) {
        # \\?\ prefix: these socket files are unreadable to normal Win32 calls
        if (Test-Path "\\?\$d") {
            [System.IO.Directory]::Move("\\?\$d", "\\?\$d.stale-$stamp")
            Write-Host "run_docker: moved $d -> $d.stale-$stamp"
        }
    }
    Get-ChildItem (Join-Path $env:LOCALAPPDATA "Docker") -Filter "*.lock" -ErrorAction SilentlyContinue |
        ForEach-Object { [System.IO.File]::Delete("\\?\" + $_.FullName) }
}

function Start-DockerDesktopAndWait {
    $exe = Get-DockerDesktopExe
    if (-not $exe) { throw "Docker engine is down and Docker Desktop.exe was not found. Start it by hand." }
    Write-Host "run_docker: starting Docker Desktop, waiting for the engine (up to 3 min)..."
    Start-Process $exe
    return (Wait-DockerEngine 180)
}

function Ensure-DockerEngine {
    if (Test-DockerEngine) { return }
    if ($NoAutoStart) { throw "Docker engine is not running (use Docker Desktop to start it)." }

    $running = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
    if ($running) {
        # Probably still starting; give it a chance before assuming it crashed.
        Write-Host "run_docker: Docker Desktop is running but the engine is not up yet, waiting..."
        if (Wait-DockerEngine 60) { return }
        Write-Host "run_docker: engine still down; assuming a crash, cleaning stale socket files."
    }

    Repair-DockerDesktop
    if (-not (Start-DockerDesktopAndWait)) {
        throw "Docker engine did not come up. Open Docker Desktop and read its error dialog."
    }
}

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
    throw "docker not found. Install Docker Desktop first."
}

Ensure-DockerEngine

& docker @dockerArgs
exit $LASTEXITCODE
