#!/usr/bin/env bash
set -xeuo pipefail
BASEDIR="$(dirname "$0")"

die(){
  echo ${1}
  exit ${2}
}

# Get the env file
source ${BASEDIR}/.env

VMFOLDER="${VMFOLDER:-~/VMs}"

command -v butane > /dev/null 2>&1 || die "butane not found" 2
command -v mkisofs > /dev/null 2>&1 || die "mkisofs not found" 2
[ -f ${SLEMICROFILE} ] || die "SLE Micro image file not found" 2

mkdir -p ${VMFOLDER}

cp ${SLEMICROFILE} ${VMFOLDER}/${VMNAME}.raw

# Check if REGISTER is enabled or not
if [ "${REGISTER}" == true ]; then
  # Check if EMAIL and REGCODE variables are empty
  [ -z "${EMAIL}" ] && die "EMAIL variable not found" 2
  [ -z "${REGCODE}" ] && die "REGCODE variable not found" 2
fi

# Create a temp dir to host the assets
TMPDIR=$(mktemp -d)

# Create required folders
mkdir -p ${TMPDIR}/{combustion,ignition}

if [ -f ${BASEDIR}/butane/config.fcc ]; then
  # Convert the config.fcc yaml file to ignition
  butane -p -o ${TMPDIR}/ignition/config.ign ${BASEDIR}/config.fcc
fi

if [ -f ${BASEDIR}/ignition/config.ign ]; then
  cp ${BASEDIR}/config.ign ${TMPDIR}/ignition/config.ign
fi

if [ -f ${BASEDIR}/combustion/script ]; then
  # Copy the combustion script
  envsubst < ${BASEDIR}/script > ${TMPDIR}/combustion/script
fi

# Create an iso
mkisofs -full-iso9660-filenames -o ${VMFOLDER}/ignition-and-combustion.iso -V ignition ${TMPDIR}

# Remove leftovers
rm -Rf ${TMPDIR}

OUTPUT=$(
osascript <<END
tell application "UTM"
	--- specify a boot ISO
	set iso to POSIX file "${VMFOLDER}/ignition-and-combustion.iso"
	-- specify the RAW file
	set rawfile to POSIX file "${VMFOLDER}/${VMNAME}.raw"
	--- create a new QEMU VM 
	set vm to make new virtual machine with properties {backend:qemu, configuration:{cpu cores:${CPUS}, memory: ${MEMORY}, name:"${VMNAME}", architecture:"aarch64", drives:{{removable:true, source:iso}, {removable:false, source:rawfile}}}}
	start vm
	repeat
	  if status of vm is started then exit repeat
  end repeat
	get address of first serial port of vm
end tell
END
)

echo "VM started. You can connect to the serial terminal as:"
echo "screen ${OUTPUT}"

exit 0