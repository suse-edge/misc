#!/usr/bin/env bash
set -euo pipefail

source common.sh

usage(){
	cat <<-EOF
	Usage: ${0} [-f <path/to/variables/file>] [-e <path/to/eib/folder>] [-n <vmname>]
	EOF
}

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

set -a
# Get the env file
source ${ENVFILE:-${BASEDIR}/.env}
# Some defaults just in case
CPUS="${CPUS:-2}"
MEMORY="${MEMORY:-2048}"
VMNAME="${NAMEOPTION:-${VMNAME:-slemicro}}"
VM_STATIC_IP=${VM_STATIC_IP:-}
VM_STATIC_PREFIX=${VM_STATIC_PREFIX:-24}
VM_STATIC_GATEWAY=${VM_STATIC_GATEWAY:-"192.168.122.1"}
VM_STATIC_DNS=${VM_STATIC_DNS:-${VM_STATIC_GATEWAY}}
EXTRADISKS="${EXTRADISKS:-false}"
VM_NETWORK=${VM_NETWORK:-default}
EIB_IMAGE="${EIB_IMAGE:-registry.suse.com/edge/3.1/edge-image-builder:1.1.0}"
set +a

if [ $(uname -o) == "Darwin" ]; then
	# Check if UTM version is 4.2.2 (required for the scripting part)
	ver(){ printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' '); }
	UTMVERSION=$(/usr/libexec/plistbuddy -c Print:CFBundleShortVersionString: /Applications/UTM.app/Contents/info.plist)
	[ $(ver ${UTMVERSION}) -lt $(ver 4.2.2) ] && die "UTM version >= 4.2.2 required" 2
elif [ $(uname -o) == "GNU/Linux" ]; then
	command -v virt-install > /dev/null 2>&1 || die "virt-install command not found" 2
else
	die "Unsupported operating system" 2
fi

# Check if the commands required exist
command -v podman > /dev/null 2>&1 || die "podman not found" 2
command -v qemu-img > /dev/null 2>&1 || die "qemu-img not found" 2
command -v yq > /dev/null 2>&1 || die "yq not found" 2

# Check if the EIB definition file exist
[ -f ${EIBFOLDER}/eib.yaml ] || die "EIB definition file \"${EIBFOLDER}/eib.yaml\" not found" 2

# Do the EIB thing
podman run --rm -it --privileged -v ${EIBFOLDER}:/eib \
	${EIB_IMAGE} \
	build --definition-file eib.yaml

OUTPUTNAME=$(cat ${EIBFOLDER}/eib.yaml | yq .image.outputImageName)
EIBFILE="${EIBFOLDER}/${OUTPUTNAME}"

# Create the image file
mkdir -p ${VMFOLDER}
qemu-img convert -O qcow2 ${EIBFILE} ${VMFOLDER}/${VMNAME}.qcow2

if [ "${EXTRADISKS}" != false ]; then
	DISKARRAY=(${EXTRADISKS//,/ })
	for (( i=0; i<"${#DISKARRAY[@]}"; i++ )); do
		qemu-img create -f qcow2 ${VMFOLDER}/${VMNAME}-extra-disk-${i}.qcow2 "${DISKARRAY[$i]}"G > /dev/null
	done
fi

if [ $(uname -o) == "Darwin" ]; then
	# See if there are extra disks to be created
	UTMEXTRADISKS=""
	UTMEXTRADISKMAPPING=""
	if [ "${EXTRADISKS}" != false ]; then
		# Probably not needed
		DISKARRAY=(${EXTRADISKS//,/ })
		for (( i=0; i<"${#DISKARRAY[@]}"; i++ )); do
			UTMEXTRADISKS="${UTMEXTRADISKS}
	set extradisk${i} to POSIX file \"${VMFOLDER}/${VMNAME}-extra-disk-${i}.qcow2\""
			UTMEXTRADISKMAPPING="${UTMEXTRADISKMAPPING}, {removable:false, source:extradisk${i}}"
		done
	fi

	# If there are not extra disks, this works as well
	UTMDISKMAPPING="{removable:false, source:rootfs}${UTMEXTRADISKMAPPING}}"

	# Create and launch the VM using UTM
	OUTPUT=$(osascript <<-END
	tell application "UTM"
		-- specify the RAW file
		set rootfs to POSIX file "${VMFOLDER}/${VMNAME}.qcow2"
		-- specify extra disks
		${UTMEXTRADISKS}
		--- create a new QEMU VM
		set vm to make new virtual machine with properties {backend:qemu, configuration:{cpu cores:${CPUS}, memory: ${MEMORY}, name:"${VMNAME}", architecture:"aarch64", drives:${UTMDISKMAPPING}}
		start vm
		repeat
			if status of vm is started then exit repeat
		end repeat
		get address of first serial port of vm
	end tell
	END
	)

	echo "VM ${VMNAME} started. You can connect to the serial terminal as: screen ${OUTPUT}"

	OUTPUT=$(osascript <<-END
	tell application "UTM"
		set vm to virtual machine named "${VMNAME}"
		set config to configuration of vm
		get address of item 1 of network interfaces of config
	end tell
	END
	)

	VMMAC=$(echo $OUTPUT | sed 's/0\([0-9A-Fa-f]\)/\1/g')

	timeout=180
	count=0

	echo -n "Waiting for IP: "
	until grep -q -i "${VMMAC}" -B1 -m1 /var/db/dhcpd_leases | head -1 | awk -F= '{ print $2 }'; do
		count=$((count + 1))
		if [[ ${count} -ge ${timeout} ]]; then
			break
		fi
		sleep 1
		echo -n "."
	done
	VMIP=$(grep -i "${VMMAC}" -B1 -m1 /var/db/dhcpd_leases | head -1 | awk -F= '{ print $2 }')
elif [ $(uname -o) == "GNU/Linux" ]; then
	qemu-img convert -O qcow2 ${VMFOLDER}/${VMNAME}.raw ${VMFOLDER}/${VMNAME}.qcow2
	# The raw file is still there doing nothing
	rm -f ${VMFOLDER}/${VMNAME}.raw

	# By default virt-install powers off the VM when rebooted once.
	# As a workaround, create the VM definition, change the on_reboot behaviour
	# and start the VM
	# See https://bugzilla.redhat.com/show_bug.cgi?id=1792411 for the print-xml 1 reason :)
	VIRTFILE=$(mktemp)
	virt-install --name ${VMNAME} \
		--noautoconsole \
		--memory ${MEMORY} \
		--vcpus ${CPUS} \
		--disk ${VMFOLDER}/${VMNAME}.qcow2 \
		--import \
		--network network=${VM_NETWORK} \
		--osinfo detect=on,name=sle-unknown \
		--print-xml 1 > ${VIRTFILE}
	sed -i -e 's#<on_reboot>destroy</on_reboot>#<on_reboot>restart</on_reboot>#g' ${VIRTFILE}
	virsh define ${VIRTFILE}
	virsh start ${VMNAME}
	rm -f ${VIRTFILE}
	echo "VM ${VMNAME} started. You can connect to the serial terminal as: virsh console ${VMNAME}"
	echo -n "Waiting for IP..."
	timeout=180
	count=0
	VMIP=""
	while [ -z "${VMIP}" ]; do
			sleep 1
			count=$((count + 1))
			if [[ ${count} -ge ${timeout} ]]; then
				break
			fi
			echo -n "."
			VMIP=$(vm_ip ${VMNAME})
	done
else
	die "VM not deployed. Unsupported operating system" 2
fi

printf "\nVM IP: ${VMIP}\n"

exit 0
