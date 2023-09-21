#!/usr/bin/env bash
set -euo pipefail

source common.sh

usage(){
	cat <<-EOF
	Usage: ${0} [-f <path/to/variables/file>] [-n <vmname>]
	EOF
}

while getopts 'f:n:h' OPTION; do
	case "${OPTION}" in
		f)
			[ -f "${OPTARG}" ] && ENVFILE="${OPTARG}" || die "Parameters file ${OPTARG} not found" 2
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

set -a
# Get the env file
source ${ENVFILE:-${BASEDIR}/.env}
# Some defaults just in case
CPUS="${CPUS:-2}"
MEMORY="${MEMORY:-2048}"
DISKSIZE="${DISKSIZE:-30}"
SSHPUB="${SSHPUB:-${HOME}/.ssh/id_rsa.pub}"
VMNAME="${NAMEOPTION:-${VMNAME:-slemicro}}"
VM_STATIC_IP=${VM_STATIC_IP:-}
VM_STATIC_PREFIX=${VM_STATIC_PREFIX:-24}
VM_STATIC_GATEWAY=${VM_STATIC_GATEWAY:-"192.168.122.1"}
VM_STATIC_DNS=${VM_STATIC_DNS:-${VM_STATIC_GATEWAY}}
REGISTER="${REGISTER:-false}"
CERTMANAGERVERSION="${CERTMANAGERVERSION:-latest}"
RANCHERBOOTSTRAPSKIP="${RANCHERBOOTSTRAPSKIP:-false}"
CLUSTER="${CLUSTER:-false}"
COCKPIT="${COCKPIT:-false}"
RANCHERFLAVOR="${RANCHERFLAVOR:-false}"
UPDATEANDREBOOT="${UPDATEANDREBOOT:-false}"
QEMUGUESTAGENT="${QEMUGUESTAGENT:-false}"
DISABLEIPV6="${DISABLEIPV6:-true}"
EXTRADISKS="${EXTRADISKS:-false}"
VM_NETWORK=${VM_NETWORK:-default}
REBOOTMGR="${REBOOTMGR:-false}"
TRANSACTIONALUPDATES="${TRANSACTIONALUPDATES:-false}"
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
command -v butane > /dev/null 2>&1 || die "butane not found" 2
command -v mkisofs > /dev/null 2>&1 || die "mkisofs not found" 2
command -v qemu-img > /dev/null 2>&1 || die "qemu-img not found" 2

# Check if the SLEMicro image exist
[ -f ${SLEMICROFILE} ] || die "SLE Micro image file not found" 2

# Check if REGISTER is enabled or not
if [ "${REGISTER}" == true ]; then
	# Check if EMAIL and REGCODE variables are empty
	[ -z "${EMAIL}" ] && die "EMAIL variable not found" 2
	[ -z "${REGCODE}" ] && die "REGCODE variable not found" 2
fi

# Bootstraping rancher requires a few things
if [ "${RANCHERBOOTSTRAPSKIP}" == true ]; then
	# Bootstrapskip requires installing jq... hence registering :(
	if [ "${REGISTER}" == false ]; then
		die "RANCHERBOOTSTRAPSKIP requires REGISTER" 3
	fi
	# Check if RANCHERFINALPASSWORD exist
	if [[ -n "${RANCHERFINALPASSWORD}" && ${#RANCHERFINALPASSWORD} -lt 12 ]]; then
		die "RANCHERFINALPASSWORD variable needs to be >12 characters long" 3
	fi
fi

# qemu-guest-agent requires register as well
if [ "${REGISTER}" == false ] && [ "${QEMUGUESTAGENT}" == true ]; then
	die "QEMUGUESTAGENT requires REGISTER" 3
fi

# Check if cluster installation to set correct path to kubeconfig and kubectl
case ${CLUSTER} in
	"k3s")
  		export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  		export KUBECTL=/usr/local/bin/kubectl
  		export CLUSTER_INSTALL_SERVICE=k3s_installer.service
  		;;
	"rke2")
  		export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
  		export KUBECTL=/var/lib/rancher/rke2/bin/kubectl
  		export CLUSTER_INSTALL_SERVICE=rke2_installer.service
  		;;
	false)
		;;
	*)
		die "CLUSTER variable not supported" 2
		;;
esac

# Create the image file
mkdir -p ${VMFOLDER}
cp ${SLEMICROFILE} ${VMFOLDER}/${VMNAME}.raw
qemu-img resize -f raw ${VMFOLDER}/${VMNAME}.raw ${DISKSIZE}G > /dev/null

if [ "${EXTRADISKS}" != false ]; then
	DISKARRAY=(${EXTRADISKS//,/ })
	for (( i=0; i<"${#DISKARRAY[@]}"; i++ )); do
		qemu-img create -f raw ${VMFOLDER}/${VMNAME}-extra-disk-${i}.raw "${DISKARRAY[$i]}"G > /dev/null
	done
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
	# If a SSH key has been set, copy it as well
	if [ ! -z "${SSHPUB}" ] && [ -f "${SSHPUB}" ]; then
		export SSHCONFIG=true
		export SSHCONTENT=$(cat ${SSHPUB})
	fi

	# Parse the file and copy it to the final ISO
	envsubst < ${BASEDIR}/combustion/script > ${TMPDIR}/combustion/script
	
	# Copy all combustion related files to the final iso destination parsing the vars
	for file in ${BASEDIR}/combustion/*.sh; do
		FILENAME=$(basename ${file})
		envsubst < ${file} > ${TMPDIR}/combustion/${FILENAME}
		chmod a+x ${TMPDIR}/combustion/${FILENAME}
		echo "./${FILENAME}" >> ${TMPDIR}/combustion/script
	done
fi

# Create an iso
mkisofs -quiet -full-iso9660-filenames -o ${VMFOLDER}/ignition-and-combustion-${VMNAME}.iso -V ignition ${TMPDIR}

# Remove leftovers
rm -Rf ${TMPDIR}

# if x86_64, convert the image to qcow2
if [ $(uname -o) == "Darwin" ]; then
	
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
	UTMDISKMAPPING="{{removable:true, source:iso}, {removable:false, source:rawfile}${UTMEXTRADISKMAPPING}}"

	# Create and launch the VM using UTM
	OUTPUT=$(osascript <<-END
	tell application "UTM"
		--- specify a boot ISO
		set iso to POSIX file "${VMFOLDER}/ignition-and-combustion-${VMNAME}.iso"
		-- specify the RAW file
		set rawfile to POSIX file "${VMFOLDER}/${VMNAME}.raw"
		-- specify extra disks
		${UTMEXTRADISKS}
		--- create a new QEMU VM
		set vm to make new virtual machine with properties {backend:qemu, configuration:{cpu cores:${CPUS}, memory: ${MEMORY}, name:"${VMNAME}", architecture:"aarch64", drives:${UTMDISKMAPPING}}}
		start vm
		repeat
			if status of vm is started then exit repeat
		end repeat
		get address of first serial port of vm
	end tell
	END
	)

	echo "VM ${VMNAME} started. You can connect to the serial terminal as: screen ${OUTPUT}"

	OUTPUT=$(osascript <<-END
	tell application "UTM"
		set vm to virtual machine named "${VMNAME}"
		set config to configuration of vm
		get address of item 1 of network interfaces of config
	end tell
	END
	)

	VMMAC=$(echo $OUTPUT | sed 's/0\([0-9A-Fa-f]\)/\1/g')

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
	qemu-img convert -O qcow2 ${VMFOLDER}/${VMNAME}.raw ${VMFOLDER}/${VMNAME}.qcow2
	# The raw file is still there doing nothing
	rm -f ${VMFOLDER}/${VMNAME}.raw
	# Give libvirt group permissions for both the disk an the ISO
	chmod 0664 ${VMFOLDER}/${VMNAME}.qcow2 ${VMFOLDER}/ignition-and-combustion-${VMNAME}.iso
	chgrp libvirt ${VMFOLDER}/${VMNAME}.qcow2 ${VMFOLDER}/ignition-and-combustion-${VMNAME}.iso
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
		--cdrom ${VMFOLDER}/ignition-and-combustion-${VMNAME}.iso \
		--network network=${VM_NETWORK} \
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
			VMIP=$(vm_ip)
	done
else
	die "VM not deployed. Unsupported operating system" 2
fi

printf "\nVM IP: ${VMIP}\n"
[ ${COCKPIT} = true ] && echo "Cockpit Web UI available at https://${VMIP}.sslip.io:9090"
[ ${RANCHERFLAVOR} != false ] && echo "After Rancher is installed, you can access the Web UI as https://rancher-${VMIP}.sslip.io"
[ ${UPDATEANDREBOOT} = true ] && echo "The VM will be updated and rebooted if required, it can take a while"

exit 0
