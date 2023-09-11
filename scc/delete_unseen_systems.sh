#!/usr/bin/env bash
set -euo pipefail
BASEDIR="$(dirname "$0")"

die(){
	echo ${1} >&2
	exit ${2}
}

usage(){
	echo "Usage: ${0} myuser mypassword [days]"
	echo "7 days by default"
}

command -v jq > /dev/null 2>&1 || die "jq not found" 2

if [ $# -lt 2 ]; then
	usage
	die "Error: User & Password not provided" 1
fi

USER=${1}
PASS=${2}
DAYS="${3:-7}"

SYSTEMS=$(curl -X 'GET' -s 'https://scc.suse.com/connect/organizations/systems' -H 'accept: application/json' -u ${USER}:${PASS})
TOTAL=$(echo ${SYSTEMS} | jq length)

if [ ${TOTAL} -le 0 ]; then
	# Not an error but a "warn"
	die "Warning: No systems found" 0
fi

TODAY=$(date +%s)

for ((i=0; i<${TOTAL}; i++)); do
	LOGIN=$(echo ${SYSTEMS} | jq -r ".[${i}].login")
	PASS=$(echo ${SYSTEMS} | jq -r ".[${i}].password")
	LAST=$(echo ${SYSTEMS} | jq -r ".[${i}].last_seen_at")
	EPOCH=$(date -d "${LAST}" +%s)
	let DIFF=(${TODAY}-${EPOCH})/86400
	if [ ${DIFF} -gt ${DAYS} ]; then
		curl -X 'DELETE' -s 'https://scc.suse.com/connect/systems' \
		 	-H 'Accept: application/vnd.scc.suse.com.v4+json' \
		 	-u ${LOGIN}:${PASS}
	fi
done
