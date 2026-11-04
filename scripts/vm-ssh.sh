#!/bin/bash
# SSH into the dev VM started by vm-run.sh (dev disks only: the login user + key come from the dev env, see scripts/dev-env.sh).
. "$(dirname "$0")/dev-env.sh"
PORT_BASE=${PORT_BASE:-18820}
exec ssh -i "$DEV_SSH_IDENTITY" -p $((PORT_BASE + 2)) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR $DEV_USER@127.0.0.1 "$@"
