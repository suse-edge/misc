#!/bin/bash
set -euo pipefail

# Undocumented variable for now :)
ALLTOLONGHORN=${ALLTOLONGHORN:-false}

if [ "${EXTRADISKS}" != false ]; then
	if [ "${ALLTOLONGHORN}" == true ]; then
		VGNAME="vg_longhorn"
		LVNAME="storage"
		MOUNTPOINT="/var/lib/longhorn"
		# This is need to create the previous mountpoint
		mount /var || true
		for disk in $(lsblk -l -o NAME,TYPE -n | awk '/disk/ { print $1 }' | grep -v vda); do
			# Create a single partition for the whole disk
			# The double (!) dollar sign is because envsubst _removes_ the first one, then the extra one is for the 'EOF'
			sfdisk /dev/$${q}{disk} <<- EOF
			label: gpt
			type=linux
			EOF
			PARTITION="/dev/$${q}{disk}1"
			# Remove all the previous content (probably not needed)
			wipefs --all $${q}{PARTITION}
			# Create a PV on top of the partition
			lvm pvcreate $${q}{PARTITION}
			# Add it to the list of PVs so vgcreate can be easily executed
			PVS+=" $${q}{PARTITION}"
		done
		# Create a VG with all the PVs
		lvm vgcreate $${q}{VGNAME} $${q}{PVS}
		# A LV with all the free space, -Z is needed because there is no udev it seems
		# https://serverfault.com/questions/827251/cannot-do-lvcreate-not-found-device-not-cleared-on-centos
		lvm lvcreate -Zn -l 100%FREE -n $${q}{LVNAME} $${q}{VGNAME}
		mkfs.ext4 /dev/mapper/$${q}{VGNAME}-$${q}{LVNAME}
		mkdir -p $${q}{MOUNTPOINT}
		echo "/dev/mapper/$${q}{VGNAME}-$${q}{LVNAME}	$${q}{MOUNTPOINT} ext4 noatime 0 0" >> /etc/fstab
		mount $${q}{MOUNTPOINT}
	else
		echo "TBD"
	fi
fi
