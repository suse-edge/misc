#!/usr/bin/env bash
set -euo pipefail
BASEDIR="$(dirname "$0")"
source ${BASEDIR}/common.sh

usage(){
	cat <<-EOF
	Usage: ${0} [-f <path/to/variables/file>] [-e <path/to/eib/folder>] [-n <vmname>]
	EOF
}

ENVFILE=""
EIBFOLDER=""

while getopts 'f:e:n:h' OPTION; do
	case "${OPTION}" in
		f)
			[ -f "${OPTARG}" ] && ENVFILE="${OPTARG}" || die "Parameters file ${OPTARG} not found" 2
			;;
		e)
			[ -d "${OPTARG}" ] && EIBFOLDER="$(readlink -f ${OPTARG})" || die "EIB folder ${OPTARG} not found" 2
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
[ -z "${EIBFOLDER}" ] && { usage && die "\"-e <path/to/eib/folder>\" required" 2;}

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
EIB_IMAGE="${EIB_IMAGE:-registry.suse.com/edge/3.3/edge-image-builder:1.2.1}"
LIBVIRT_DISK_SETTINGS="${LIBVIRT_DISK_SETTINGS:-bus=virtio}"
set +a

check_os

# Check if the commands required exist
command -v podman > /dev/null 2>&1 || die "podman not found" 2
command -v qemu-img > /dev/null 2>&1 || die "qemu-img not found" 2
command -v yq > /dev/null 2>&1 || die "yq not found" 2

# Check if the EIB definition file exist
[ -f ${EIBFOLDER}/eib.yaml ] || die "EIB definition file \"${EIBFOLDER}/eib.yaml\" not found" 2

# Check if the network config file exist
if ! [[ -f "${EIBFOLDER}/network/${VMNAME}.yaml" || -f "${EIBFOLDER}/network/_all.yaml" ]]; then
	# For some scenarios this may not be needed
	echo "Warning: Network definition file for ${VMNAME} \"${EIBFOLDER}/network/${VMNAME}.yaml\" nor \"${EIBFOLDER}/network/_all.yaml\" found"
fi

# Check if it matches the EIB definition
if [ -f ${EIBFOLDER}/network/${VMNAME}.yaml ]; then
	EIBMACADDRESS=$(cat ${EIBFOLDER}/network/${VMNAME}.yaml | yq -r ".interfaces[0].mac-address")
	if [ ${EIBMACADDRESS} == "null" ]; then
		echo "Info: Network definition file for ${VMNAME}, \"${EIBFOLDER}/network/${VMNAME}.yaml\", doesn't contain a mac-address, a random one will be created"
		MACADDRESS=$(generate_mac)
	fi
	if [ ${EIBMACADDRESS} != "${MACADDRESS}" ]; then
		echo "Warning: Network definition file for ${VMNAME}, \"${EIBFOLDER}/network/${VMNAME}.yaml\", mac-address ${EIBMACADDRESS} is different than the env var ${MACADDRESS}, using the \"${EIBFOLDER}/network/${VMNAME}.yaml\" one"
		MACADDRESS="${EIBMACADDRESS}"
	fi
fi

# Just in case
[ ${MACADDRESS} == "null" ] && MACADDRESS=$(generate_mac)

# Only check podman machine on non linux OSes
if [ $(uname -o) != "GNU/Linux" ]; then
	# Check podman-machine-default specs and warn the user
	PODMANMACHINESPECS=$(podman machine inspect podman-machine-default)
	PODMANMACHINECPU=$(echo ${PODMANMACHINESPECS} | yq -r ".[0].Resources.CPUs")
	PODMANMACHINEMEMORY=$(echo ${PODMANMACHINESPECS} | yq -r ".[0].Resources.Memory")

	[ ${PODMANMACHINECPU} -lt 4 ] && echo "Warning: Podman machine number of CPUs is too low for the EIB RPM resolution process to work, consider increasing them to at least 4 (see podman machine set --help)"
	[ ${PODMANMACHINEMEMORY} -lt 4096 ] && echo "Warning: Podman machine memory is too low for the EIB RPM resolution process to work, consider increasing it to at least 4096 MB (see podman machine set --help)"
fi

# Do the EIB thing
podman run --rm -it --privileged -v ${EIBFOLDER}:/eib \
	${EIB_IMAGE} \
	build --definition-file eib.yaml

OUTPUTNAME=$(cat ${EIBFOLDER}/eib.yaml | yq -r .image.outputImageName)
IMAGE="${EIBFOLDER}/${OUTPUTNAME}"

exit 0
