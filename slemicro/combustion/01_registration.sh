#!/bin/bash
set -euo pipefail

# Registration
if [ "${REGISTER}" = true ]; then
	if ! which SUSEConnect > /dev/null 2>&1; then
		zypper --non-interactive install suseconnect-ng
	fi
	SUSEConnect --email "${EMAIL}" --url https://scc.suse.com --regcode "${REGCODE}"
fi
