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
		for disk in $(lsblk -l -o NAME,TYPE -n | awk '/disk/ { print $$1 }' | grep -v vda); do
			# Create a single partition for the whole disk
			sfdisk /dev/$${disk} <<- EOF
			label: gpt
			type=linux
			EOF
			PARTITION="/dev/$${disk}1"
			# Remove all the previous content (probably not needed)
			wipefs --all $${PARTITION}
			# Create a PV on top of the partition
			lvm pvcreate $${PARTITION}
			# Add it to the list of PVs so vgcreate can be easily executed
			PVS+=" $${PARTITION}"
		done
		# Create a VG with all the PVs
		lvm vgcreate $${VGNAME} $${PVS}
		# A LV with all the free space, -Z is needed because there is no udev it seems
		# https://serverfault.com/questions/827251/cannot-do-lvcreate-not-found-device-not-cleared-on-centos
		lvm lvcreate -Zn -l 100%FREE -n $${LVNAME} $${VGNAME}
		mkfs.ext4 /dev/mapper/$${VGNAME}-$${LVNAME}
		mkdir -p $${MOUNTPOINT}
		echo "/dev/mapper/$${VGNAME}-$${LVNAME}	$${MOUNTPOINT} ext4 noatime 0 0" >> /etc/fstab
		mount $${MOUNTPOINT}
	else
		echo "TBD"
	fi
fi
