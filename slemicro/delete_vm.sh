#!/usr/bin/env bash
set -euo pipefail
BASEDIR="$(dirname "$0")"
source ${BASEDIR}/common.sh

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
EXTRADISKS="${EXTRADISKS:-false}"
set +a

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
	if virsh list --all --name | grep -q ${VMNAME} ; then
		[ "$(virsh domstate ${VMNAME} 2>/dev/null)" == "running" ] && virsh destroy ${VMNAME}
		virsh undefine ${VMNAME} --nvram --remove-all-storage
	else
		echo "${VMNAME} not found"
	fi
else
	die "Unsupported operating system" 2
fi

for ext in raw qcow2; do
	if [ -f ${VMFOLDER}/${VMNAME}.${ext} ]; then
		echo "Deleting ${VMFOLDER}/${VMNAME}.${ext}"
      		rm -f ${VMFOLDER}/${VMNAME}.${ext}
	fi
done

if [ "${EXTRADISKS}" != false ]; then 
	rm -f ${VMFOLDER}/${VMNAME}-extra-disk-*.raw
fi

exit 0
