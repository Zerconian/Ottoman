#!/bin/bash
# Dev-loop settings that are specific to one machine and one person: never in git. Scripts source this file.
# Put your values in .ottoman-dev.env at the repo root (gitignored; see .ottoman-dev.env.example). Defaults below
# make a fresh clone work: dev user "dev", the first LAN address of this host for the dev registry, and
# ~/.ssh/id_ed25519_ottoman as the VM key (created on first use by scripts/vm-run.sh).
[ -f "$(dirname "${BASH_SOURCE[0]}")/../.ottoman-dev.env" ] && . "$(dirname "${BASH_SOURCE[0]}")/../.ottoman-dev.env"
: "${DEV_USER:=dev}"
: "${DEV_REGISTRY_HOST:=$(hostname -I 2>/dev/null | awk '{print $1}')}"
: "${DEV_SSH_IDENTITY:=$HOME/.ssh/id_ed25519_ottoman}"
: "${DEV_SSH_KEY:=$(cat "$DEV_SSH_IDENTITY.pub" 2>/dev/null || true)}"
export DEV_USER DEV_REGISTRY_HOST DEV_SSH_IDENTITY DEV_SSH_KEY
