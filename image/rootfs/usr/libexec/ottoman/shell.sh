#!/bin/bash
# Keep the launcher alive for the life of the session. A crash restarts it after 1 s and logs to the journal.
while true; do
  /usr/libexec/ottoman/ottoman-shell
  echo "ottoman-shell exited with $?, restarting" >&2
  sleep 1
done
