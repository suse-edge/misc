#!/usr/bin/env bash
set -euo pipefail

source common.sh

usage(){
	cat <<-EOF
	Usage: ${0} [-f <path/to/variables/file>] [-n <vmname>]
	
	Options:
	 -f		(Optional) Path to the variables file
	 -n		(Optional) Virtual machine name
	EOF
}

while getopts 'f:nh' OPTION; do
	case "${OPTION}" in
		f)
			[ -f "${OPTARG}" ] && ENVFILE="${OPTARG}" || die "Parameters file ${OPTARG} not found" 2
			;;
		n)
			NAMEOPTION="${OPTARG}"
			;;
		h)
			usage && exit 0
			;;
		?)
			usage && exit 2
			;;
	esac
done

set -a
# Get the env file
source ${ENVFILE:-${BASEDIR}/.env}
# Some defaults just in case
VMNAME="${NAMEOPTION:-${VMNAME:-slemicro}}"
set +a

vm_ip
