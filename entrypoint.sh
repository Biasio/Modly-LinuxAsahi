#!/bin/bash
# =============================================================================
# entrypoint.sh — start Modly inside the container.
# =============================================================================
set -euo pipefail

readonly APP_DIR="/opt/modly"
readonly VENV_DIR="${APP_DIR}/.venv"

log()  { printf '[entrypoint] %s\n' "$*" >&2; }
die()  { log "ERROR: $*"; exit 1; }

trap 'die "abnormal exit at line $LINENO (command: $BASH_COMMAND)"' ERR

[ -d "$APP_DIR" ]  || die "application directory missing: $APP_DIR"
[ -f "${VENV_DIR}/bin/activate" ] || die "Python virtualenv not found in $VENV_DIR"


cd "$APP_DIR"
. "${VENV_DIR}/bin/activate"


if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ] \
    && [ -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]; then
    log "Wayland socket detected (${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}), enabling Ozone/Wayland"
    export ELECTRON_OZONE_PLATFORM_HINT="auto"
    export ELECTRON_EXTRA_LAUNCH_ARGS="--enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform=wayland --use-gl=egl"
elif [ -n "${WAYLAND_DISPLAY:-}" ]; then
    log "WARNING: WAYLAND_DISPLAY=${WAYLAND_DISPLAY} set but socket not found, falling back to X11/default"
fi

log "starting: npm run preview -- $*"
exec npm run preview -- "$@"
