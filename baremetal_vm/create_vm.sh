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

# Create the image file
mkdir -p ${VMFOLDER}

if [ "${EXTRADISKS}" != false ]; then
	DISKARRAY=(${EXTRADISKS//,/ })
	for (( i=0; i<"${#DISKARRAY[@]}"; i++ )); do
		qemu-img create -f raw ${VMFOLDER}/${VMNAME}-extra-disk-${i}.raw "${DISKARRAY[$i]}"G > /dev/null
	done
fi

# if x86_64, convert the image to qcow2
if [ $(uname -o) == "Darwin" ]; then
	qemu-img create -f raw ${VMFOLDER}/${VMNAME}.raw ${DISKSIZE}G
	# See if there are extra disks to be created
	UTMEXTRADISKS=""
	UTMEXTRADISKMAPPING=""
	if [ "${EXTRADISKS}" != false ]; then
		# Probably not needed
		DISKARRAY=(${EXTRADISKS//,/ })
		for (( i=0; i<"${#DISKARRAY[@]}"; i++ )); do
			UTMEXTRADISKS="${UTMEXTRADISKS}
	set extradisk${i} to POSIX file \"${VMFOLDER}/${VMNAME}-extra-disk-${i}.raw\""
			UTMEXTRADISKMAPPING="${UTMEXTRADISKMAPPING}, {removable:false, source:extradisk${i}}"
		done
	fi

	# If there are not extra disks, this works as well
	UTMDISKMAPPING="{{removable:false, source:rawfile}${UTMEXTRADISKMAPPING}}"

	# Create and launch the VM using UTM
	OUTPUT=$(osascript <<-END
	tell application "UTM"
		-- specify the RAW file
		set rawfile to POSIX file "${VMFOLDER}/${VMNAME}.raw"
		-- specify extra disks
		${UTMEXTRADISKS}
		--- create a new QEMU VM
		set vm to make new virtual machine with properties {backend:qemu, configuration:{cpu cores:${CPUS}, memory: ${MEMORY}, name:"${VMNAME}", architecture:"aarch64", drives:${UTMDISKMAPPING}}}
	end tell
	END
	)

elif [ $(uname -o) == "GNU/Linux" ]; then
	qemu-img create -f qcow2 ${VMFOLDER}/${VMNAME}.qcow2 ${DISKSIZE}G

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
		--network network=default \
		--osinfo detect=on,name=sle-unknown \
		--print-xml 1 > ${VIRTFILE}
	sed -i -e 's#<on_reboot>destroy</on_reboot>#<on_reboot>restart</on_reboot>#g' ${VIRTFILE}
	virsh define ${VIRTFILE}
	rm -f ${VIRTFILE}
else
	die "VM not deployed. Unsupported operating system" 2
fi
