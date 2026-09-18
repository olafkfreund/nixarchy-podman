#!/usr/bin/env bash
# Stages throwaway Podman objects for the showcase captures in docs/img, and
# removes them again. Run it on the desktop the captures are taken on.
#
#   docs/capture.sh --setup      create the demo objects (refuses if any exist)
#   docs/capture.sh --unhealthy  make demo-unhealthy report unhealthy now
#   docs/capture.sh --teardown   remove exactly what --setup created
#   docs/capture.sh --shot NAME X,Y WxH
#                                 crop one still into docs/img/NAME.png
#
# The owner's containers, images, volumes and networks are never touched:
# --setup refuses to run if any name it would use already exists, records
# every object it creates, and --teardown removes only what that record
# lists. Demo images are built (not tagged), so each has its own id and a
# single tag -- tagging a shared image would show duplicate rows (issue #6).
#
# Surfaces are opened with the shell's IPC, and a shot is taken only once the
# surface's layer is up (hyprctl layers), as nixarchy's capture script does.
# Key-driven states and the recordings need key input; AGENTS.md describes
# that part.
set -euo pipefail

img_dir="$(cd "$(dirname "$0")" && pwd)/img"
project=demo-shop
tag_app=localhost/demo/shop:latest
tag_tool=localhost/demo/tools:latest
containers=(demo-shop-web demo-shop-db demo-shop-migrate demo-unhealthy)
volumes=(demo-cache demo-empty)
network=demo-net
# One line per created object, "kind name", read back by --teardown.
state="${XDG_RUNTIME_DIR:-/tmp}/nixarchy-podman-capture.state"

made() { echo "$1 $2" >>"$state"; }

refuse_collisions() {
  local c v clash=0
  for c in "${containers[@]}"; do
    if podman container exists "$c"; then echo "exists: container $c" >&2; clash=1; fi
  done
  for v in "${volumes[@]}"; do
    if podman volume exists "$v"; then echo "exists: volume $v" >&2; clash=1; fi
  done
  if podman network exists "$network"; then echo "exists: network $network" >&2; clash=1; fi
  for t in "$tag_app" "$tag_tool"; do
    if podman image exists "$t"; then echo "exists: image $t" >&2; clash=1; fi
  done
  if [ -s "$state" ]; then echo "exists: $state (run --teardown first)" >&2; clash=1; fi
  if [ "$clash" -ne 0 ]; then
    echo "refusing: these names belong to something that is not this script's" >&2
    exit 1
  fi
}

build_demo() { # build_demo <base> <tag>: a new image of its own, one tag
  local base=$1 tag=$2
  if ! podman image exists "$base"; then
    podman pull -q "$base" >/dev/null
    made base "$base"
  fi
  printf 'FROM %s\nLABEL io.nixarchy.podman.demo=true\n' "$base" |
    podman build -q -t "$tag" -f - >/dev/null
  made image "$tag"
}

setup() {
  refuse_collisions
  : >"$state"
  build_demo docker.io/library/alpine:3 "$tag_app"
  build_demo docker.io/library/busybox:latest "$tag_tool"   # unused on purpose

  podman network create "$network" >/dev/null && made network "$network"
  for v in "${volumes[@]}"; do podman volume create "$v" >/dev/null && made volume "$v"; done
  # Give the cache something to measure.
  podman run --rm -v demo-cache:/data "$tag_app" \
    sh -c 'head -c 24000000 /dev/urandom > /data/blob'

  local label="com.docker.compose.project=$project"
  podman run -d --name demo-shop-web --label "$label" --network "$network" \
    -v demo-cache:/cache "$tag_app" sleep infinity >/dev/null && made container demo-shop-web
  podman run -d --name demo-shop-db --label "$label" --network "$network" \
    "$tag_app" sleep infinity >/dev/null && made container demo-shop-db
  # A one-off job that failed, for the "Exited (1)" row.
  podman run --name demo-shop-migrate --label "$label" "$tag_app" \
    sh -c 'echo "migration 0042 failed: column already exists" >&2; exit 1' || true
  made container demo-shop-migrate
  # A health check that always fails, for the red glyph.
  podman run -d --name demo-unhealthy --health-cmd false \
    --health-interval 1h --health-retries 1 "$tag_app" sleep infinity >/dev/null &&
    made container demo-unhealthy
}

unhealthy() {
  # Rootless health checks run on a timer; run one now instead of waiting.
  podman healthcheck run demo-unhealthy >/dev/null 2>&1 || true
  podman inspect -f '{{.State.Health.Status}}' demo-unhealthy
}

teardown() {
  [ -f "$state" ] || { echo "nothing recorded; nothing to remove"; return; }
  local kind name
  # Order matters: containers, then what they use, then images, then bases.
  for want in container network volume image base; do
    while read -r kind name; do
      [ "$kind" = "$want" ] || continue
      case $kind in
        container) podman rm -f -t 0 "$name" >/dev/null 2>&1 || true ;;
        network) podman network rm "$name" >/dev/null 2>&1 || true ;;
        volume) podman volume rm "$name" >/dev/null 2>&1 || true ;;
        image|base) podman rmi "$name" >/dev/null 2>&1 || true ;;
      esac
    done <"$state"
  done
  rm -f "$state"
}

shot() {
  local name=$1 pos=$2 size=$3
  mkdir -p "$img_dir"
  grim -g "$pos $size" "$img_dir/$name.png"
  echo "  $name.png ($size at $pos)"
}

case "${1:-}" in
  --setup) setup ;;
  --unhealthy) unhealthy ;;
  --teardown) teardown ;;
  --shot) shift; shot "$@" ;;
  *) sed -n '2,10p' "$0" >&2; exit 2 ;;
esac
