#!/bin/bash
# =============================================================================
# run.sh — build (if needed) and launch the Modly container on Podman.
# =============================================================================
set -euo pipefail

readonly IMAGE_NAME="modly:latest"
readonly CONTAINER_NAME="modly"

log()  { printf '[run] %s\n' "$*" >&2; }
die()  { log "ERROR: $*"; exit 1; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}


cleanup() {
    xhost -si:localuser:"$USER" >/dev/null 2>&1 || true
}


require_cmd podman
require_cmd getent
require_cmd xhost

[ -n "${DISPLAY:-}" ] || die "DISPLAY variable not set: no X server available"

if ! podman image exists "$IMAGE_NAME"; then
    log "image '$IMAGE_NAME' absent, starting build"
    podman build -t "$IMAGE_NAME" . || die "image build failed"
fi

XAUTH_MOUNT=()
if [ -n "${XAUTHORITY:-}" ] && [ -f "${XAUTHORITY}" ]; then
    XAUTH_MOUNT=(-v "${XAUTHORITY}:/home/node/.Xauthority:ro")
elif [ -f "${HOME}/.Xauthority" ]; then
    XAUTH_MOUNT=(-v "${HOME}/.Xauthority:/home/node/.Xauthority:ro")
else
    log "WARNING: no .Xauthority file found, X11 authentication may fail"
fi

[ -f "env.conf" ] || die "file 'env.conf' not found in current directory (required by --env-file)"

SHARED_DIR="${HOME}/.local/share/modly/shared-volume"
mkdir -p "$SHARED_DIR" || die "unable to create shared directory: $SHARED_DIR"


WAYLAND_MOUNT=()
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -n "${WAYLAND_DISPLAY:-}" ] \
    && [ -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]; then
    WAYLAND_MOUNT=(-v "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}:${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}:rw")
else
    log "Wayland session not detected, proceeding without the related mount"
fi


trap cleanup EXIT

xhost +si:localuser:"$USER"

podman run --rm -it \
    --name "$CONTAINER_NAME" \
    --ipc=host \
    --userns=keep-id \
    --group-add keep-groups \
    --device /dev/dri:/dev/dri:rw \
    -v modly_user_data:/home/node \
    --env-file env.conf \
    -e DISPLAY="$DISPLAY" \
    -e XCURSOR_SIZE="${XCURSOR_SIZE:-}" \
    -e WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
    -e XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" \
    -e XDG_CONFIG_HOME="/home/node/.config" \
    -e XDG_DATA_HOME="/home/node/.local/share" \
    -e XDG_CACHE_HOME="/home/node/.cache" \
    -e HF_HOME="/home/node/.cache/huggingface" \
    -v "${SHARED_DIR}:/home/node/shared-volume:rw" \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    "${WAYLAND_MOUNT[@]}" \
    "${XAUTH_MOUNT[@]}" \
    -v /sys/class/drm:/sys/class/drm:ro \
    -v /sys/devices/platform/soc:/sys/devices/platform/soc:ro \
    --security-opt label=type:container_runtime_t \
    "$IMAGE_NAME"

