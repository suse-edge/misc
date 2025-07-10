#!/usr/bin/env bash
BASEDIR="$(dirname "$0")"

die(){
	echo ${1} 1>&2
	exit ${2}
}

check_os(){
	if [ $(uname -o) == "Darwin" ]; then
		# Check if UTM version is 4.2.2 (required for the scripting part)
		ver(){ printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' '); }
		UTMVERSION=$(/usr/libexec/plistbuddy -c Print:CFBundleShortVersionString: /Applications/UTM.app/Contents/info.plist)
		if [ $(ver ${UTMVERSION}) -lt $(ver 4.2.2) ]; then
			die "UTM version >= 4.2.2 required" 2
		fi
	elif [ $(uname -o) == "GNU/Linux" ]; then
		command -v virt-install > /dev/null 2>&1 || die "virt-install command not found" 2
	else
		die "Unsupported operating system" 2
	fi
}

create_empty_image_file(){
	SIZE="${1:-20}"
	mkdir -p ${VMFOLDER}
	qemu-img create -f qcow2 ${VMFOLDER}/${VMNAME}.qcow2 ${SIZE}G
}

create_image_file(){
	# Create the image file
	mkdir -p ${VMFOLDER}
	qemu-img convert -O qcow2 ${IMAGE} ${VMFOLDER}/${VMNAME}.qcow2

}

create_extra_disks(){
	if [ "${EXTRADISKS}" != false ]; then
		DISKARRAY=(${EXTRADISKS//,/ })
		for (( i=0; i<"${#DISKARRAY[@]}"; i++ )); do
			qemu-img create -f qcow2 ${VMFOLDER}/${VMNAME}-extra-disk-${i}.qcow2 "${DISKARRAY[$i]}"G > /dev/null
		done
	fi
}

create_vm(){
	POWERON="${1:-true}"
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
	VMCREATION=$(osascript <<-END
	tell application "UTM"
		-- specify the RAW file
		set rootfs to POSIX file "${VMFOLDER}/${VMNAME}.qcow2"
		-- specify extra disks
		${UTMEXTRADISKS}
		--- create a new QEMU VM
		set vm to make new virtual machine with properties {backend:qemu, configuration:{cpu cores:${CPUS}, memory: ${MEMORY}, name:"${VMNAME}", network interfaces:{{hardware:"virtio-net-pci", mode:shared, index:0, address:"${MACADDRESS}", port forwards:{}, host interface:""}}, architecture:"aarch64", drives:${UTMDISKMAPPING}}
	end tell
	END
	)

	if [ ${POWERON} == "true" ]; then
		# Create the VM
		OUTPUT=$(osascript <<-END
		tell application "UTM"
			set vm to virtual machine named "${VMNAME}"
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
	fi
	elif [ $(uname -o) == "GNU/Linux" ]; then
		# By default virt-install powers off the VM when rebooted once.
		# As a workaround, create the VM definition, change the on_reboot behaviour
		# and start the VM
		# See https://bugzilla.redhat.com/show_bug.cgi?id=1792411 for the print-xml 1 reason :)
		# The following ones are perhaps useful:
		# --rng /dev/urandom
		# --tpm backend.type=emulator,backend.version=2.0
		VIRTFILE=$(mktemp)
		virt-install --name ${VMNAME} \
			--noautoconsole \
			--memory ${MEMORY} \
			--vcpus ${CPUS} \
			--disk ${LIBVIRT_DISK_SETTINGS},path=${VMFOLDER}/${VMNAME}.qcow2 \
			--import \
			--network network=${VM_NETWORK},model=virtio,mac=${MACADDRESS} \
			--osinfo detect=on,name=sle-unknown \
			--sound none \
			--boot uefi \
			--print-xml 1 > ${VIRTFILE}
		sed -i -e 's#<on_reboot>destroy</on_reboot>#<on_reboot>restart</on_reboot>#g' ${VIRTFILE}
		virsh define ${VIRTFILE}
		rm -f ${VIRTFILE}
		
		if [ ${POWERON} == "true" ]; then
			virsh start ${VMNAME}
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
		fi

	else
		die "VM not deployed. Unsupported operating system" 2
	fi
}

generate_mac(){
	# The fixed OUI prefix for QEMU/KVM
	MAC_PREFIX="52:54:00"

	# Generate 3 random octets (6 hexadecimal characters)
	# We use /dev/urandom for better randomness, convert to hex, and take the first 6 characters
	random_suffix=$(head /dev/urandom | tr -dc '0-9a-f' | head -c 6)

	# Format the suffix into colon-separated pairs
	MAC_SUFFIX=$(printf '%s:%s:%s' \
			"${random_suffix:0:2}" \
			"${random_suffix:2:2}" \
			"${random_suffix:4:2}")

	# Combine prefix and suffix
	echo "${MAC_PREFIX}:${MAC_SUFFIX}"
}

vm_ip(){
	if [ $(uname -o) == "Darwin" ]; then
		# Check if UTM version is 4.2.2 (required for the scripting part)
		ver(){ printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' '); }
		UTMVERSION=$(/usr/libexec/plistbuddy -c Print:CFBundleShortVersionString: /Applications/UTM.app/Contents/info.plist)
		[ $(ver ${UTMVERSION}) -lt $(ver 4.2.2) ] && die "UTM version >= 4.2.2 required" 2
	
		# Get the VM IP
		OUTPUT=$(osascript <<-END
		tell application "UTM"
			set vm to virtual machine named "${1}"
			set config to configuration of vm
			get address of item 1 of network interfaces of config
		end tell
		END
		)
		VMMAC=$(echo $OUTPUT | sed 's/0\([0-9A-Fa-f]\)/\1/g')
		VMIP=$(grep -i "${VMMAC}" -B1 -m1 /var/db/dhcpd_leases | head -1 | awk -F= '{ print $2 }')
	elif [ $(uname -o) == "GNU/Linux" ]; then
		IFADDR_SOURCE=""
		if [ ! -z "${VM_STATIC_IP:-}" ]; then
			IFADDR_SOURCE="--source=arp"
		fi
		VMIP=$(virsh domifaddr ${1} ${IFADDR_SOURCE} | awk -F'[ /]+' '/ipv/ {print $5}' )
	else
		die "Unsupported operating system" 2
	fi
	echo ${VMIP}
}
