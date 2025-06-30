#!/usr/bin/env bash
set -euo pipefail
BASEDIR="$(dirname "$0")"
source ${BASEDIR}/common.sh

usage(){
	cat <<-EOF
	Usage: ${0} [-f <path/to/variables/file>] [-i <path/to/image.qcow2>] [-n <vmname>]
	EOF
}

ENVFILE=""
IMAGE=""

while getopts 'f:i:n:h' OPTION; do
	case "${OPTION}" in
		f)
			[ -f "${OPTARG}" ] && ENVFILE="${OPTARG}" || die "Parameters file ${OPTARG} not found" 2
			;;
		i)
			[ -f "${OPTARG}" ] && IMAGE="$(readlink -f ${OPTARG})" || die "Image ${OPTARG} not found" 2
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

[ -z "${ENVFILE}" ] && { usage && die "\"-f <path/to/variables/file>\" required" 2;}
[ -z "${IMAGE}" ] && { usage && die "\"-i <path/to/image.qcow2>\" required" 2;}

set -a
# Get the env file
source ${ENVFILE:-${BASEDIR}/.env}
# Some defaults just in case
CPUS="${CPUS:-2}"
MEMORY="${MEMORY:-2048}"
VMNAME="${NAMEOPTION:-${VMNAME:-slemicro}}"
MACADDRESS="${MACADDRESS:-null}"
VM_STATIC_IP=${VM_STATIC_IP:-}
VM_STATIC_PREFIX=${VM_STATIC_PREFIX:-24}
VM_STATIC_GATEWAY=${VM_STATIC_GATEWAY:-"192.168.122.1"}
VM_STATIC_DNS=${VM_STATIC_DNS:-${VM_STATIC_GATEWAY}}
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

create_image_file

create_extra_disks

create_vm

printf "\nVM IP: ${VMIP}\n"

exit 0
