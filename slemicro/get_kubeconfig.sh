#!/usr/bin/env bash
set -euo pipefail

source common.sh

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
			NAMEOPTION="${OPTARG}"
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
VMNAME="${NAMEOPTION:-${VMNAME:-slemicro}}"
RANCHERFLAVOR="${RANCHERFLAVOR:-false}"
RANCHERFINALPASSWORD="${RANCHERFINALPASSWORD:-false}"
CLUSTER="${CLUSTER:-false}"
VMIP="${VMIP:-false}"
WAIT="${WAIT:-false}"
set +a

if [ ${VMIP} == false ]; then
	VMIP=$(vm_ip)
	if [ -z "${VMIP}" ]; then
		echo "Could not detect IP for VM ${VMNAME}"
		exit 1
	fi
fi

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
	if [ ${WAIT} == true ]; then
		# Wait until K3s API answer back with 401 unauthorized code
		while ! [ "$(curl -s -w '%{http_code}' -k -o /dev/null https://${VMIP}:6443)" -eq 401 ]; do sleep 10; done
	fi
	# Create a temp file
	TMPKUBECONFIG=$(mktemp)
	# TODO: remove the hardcoded user
	scp root@${VMIP}:${KUBECONFIG} ${TMPKUBECONFIG} > /dev/null
	if [ $(uname -o) == "Darwin" ]; then
		sed -i "" "s/127.0.0.1/${VMIP}/g" ${TMPKUBECONFIG}
	elif [ $(uname -o) == "GNU/Linux" ]; then
		sed -i "s/127.0.0.1/${VMIP}/g" ${TMPKUBECONFIG}
	else
		echo "Kubeconfig sed not done, unsupported operating system" 1>&2
	fi

else
	# via rancher
	[ ${RANCHERFINALPASSWORD} == false ] && die "RANCHERFINALPASSWORD not provided" 2
	# Check if the commands required exist
	command -v jq > /dev/null 2>&1 || die "jq not found" 2

	RANCHERHOSTNAME="rancher-${VMIP}.sslip.io"

	if [ ${WAIT} == true ]; then
		# Wait until Rancher API answer back with healthz 200
		while ! [ "$(curl -s -w '%{http_code}' -k -o /dev/null https://${RANCHERHOSTNAME}/healthz)" -eq 200 ]; do sleep 10; done
	fi
	
	TOKEN="null"
	# Prevent a race condition while the rancher bootstrap is being applied
	while [ ${TOKEN} == "null" ]; do
		sleep 5
		# Login
		TOKEN=$(curl -sk -X POST https://${RANCHERHOSTNAME}/v3-public/localProviders/local?action=login -H 'content-type: application/json' -d "{\"username\":\"admin\",\"responseType\": \"token\", \"password\": \"${RANCHERFINALPASSWORD}\"}" | jq -r .token)
	done

	# Create a temp file
	TMPKUBECONFIG=$(mktemp)
	# Get the kubeconfig
	# TODO: The following API call creates a token that doesn't expire https://github.com/rancher/rancher/issues/37705
	curl -sk "https://${RANCHERHOSTNAME}/v3/clusters/local?action=generateKubeconfig" -X 'POST' -H 'content-type: application/json' -H "Authorization: Bearer ${TOKEN}" | jq -r .config > ${TMPKUBECONFIG} 
fi

echo ${TMPKUBECONFIG}

exit 0
