#!/bin/bash
# SSH into the dev VM started by vm-run.sh (dev disks only: the zerc user + key come from image/bib-config.dev.toml).
PORT_BASE=${PORT_BASE:-18820}
exec ssh -i ~/.ssh/id_ed25519_ottoman -p $((PORT_BASE + 2)) -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR zerc@127.0.0.1 "$@"
