#!/bin/bash
# Keep the launcher alive for the life of the session. A crash restarts it after 1 s and logs to the journal.
# sway's exec children live in the logind session scope, not the service cgroup, so a session restart does not kill
# this loop: stop when the sway that started us is gone (its IPC socket vanishes), or two shells run (seen 2026-11-05).
while true; do
  /usr/libexec/ottoman/ottoman-shell
  [ -S "${SWAYSOCK:-/nonexistent}" ] || { echo "ottoman-shell exited and sway is gone, not restarting" >&2; exit 0; }
  echo "ottoman-shell exited with $?, restarting" >&2
  sleep 1
done
