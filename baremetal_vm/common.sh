#!/usr/bin/env bash
BASEDIR="$(dirname "$0")"

die(){
	echo ${1} 1>&2
	exit ${2}
}

usage(){
	cat <<-EOF
	Usage: ${0} [-f <path/to/variables/file>] [-n <vmname>]
	EOF
}

set -a
# Source the .env file if it exists
ENVFILE=${ENVFILE:-${BASEDIR}/.env}
[ -f ${ENVFILE} ] && source ${ENVFILE}

# Some defaults if no .env is specified
VMFOLDER=${VMFOLDER:-"${HOME}/VMs"}
CPUS="${CPUS:-2}"
MEMORY="${MEMORY:-2048}"
DISKSIZE="${DISKSIZE:-30}"
VMNAME="${VMNAME:-BareMetalHost}"
EXTRADISKS="${EXTRADISKS:-false}"
set +a
