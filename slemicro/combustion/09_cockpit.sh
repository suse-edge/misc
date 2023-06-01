#!/bin/bash
set -euo pipefail

# Cockpit
if [ "${COCKPIT}" = true ]; then
	systemctl enable cockpit.socket
fi
