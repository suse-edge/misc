#!/usr/bin/env bash
set -euo pipefail
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

while getopts 'f:n:h' OPTION; do
	case "${OPTION}" in
		f)
			[ -f "${OPTARG}" ] && ENVFILE="${OPTARG}" || die "Parameters file ${OPTARG} not found" 2
			;;
		n)
			VMNAME="${OPTARG}"
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
set +a

VMFOLDER="${VMFOLDER:-~/VMs}"

if [ $(uname -o) == "Darwin" ]; then
# Stop and delete the VM using UTM
	OUTPUT=$(
	osascript <<-END
	tell application "UTM"
		if exists virtual machine named "${VMNAME}" then
			set vm to virtual machine named "${VMNAME}"
			if status of vm is started then stop vm
			repeat
				if status of vm is stopped then exit repeat
			end repeat
			delete virtual machine named "${VMNAME}"
		end if
	end tell
	END
	)
elif [ $(uname -o) == "GNU/Linux" ]; then
	virsh destroy ${VMNAME}
	virsh undefine ${VMNAME}
else
	die "Unsupported operating system" 2
fi

[ -f ${VMFOLDER}/${VMNAME}.raw ] && rm -f ${VMFOLDER}/${VMNAME}.raw
[ -f ${VMFOLDER}/${VMNAME}.qcow2 ] && rm -f ${VMFOLDER}/${VMNAME}.qcow2
[ -f ${VMFOLDER}/ignition-and-combustion-${VMNAME}.iso ] && rm -f ${VMFOLDER}/ignition-and-combustion-${VMNAME}.iso

exit 0