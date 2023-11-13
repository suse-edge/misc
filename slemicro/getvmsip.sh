#!/bin/bash
set -euo pipefail

source common.sh

if [ $(uname -o) == "Darwin" ]; then
	VMS=$(osascript <<-END
	tell application id "com.utmapp.UTM"
		set vms to name of virtual machines
	end tell
	END
	)

	IFS=, read -a Array <<<"${VMS//, /,}"

	for vm in "${Array[@]}"; do
		VMMAC=$(osascript <<-END
		tell application id "com.utmapp.UTM"
			set vm to virtual machine named "${vm}"
			set config to configuration of vm
			get address of item 1 of network interfaces of config
		end tell
		END
		)
		VMIP=$(grep -i "${VMMAC}" -B1 -m1 /var/db/dhcpd_leases | head -1 | awk -F= '{ print $2 }')
		echo "${vm} ${VMIP}"
	done
elif [ $(uname -o) == "GNU/Linux" ]; then
	for vm in $(virsh list --name); do echo "${vm} $(virsh --connect qemu:///system domifaddr ${vm} | awk '/ipv4/ NF>1{print $NF}' | cut -d/ -f1)"; done  2> /dev/null
else
	die "Unsupported operating system" 2
fi
