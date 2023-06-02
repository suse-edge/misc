#!/bin/bash
set -euo pipefail

# Podman
if [ "${PODMAN}" = true ]; then
	systemctl enable podman.service podman.socket
fi
