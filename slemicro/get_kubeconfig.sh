#!/usr/bin/env bash
set -euo pipefail
BASEDIR="$(dirname "$0")"

die(){
	echo ${1} 1>&2
	exit ${2}
}

usage(){
	cat <<-EOF
	Usage: ${0} [-f <path/to/variables/file>] [-n <vmname>] [-i <ip>] [-w]
	
	Options:
	 -f		(Optional) Path to the variables file
	 -n		(Optional) Virtual machine name
	 -i		(Optional) Virtual machine IP
	 -w		(Optional) Wait for the API/Rancher to be available
	EOF
}

while getopts 'f:n:i:wh' OPTION; do
	case "${OPTION}" in
		f)
			[ -f "${OPTARG}" ] && ENVFILE="${OPTARG}" || die "Parameters file ${OPTARG} not found" 2
			;;
		n)
			VMNAME="${OPTARG}"
			;;
		i)
			VMIP="${OPTARG}"
			;;
		w)
			WAIT=true
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
VMNAME="${VMNAME:-slemicro}"
RANCHERFLAVOR="${RANCHERFLAVOR:-false}"
RANCHERFINALPASSWORD="${RANCHERFINALPASSWORD:-false}"
CLUSTER="${CLUSTER:-false}"
VMIP="${VMIP:-false}"
WAIT="${WAIT:-false}"
set +a

if [ ${VMIP} == false ]; then
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
		command -v virt-install > /dev/null 2>&1 || die "virt-install command not found" 2
		
		VMIP=$(virsh domifaddr ${VMNAME} | awk -F'[ /]+' '/ipv/ {print $5}' )
	else
		die "Unsupported operating system" 2
	fi
fi

# Create a temp file
TMPKUBECONFIG=$(mktemp)

if [ ${RANCHERFLAVOR} == false ]; then
	# via ssh
	case ${CLUSTER} in
		"k3s")
  		KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  		;;
		"rke2")
  		KUBECONFIG=/etc/rancher/rke2/rke2.yaml
  		;;
		false)
			die "CLUSTER cannot be false" 2
			;;
		*)
			die "CLUSTER variable not supported" 2
			;;
	esac
	if [ ${WAIT} == true ]; do
		while ! curl -sk https://${VMIP}:6443; do sleep 10; done
	fi
	# TODO: remove the hardcoded user
	scp root@${VMIP}:${KUBECONFIG} ${TMPKUBECONFIG}
	if [ $(uname -o) == "Darwin" ]; then
		sed -i "" "s/127.0.0.1/${VMIP}/g" ${TMPKUBECONFIG}
	elif [ $(uname -o) == "GNU/Linux" ]; then
		sed -i "s/127.0.0.1/${VMIP}/g" ${TMPKUBECONFIG}
	else
		echo "Kubeconfig sed not done, unsupported operating system" 1>&2
	fi

else
	if [ ${WAIT} == true ]; do
		while ! curl -sk https://${VMIP}.sslip.io; do sleep 10; done
	fi
	
	# via rancher
	[ ${RANCHERFINALPASSWORD} == false ] && die "RANCHERFINALPASSWORD not provided" 2

	# Check if the commands required exist
	command -v jq > /dev/null 2>&1 || die "jq not found" 2

	# Login
	TOKEN=$(curl -sk -X POST https://${VMIP}.sslip.io/v3-public/localProviders/local?action=login -H 'content-type: application/json' -d "{\"username\":\"admin\",\"responseType\": \"token\", \"password\": \"${RANCHERFINALPASSWORD}\"}" | jq -r .token)

	# Get the kubeconfig
	# TODO: The following API call creates a token that doesn't expire https://github.com/rancher/rancher/issues/37705
	GENERATEDKUBECONFIG=$(curl -sk "https://${VMIP}.sslip.io/v3/clusters/local?action=generateKubeconfig" -X 'POST' -H 'content-type: application/json' -H "Authorization: Bearer ${TOKEN}")
	echo ${GENERATEDKUBECONFIG} | jq -r .config > ${TMPKUBECONFIG}
fi

echo ${TMPKUBECONFIG}

exit 0
