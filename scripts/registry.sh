#!/bin/bash
# Local OCI registry on the build host for the dev loop: build -> push here -> `bootc switch` in the VM / on the Tiny.
# Rootless podman, port 18821 (Ottoman block), data in ~/.local/share/ottoman-registry. Fails loudly if the port is taken.
set -euo pipefail
case "${1:-start}" in
  start)
    if podman container exists ottoman-registry; then podman start ottoman-registry >/dev/null; else
      mkdir -p ~/.local/share/ottoman-registry
      podman run -d --name ottoman-registry --restart=always -p 18821:5000 \
        -v ~/.local/share/ottoman-registry:/var/lib/registry:Z docker.io/library/registry:2 >/dev/null
    fi
    sleep 1; curl -fsS http://127.0.0.1:18821/v2/_catalog && echo " registry up on :18821" ;;
  push)
    TAG=${2:-dev}
    podman tag localhost/ottoman:dev "localhost:18821/ottoman:$TAG"
    podman push --tls-verify=false "localhost:18821/ottoman:$TAG"
    curl -fsS "http://127.0.0.1:18821/v2/ottoman/tags/list"; echo ;;
  stop) podman stop ottoman-registry ;;
  *) echo "usage: $0 start|push [tag]|stop" >&2; exit 2 ;;
esac
