#!/usr/bin/env bash
set -euo pipefail

source common.sh

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
command -v qemu-img > /dev/null 2>&1 || die "qemu-img not found" 2

# Check if the image file exist
[ -f ${VMFOLDER}/${VMNAME}.qcow2 ] && die "Image file ${VMFOLDER}/${VMNAME}.qcow2 already exists" 2

# Check if the MAC address has been set
[ "${MACADDRESS}" != "null" ] || die "MAC Address needs to be specified and it should match the one defined on EIB at \"<eibfolder>/network/${VMNAME}.yaml\"" 2

# Create the image file
mkdir -p ${VMFOLDER}
qemu-img convert -O qcow2 ${IMAGE} ${VMFOLDER}/${VMNAME}.qcow2

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

# Create the VM
	OUTPUT=$(osascript <<-END
	tell application "UTM"
		-- specify the RAW file
		set rootfs to POSIX file "${VMFOLDER}/${VMNAME}.qcow2"
		-- specify extra disks
		${UTMEXTRADISKS}
		--- create a new QEMU VM
		set vm to make new virtual machine with properties {backend:qemu, configuration:{cpu cores:${CPUS}, memory: ${MEMORY}, name:"${VMNAME}", network interfaces:{{hardware:"virtio-net-pci", mode:shared, index:0, address:"${MACADDRESS}", port forwards:{}, host interface:""}}, architecture:"aarch64", drives:${UTMDISKMAPPING}}
		start vm
		repeat
			if status of vm is started then exit repeat
		end repeat
		get address of first serial port of vm
	end tell
	END
	)

	echo "VM ${VMNAME} started. You can connect to the serial terminal as: screen ${OUTPUT}"

	VMMAC=$(echo ${MACADDRESS} | sed 's/0\([0-9A-Fa-f]\)/\1/g')
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
		--network network=${VM_NETWORK},model=virtio,mac=${MACADDRESS} \
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
