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
	OUTPUT=$(osascript <<-END
	tell application "UTM"
		set vm to virtual machine named "${VMNAME}"
		start vm
		repeat
			if status of vm is started then exit repeat
		end repeat
		get address of first serial port of vm
	end tell
	END
	)

	echo "VM ${VMNAME} started. You can connect to the serial terminal as: screen ${OUTPUT}"

elif [ $(uname -o) == "GNU/Linux" ]; then
	virsh start ${VMNAME}
	echo "VM ${VMNAME} started. You can connect to the serial terminal as: virsh console ${VMNAME}"
else
	die "VM not started. Unsupported operating system" 2
fi
