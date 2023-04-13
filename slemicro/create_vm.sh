#!/usr/bin/env bash
set -euo pipefail
BASEDIR="$(dirname "$0")"

die(){
  echo ${1}
  exit ${2}
}

# Get the env file
source ${BASEDIR}/.env

VMFOLDER="${VMFOLDER:-~/VMs}"

# Check if UTM version is 4.2.2 (required for the scripting part)
ver(){ printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' '); }
UTMVERSION=$(/usr/libexec/plistbuddy -c Print:CFBundleShortVersionString: /Applications/UTM.app/Contents/info.plist)
[ $(ver ${UTMVERSION}) -lt $(ver 4.2.2) ] && die "UTM version >= 4.2.2 required" 2

# Check if the commands required exist
command -v butane > /dev/null 2>&1 || die "butane not found" 2
command -v mkisofs > /dev/null 2>&1 || die "mkisofs not found" 2
command -v qemu-img > /dev/null 2>&1 || die "qemu-img not found" 2

# Check if the SLEMicro image exist
[ -f ${SLEMICROFILE} ] || die "SLE Micro image file not found" 2

# Create the image file
mkdir -p ${VMFOLDER}
cp ${SLEMICROFILE} ${VMFOLDER}/${VMNAME}.raw
qemu-img resize -f raw ${VMFOLDER}/${VMNAME}.raw ${DISKSIZE}G > /dev/null

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

# If the butane file exists
if [ -f ${BASEDIR}/butane/config.fcc ]; then
  # Convert the config.fcc yaml file to ignition
  butane -p -o ${TMPDIR}/ignition/config.ign ${BASEDIR}/butane/config.fcc
fi

# If the ignition file exists
if [ -f ${BASEDIR}/ignition/config.ign ]; then
  # Copy it to the final iso destination
  cp ${BASEDIR}/ignition/config.ign ${TMPDIR}/ignition/config.ign
fi

# If the combustion script exists
if [ -f ${BASEDIR}/combustion/script ]; then
  # Copy it to the final iso destination parsing the vars
  envsubst < ${BASEDIR}/combustion/script > ${TMPDIR}/combustion/script
fi

# Create an iso
mkisofs -quiet -full-iso9660-filenames -o ${VMFOLDER}/ignition-and-combustion-${VMNAME}.iso -V ignition ${TMPDIR}

# Remove leftovers
rm -Rf ${TMPDIR}

# Create and launch the VM using UTM
OUTPUT=$(
osascript <<END
tell application "UTM"
	--- specify a boot ISO
	set iso to POSIX file "${VMFOLDER}/ignition-and-combustion-${VMNAME}.iso"
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

echo "VM started. You can connect to the serial terminal as: screen ${OUTPUT}"

OUTPUT=$(
osascript <<END
tell application "UTM"
  set vm to virtual machine named "${VMNAME}"
	set config to configuration of vm
	get address of item 1 of network interfaces of config
end tell
END
)

VMMAC=$(echo $OUTPUT | sed 's/^0*//')

timeout=180
count=0

echo -n "Waiting for IP: "
until grep -q -i "${VMMAC}" -B1 -m1 /var/db/dhcpd_leases | head -1 | awk -F= '{ print $2 }' | sed 's/0\([0-9A-Fa-f]\)/\1/g'; do
    count=$((count + 1))
    if [[ ${count} -ge ${timeout} ]]; then
        break
    fi
    sleep 1
    echo -n "."
done

echo ""

echo "VM IP: $(grep -i "${VMMAC}" -B1 -m1 /var/db/dhcpd_leases | head -1 | awk -F= '{ print $2 }' | sed 's/0\([0-9A-Fa-f]\)/\1/g')"

exit 0