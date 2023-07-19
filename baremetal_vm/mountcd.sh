#!/usr/bin/env bash
set -euo pipefail
source common.sh

usage(){
	cat <<-EOF
	Usage: ${0} [-f <path/to/variables/file>] [-n <vmname> -i <iso image path>]
	EOF
}

VM_ISOPATH=${VM_ISOPATH:-}

while getopts 'f:i:n:h' OPTION; do
	case "${OPTION}" in
		f)
			[ -f "${OPTARG}" ] && ENVFILE="${OPTARG}" || die "Parameters file ${OPTARG} not found" 2
			;;
		i)
			VM_ISOPATH="${OPTARG}"
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

if [ -z "${VM_ISOPATH}" ]; then
	die "No iso image path provided, specify via -i or VM_ISOPATH"
fi

if [ $(uname -o) == "Darwin" ]; then
	if [ $(utmctl status ${VMNAME}) != "stopped" ]; then
		die "VM ${VMNAME} must be stopped to attach ISO"
	fi
	OUTPUT=$(osascript <<-END
	tell application "UTM"
		set vm to virtual machine named "${VMNAME}"
		set config to configuration of vm
		set iso to POSIX file "${VM_ISOPATH}"
		set beginning of drives of config to {removable:true, interface: usb, raw:true, source:iso}
		--- save the configuration (VM must be stopped)
		update configuration of vm with config
	end tell
	END
	)

	echo "Attached ${VM_ISOPATH} to ${VMNAME}"

elif [ $(uname -o) == "GNU/Linux" ]; then
	echo "Not supported on Linux, use sushy-tools instead"
	exit 1
else
	die "Unsupported operating system" 2
fi
