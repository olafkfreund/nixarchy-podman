#!/usr/bin/env bash
# Stages throwaway Podman objects for the showcase captures in docs/img, and
# removes them again. Run it on the desktop the captures are taken on.
#
#   docs/capture.sh --setup      create the demo-* objects
#   docs/capture.sh --unhealthy  make demo-unhealthy report unhealthy now
#   docs/capture.sh --teardown   remove every demo-* object (safe to repeat)
#   docs/capture.sh --shot NAME X,Y WxH
#                                 crop one still into docs/img/NAME.png
#
# Everything it creates is named demo-* or tagged localhost/demo/*, and
# --teardown touches nothing else, so the owner's containers, images, volumes
# and networks are never changed. The shots use the plugin's filter set to
# "demo", so the owner's own items stay off screen.
#
# Surfaces are opened with the shell's IPC, and a shot is taken only once the
# surface's layer is up (hyprctl layers), as nixarchy's capture script does.
# Key-driven states (a filter typed, a question asked) and the recordings need
# key input; AGENTS.md describes that part.
set -euo pipefail

img_dir="$(cd "$(dirname "$0")" && pwd)/img"
project=demo-shop
tag_app=localhost/demo/shop:latest
tag_tool=localhost/demo/tools:latest
# Base images setup had to pull, so teardown removes those and never one the
# owner already had.
pulled="${XDG_RUNTIME_DIR:-/tmp}/nixarchy-podman-capture.pulled"

setup() {
  : >"$pulled"
  for base in docker.io/library/alpine:3 docker.io/library/busybox:latest; do
    if ! podman image exists "$base"; then
      podman pull -q "$base" >/dev/null
      echo "$base" >>"$pulled"
    fi
  done
  podman tag docker.io/library/alpine:3 "$tag_app"
  podman tag docker.io/library/busybox:latest "$tag_tool"   # unused on purpose
  # One tag per demo image: an image carrying two tags trips issue #6
  # (duplicate rows). Only a base image this script pulled is untagged --
  # never one the owner already had.
  while read -r base; do podman untag "$base" "$base" >/dev/null; done <"$pulled"   # IMAGE NAME: only that name

  podman network create demo-net >/dev/null
  podman volume create demo-cache >/dev/null
  podman volume create demo-empty >/dev/null                 # unused on purpose
  # Give the cache something to measure.
  podman run --rm -v demo-cache:/data "$tag_app" \
    sh -c 'head -c 24000000 /dev/urandom > /data/blob'

  local label="com.docker.compose.project=$project"
  podman run -d --name demo-shop-web --label "$label" --network demo-net \
    -v demo-cache:/cache "$tag_app" sleep infinity >/dev/null
  podman run -d --name demo-shop-db --label "$label" --network demo-net \
    "$tag_app" sleep infinity >/dev/null
  # A one-off job that failed, for the "Exited (1)" row.
  podman run --name demo-shop-migrate --label "$label" "$tag_app" \
    sh -c 'echo "migration 0042 failed: column already exists" >&2; exit 1' || true
  # A health check that always fails, for the red glyph.
  podman run -d --name demo-unhealthy --health-cmd false \
    --health-interval 1h --health-retries 1 "$tag_app" sleep infinity >/dev/null
}

unhealthy() {
  # Rootless health checks run on a timer; run one now instead of waiting.
  podman healthcheck run demo-unhealthy >/dev/null 2>&1 || true
  podman inspect -f '{{.State.Health.Status}}' demo-unhealthy
}

teardown() {
  local -a names
  mapfile -t names < <(podman ps -a --format '{{.Names}}' | grep '^demo-' || true)
  if [ "${#names[@]}" -gt 0 ]; then podman rm -f -t 0 "${names[@]}" >/dev/null; fi
  for v in demo-cache demo-empty; do podman volume rm -f "$v" >/dev/null 2>&1 || true; done
  podman network rm -f demo-net >/dev/null 2>&1 || true
  podman rmi -f "$tag_app" "$tag_tool" >/dev/null 2>&1 || true
  if [ -f "$pulled" ]; then
    while read -r base; do podman rmi "$base" >/dev/null 2>&1 || true; done <"$pulled"
    rm -f "$pulled"
  fi
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
