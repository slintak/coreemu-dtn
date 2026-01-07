#!/bin/sh
set -eu

SERVICES="./resources/core_services"
SCENARIOS="./resources/scenarios"

IMAGE="${IMAGE:-ghcr.io/slintak/coreemu-emane:latest}"
NAME="${NAME:-coreemu9}"

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ -d "$SERVICES" ] || die "Services directory does not exist: $SERVICES"
[ -d "$SCENARIOS" ] || die "Scenarios directory does not exist: $SCENARIOS"

# X11 access setup (best-effort; doesn't fail the script)
if command -v xhost >/dev/null 2>&1; then
  xhost +local:root >/dev/null 2>&1 || true
fi

# Build docker run args
set -- \
  -it --rm \
  --name "$NAME" \
  --network host \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_ADMIN \
  --privileged \
  -e "DISPLAY=${DISPLAY:-}" \
  -v "$SERVICES:/shared/myservices" \
  -v "$SCENARIOS:/shared/scenarios" \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw

exec docker run "$@" "$IMAGE"
