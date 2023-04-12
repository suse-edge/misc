#!/usr/bin/env bash
set -euo pipefail
BASEDIR="$(dirname "$0")"

die(){
  echo ${1}
  exit ${2}
}

# Get the env file
source ${BASEDIR}/.env

VMFOLDER="${VMFOLDER:-~/VMs}"

# Stop and delete the VM using UTM
OUTPUT=$(
osascript <<END
tell application "UTM"
	set vm to virtual machine named "${VMNAME}"
	stop vm
	repeat
	  if status of vm is stopped then exit repeat
  end repeat
	delete virtual machine named "${VMNAME}"
end tell
END
)

[ -f ${VMFOLDER}/${VMNAME}.raw ] && rm -f ${VMFOLDER}/${VMNAME}.raw
[ -f ${VMFOLDER}/ignition-and-combustion-${VMNAME}.iso ] && rm -f ${VMFOLDER}/ignition-and-combustion-${VMNAME}.iso

exit 0