#!/bin/bash
set -euo pipefail

# Registration
if [ "${REGISTER}" = true ]; then
	if ! which SUSEConnect > /dev/null 2>&1; then
		zypper --non-interactive install suseconnect-ng
	fi

	SCC_REGISTRATION_HOST=${SCC_REGISTRATION_HOST:-https://scc.suse.com}
	SUSEConnect --email "${EMAIL}" --url "${SCC_REGISTRATION_URL}" --regcode "${REGCODE}"
fi
