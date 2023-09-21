#!/usr/bin/env bash
BASEDIR="$(dirname "$0")"

die(){
	echo ${1} 1>&2
	exit ${2}
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
			set vm to virtual machine named "${VMNAME}"
			set config to configuration of vm
			get address of item 1 of network interfaces of config
		end tell
		END
		)
		VMMAC=$(echo $OUTPUT | sed 's/0\([0-9A-Fa-f]\)/\1/g')
		VMIP=$(grep -i "${VMMAC}" -B1 -m1 /var/db/dhcpd_leases | head -1 | awk -F= '{ print $2 }')
	elif [ $(uname -o) == "GNU/Linux" ]; then
		IFADDR_SOURCE=""
		if [ ! -z "${VM_STATIC_IP}" ]; then
			IFADDR_SOURCE="--source=arp"
		fi
		VMIP=$(virsh domifaddr ${VMNAME} ${IFADDR_SOURCE} | awk -F'[ /]+' '/ipv/ {print $5}' )
	else
		die "Unsupported operating system" 2
	fi
	echo ${VMIP}
}
