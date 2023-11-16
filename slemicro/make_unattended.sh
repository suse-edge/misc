#!/usr/bin/env bash
set -euo pipefail

usage(){
	cat <<-EOF
	Usage: ${0} -i SLE-Micro-SelfInstall.iso [-o tweaked-SLE-Micro-SelfInstall.iso] [-d /dev/sda]
	
	Options:
	 -i		Path to the original SLE Micro iso file
	 -o		(Optional) Path to the tweaked-SLE-Micro-SelfInstall.iso file (./tweaked.iso by default)
	 -d		(Optional) Disk device where SLE Micro will be installed (if not provided, the first one that the installer finds)
	EOF
}

die(){
	echo "${1}" 1>&2
	exit "${2}"
}

while getopts 'i:o:d:h' OPTION; do
	case "${OPTION}" in
		i)
			if [ -f "${OPTARG}" ]; then
				INPUTISO="${OPTARG}"
			else
				die "Input ISO ${OPTARG} not found" 2
			fi
			;;
		o)
			if [ -d "$(dirname "${OPTARG}")" ]; then
				OUTPUTISO="${OPTARG}"
			else
				die "Output path $(dirname "${OPTARG}") not found" 2
			fi
			;;
		d)
			WRITETO="${OPTARG}"
			;;
		h)
			usage && exit 0
			;;
		?)
			usage && exit 2
			;;
	esac
done

# INPUTISO is mandatory
if [ -z "${INPUTISO:-}" ]; then
	usage && exit 2
fi

# OUTPUTISO defaults to ./tweaked.iso
OUTPUTISO="${OUTPUTISO:-./tweaked.iso}"

# Don't overwrite the destination
if [ -f ${OUTPUTISO} ]; then
	usage
	die "${OUTPUTISO} already exists" 2
fi

# Root needed by mount
[ "$(id -u)" -eq 0 ] || die "This script must be executed by root" 2

TMPDIR="$(mktemp -d -t make_unattended.XXXXXX)"
# shellcheck disable=SC2064
trap "rm -rf '$TMPDIR'" EXIT

# We mount the ISO and extract the files we need
mkdir -p "${TMPDIR}"/{orig,init}
mount "${INPUTISO}" "${TMPDIR}"/orig >/dev/null 2>&1
cp "${TMPDIR}"/orig/boot/x86_64/loader/initrd "${TMPDIR}"/init
cp "${TMPDIR}"/orig/boot/grub2/grub.cfg "${TMPDIR}"/grub.cfg-orig
umount "${TMPDIR}"/orig
rmdir "${TMPDIR}"/orig
chmod 666 "${TMPDIR}"/init/initrd

# The initrd contained in the iso is basically two cpios concatenated
# The first one contains the microcode essentially (early cpio):

# dd if=initrd-orig skip=0 | cpio -it
# .
# early_cpio
# kernel
# kernel/x86
# kernel/x86/microcode
# kernel/x86/microcode/AuthenticAMD.bin
# kernel/x86/microcode/GenuineIntel.bin
# 25782 blocks

# And the second one contains the filesystem compressed with zstd:

# dd if=./initrd-orig skip=25782 | zstd -dc | cpio -it
# .
# .profile
# bin
# bin/arping
# bin/awk
# bin/basename
# bin/bash
# bin/cat
# bin/chmod
# bin/chown
# bin/cp
# bin/date
# [... a lot more files ...]

# The .profile is the one used by kiwi to perform the installation
# We need to add the kiwi_oemunattended flag to it.
# There is also the kiwi_oemunattended_id https://github.com/OSInside/kiwi/blob/master/dracut/modules.d/90kiwi-dump/kiwi-dump-image.sh
# which we can use to specify the device we want to use to write the image into.

# First step is to extract the initrd filesystem content (the second cpio)
# pushd and popd commands are needed because lsinitrd doesn't have a way to extract the data than to the current folder
pushd "${TMPDIR}"/init > /dev/null
lsinitrd --unpack ./initrd
popd > /dev/null

# Then, in order to be able to recreate it, we need to get the first cpio as well
# We just list the content from it but we need stderr as this is where cpio prints the number of blocks written
# The usual cat initrd | cpio -it gives a pipefail (because of cat), so use -F instead (which should be better)
BLOCKS=$(cpio -itF "${TMPDIR}"/init/initrd 2>&1 | awk '/blocks/ { print $1 }')
dd if="${TMPDIR}"/init/initrd skip=0 count="${BLOCKS}" of="${TMPDIR}"/first >/dev/null 2>&1

# We have everything we need from initrd
rm -f "${TMPDIR}"/init/initrd

# We inject the unattended flag
echo "kiwi_oemunattended='true'" >> "${TMPDIR}"/init/.profile

# Specify the destination disk if present
if [ -n "${WRITETO:-}" ]; then
	echo "kiwi_oemunattended_id='${WRITETO}'" >> "${TMPDIR}"/init/.profile
fi

# This will generate the "second" cpio
pushd "${TMPDIR}"/init/ > /dev/null
find . | cpio -o -H newc -F "${TMPDIR}"/second 2>/dev/null
popd > /dev/null

# We can clean up the extracted one
rm -Rf "${TMPDIR}"/init

# Now we need to compress the filesystem
zstd -q "${TMPDIR}"/second
rm -f "${TMPDIR}"/second

# And create the proper initrd by concatenating both
cat "${TMPDIR}"/first "${TMPDIR}"/second.zst > "${TMPDIR}"/initrd
rm -f "${TMPDIR}"/first "${TMPDIR}"/second.zst

# This will remove the need to select "install" in grub
echo "set timeout=3" > "${TMPDIR}"/pre-grub.txt
echo "set timeout_style=menu" >> "${TMPDIR}"/pre-grub.txt
cat "${TMPDIR}"/pre-grub.txt "${TMPDIR}"/grub.cfg-orig > "${TMPDIR}"/grub.cfg
rm -f "${TMPDIR}"/pre-grub.txt "${TMPDIR}"/grub.cfg-orig

# Finally we create the iso replacing the initrd and grub.cfg files
xorriso -indev "${INPUTISO}" -outdev "${OUTPUTISO}" \
	-map "${TMPDIR}"/grub.cfg /boot/grub2/grub.cfg \
	-map "${TMPDIR}"/initrd /boot/x86_64/loader/initrd \
	-boot_image any replay > /dev/null 2>&1