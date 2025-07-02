#!/usr/bin/env bash
set -euo pipefail
BASEDIR="$(dirname "$0")"
source ${BASEDIR}/common.sh

usage(){
	cat <<-EOF
	Usage: ${0} [-f <path/to/variables/file>] [-s <size_in_GB>] [-n <vmname>]
	EOF
}

ENVFILE=""
SIZE=""

while getopts 'f:s:n:h' OPTION; do
	case "${OPTION}" in
		f)
			[ -f "${OPTARG}" ] && ENVFILE="${OPTARG}" || die "Parameters file ${OPTARG} not found" 2
			;;
		s)
			SIZE="${OPTARG}"
			;;
		n)
			NAMEOPTION="${OPTARG}"
			;;
		h)
			usage && exit 
			;;
		?)
			usage && exit 2
			;;
	esac
done

[ -z "${SIZE}" ] && { usage && die "\"-s <size_in_GB>\" required" 2;}
[ -z "${ENVFILE}" ] && { usage && die "\"-f <path/to/variables/file>\" required" 2;}

set -a
# Get the env file
source ${ENVFILE:-${BASEDIR}/.env}
# Some defaults just in case
CPUS="${CPUS:-2}"
MEMORY="${MEMORY:-2048}"
VMNAME="${NAMEOPTION:-${VMNAME:-slemicro}}"
MACADDRESS="${MACADDRESS:-null}"
EXTRADISKS="${EXTRADISKS:-false}"
VM_NETWORK=${VM_NETWORK:-default}
LIBVIRT_DISK_SETTINGS="${LIBVIRT_DISK_SETTINGS:-bus=virtio}"
set +a

check_os

# Check if the commands required exist
command -v qemu-img > /dev/null 2>&1 || die "qemu-img not found" 2

# Check if the image file exist
[ -f ${VMFOLDER}/${VMNAME}.qcow2 ] && die "Image file ${VMFOLDER}/${VMNAME}.qcow2 already exists" 2

# Check if the MAC address has been set
[ "${MACADDRESS}" != "null" ] || die "MAC Address needs to be specified and it should match the one defined on EIB at \"<eibfolder>/network/${VMNAME}.yaml\"" 2

create_empty_image_file ${SIZE}

create_extra_disks

# Create the VM powered off
create_vm "off"

exit 0
