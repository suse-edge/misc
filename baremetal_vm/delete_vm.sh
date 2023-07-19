#!/usr/bin/env bash
set -euo pipefail
source common.sh

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
		virsh undefine ${VMNAME}
	else
		die "${VMNAME} not found" 2
	fi
else
	die "Unsupported operating system" 2
fi

[ -f ${VMFOLDER}/${VMNAME}.raw ] && rm -f ${VMFOLDER}/${VMNAME}.raw
[ -f ${VMFOLDER}/${VMNAME}.qcow2 ] && rm -f ${VMFOLDER}/${VMNAME}.qcow2
[ -f ${VMFOLDER}/${VMNAME}.yaml ] && rm -f ${VMFOLDER}/${VMNAME}.yaml
[ "${EXTRADISKS}" != false ] && rm -f ${VMFOLDER}/${VMNAME}-extra-disk-*.raw

BMH_NAME=$(echo "${VMNAME}" | tr '[:upper:]' '[:lower:]')
kubectl delete bmh ${BMH_NAME}
