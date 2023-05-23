#!/usr/bin/env bash
set -euo pipefail
BASEDIR="$(dirname "$0")"

die(){
	echo ${1}
	exit ${2}
}

# Get the env file
source ${BASEDIR}/.env
if [ $# -eq 1 ]; then
	VMNAME=$1
fi
VMFOLDER="${VMFOLDER:-~/VMs}"

if [ $(uname -o) == "Darwin" ]; then
# Stop and delete the VM using UTM
	OUTPUT=$(
	osascript <<-END
	tell application "UTM"
		set vm to virtual machine named "${VMNAME}"
		if status of vm is started then stop vm
		repeat
			if status of vm is stopped then exit repeat
		end repeat
		delete virtual machine named "${VMNAME}"
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