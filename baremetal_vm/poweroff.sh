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
		stop vm by force
	end tell
	END
	)

	echo "VM ${VMNAME} stopped. ${OUTPUT}"

elif [ $(uname -o) == "GNU/Linux" ]; then
	virsh destroy ${VMNAME}
	echo "VM ${VMNAME} stopped."
else
	die "VM not stopped. Unsupported operating system" 2
fi
