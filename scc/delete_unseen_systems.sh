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

delete_systems(){
	SYSTEMS=$(curl -X 'GET' -s "${1}" -H 'accept: application/json' -u ${USER}:${PASS})
	TOTAL=$(echo ${SYSTEMS} | jq length)

	if [ ${TOTAL} -le 0 ]; then
		# Not an error but a "warn"
		die "Warning: No systems found" 0
	fi

	TODAY=$(date +%s)

	for ((j=0; j<${TOTAL}; j++)); do
		HOST=$(echo ${SYSTEMS} | jq -r ".[${j}]")
		ID=$(echo ${HOST} | jq -r ".id")
		HOSTLOGIN=$(echo ${HOST} | jq -r ".login")
		HOSTPASS=$(echo ${HOST} | jq -r ".password")
		LASTSEEN=$(echo ${HOST} | jq -r ".last_seen_at")
		EPOCH=$(date -d "${LASTSEEN}" +%s)
		DIFF=$(( (TODAY - EPOCH) / 86400 ))
		if [ ${DIFF} -gt ${DAYS} ]; then
			echo "Deleting $((j+1))/${TOTAL} - ${ID}, last seen at ${LASTSEEN}"
			curl -X 'DELETE' -s 'https://scc.suse.com/connect/systems' \
				-H 'Accept: application/vnd.scc.suse.com.v4+json' \
				-u ${HOSTLOGIN}:${HOSTPASS}
		else
			echo "Not deleting ${ID}, last seen at ${LASTSEEN}"
		fi
	done
}

command -v jq > /dev/null 2>&1 || die "jq not found" 2

if [ $# -lt 2 ]; then
	usage
	die "Error: User & Password not provided" 1
fi

USER=${1}
PASS=${2}
DAYS="${3:-7}"
URL="https://scc.suse.com/connect/organizations/systems"

PAGINATION=$(curl "${URL}" -H 'accept: application/json' -u ${USER}:${PASS} -I -s -o /dev/null -w '%header{link}')

if [[ ${#PAGINATION} -gt 0 ]]; then
	# Extract the "last" page number
	LASTPAGE=$(echo "${PAGINATION}" | grep -oP '(?<=page=)\d+(?=>; rel="last")')
	# Extract the "next" page number
	NEXTPAGE=$(echo "${PAGINATION}" | grep -oP '(?<=page=)\d+(?=>; rel="next")')
	# Start the loop from NEXT - 1
	STARTPAGE=$((NEXTPAGE - 1))

	# Loop from START to LAST
	for ((i=STARTPAGE; i<=LASTPAGE; i++)); do
		delete_systems "${URL}?page=${i}"
	done
else
	delete_systems "${URL}"
fi
