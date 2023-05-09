#!/usr/bin/env bash
set -euo pipefail
BASEDIR="$(dirname "$0")"

die(){
	echo ${1} >&2
	exit ${2}
}

usage(){
	echo "Usage: ${0} myuser mypassword"
}

command -v jq > /dev/null 2>&1 || die "jq not found" 2

if [ $# -lt 2 ]; then
	usage
	die "Error: User & Password not provided" 1
fi

USER=${1}
PASS=${2}

SYSTEMS=$(curl -X 'GET' -s 'https://scc.suse.com/connect/organizations/systems' -H 'accept: application/json' -u ${USER}:${PASS})
TOTAL=$(echo ${SYSTEMS} | jq length)
TOTAL=$(($TOTAL-1))

if [ ${TOTAL} -lt 0 ]; then
	# Not an error but a "warn"
	die "Warning: No systems found" 0
fi

for i in {0..${TOTAL}}; do
	LOGIN=$(echo ${SYSTEMS} | jq -r ".[${i}].login")
	PASS=$(echo ${SYSTEMS} | jq -r ".[${i}].password")
	curl -X 'DELETE' -s 'https://scc.suse.com/connect/systems' \
  	-H 'Accept: application/vnd.scc.suse.com.v4+json' \
  	-u ${LOGIN}:${PASS}
done