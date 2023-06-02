#!/bin/bash
set -euo pipefail

# SSH key management
if [ "${SSHCONFIG}" = true ]; then
	mkdir -pm700 /root/.ssh/
	echo "${SSHCONTENT}" >> /root/.ssh/authorized_keys
fi