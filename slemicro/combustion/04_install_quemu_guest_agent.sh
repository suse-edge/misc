#!/bin/bash
set -euo pipefail

# Installing qemu-guest-agent service
if [ "${QEMUGUESTAGENT}" = true ]; then
    zypper --non-interactive install qemu-guest-agent
    systemctl enable qemu-guest-agent
fi
