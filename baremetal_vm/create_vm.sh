#!/bin/bash

set -euxo pipefail

source ../slemicro/common.sh
source common.sh

IMG_TO_USE=${IMG_TO_USE:-}

while getopts 'f:n:h' OPTION; do
	case "${OPTION}" in
		f)
			[ -f "${OPTARG}" ] && ENVFILE="${OPTARG}" || die "Parameters file ${OPTARG} not found" 2
			;;
		n)
			VMNAME="${OPTARG}"
			;;
		h)
			usage && exit 0
			;;
		?)
			usage && exit 2
			;;
	esac
done

if [ ! -d "${VMFOLDER}" ]; then
	mkdir ${VMFOLDER}
fi

# FIXME shardy workaround for DNS issues
IRONIC_HOST=${IRONIC_HOST:-$(vm_ip ${CLUSTER_VMNAME})}
if [ -z "${IRONIC_HOST}" ]; then
	die "Could not detect IRONIC_HOST - either set variable or ensure CLUSTER_VMNAME refers to a running VM"
fi

cd ${VMFOLDER}

echo "Creating virtual baremetal host"

qemu-img create -f qcow2 $VMNAME.qcow2 30G
#virt-install --name $VMNAME --memory 4096 --vcpus 2 --disk $VMNAME.qcow2 --boot uefi --import --network network=${VM_NETWORK} --osinfo detect=on --noautoconsole --print-xml 1 > $VMNAME.xml
virt-install --name $VMNAME --memory 4096 --vcpus 2 --disk $VMNAME.qcow2,bus=virtio --import --network network=${VM_NETWORK} --osinfo detect=on --noautoconsole --print-xml 1 > $VMNAME.xml
virsh define $VMNAME.xml

echo "Finished creating virtual node"
echo "Starting sushy-tools and httpd file server"

mkdir -p sushy-tools/
cat << EOF > sushy-tools/sushy-emulator.conf
SUSHY_EMULATOR_LISTEN_IP = u'0.0.0.0'
SUSHY_EMULATOR_LISTEN_PORT = 8000
SUSHY_EMULATOR_SSL_CERT = None
SUSHY_EMULATOR_SSL_KEY = None
SUSHY_EMULATOR_OS_CLOUD = None
SUSHY_EMULATOR_LIBVIRT_URI = u'qemu:///system'
SUSHY_EMULATOR_IGNORE_BOOT_DEVICE = True
EOF

# run sushy-tools via podman if it's not already running
if [ $(sudo podman ps -f status=running -f name=sushy-tools -q | wc -l) -ne 1 ];then
  sudo podman run -d --rm --net host --privileged --name sushy-tools \
  --add-host boot.ironic.suse.baremetal:${IRONIC_HOST} --add-host api.ironic.suse.baremetal:${IRONIC_HOST} --add-host inspector.ironic.suse.baremetal:${IRONIC_HOST} \
  -v ./sushy-tools/sushy-emulator.conf:/etc/sushy/sushy-emulator.conf:Z \
  -v /var/run/libvirt:/var/run/libvirt:Z \
  -e SUSHY_EMULATOR_CONFIG=/etc/sushy/sushy-emulator.conf \
  -p 8000:8000 \
  quay.io/metal3-io/sushy-tools:latest sushy-emulator

  if [ "${VM_NETWORK}" != "default" ]; then
    # Open firewall to enable VM -> sushy access via the libvirt bridge
    sudo firewall-cmd --add-port=8000/tcp --zone libvirt
    sudo firewall-cmd --list-all --zone libvirt
  fi
fi
echo "Finished starting sushy-tools podman"

# Optionally cache an OS image for the BMH to reference
mkdir -p bmh-image-cache
IMG_FILENAME=$(basename ${IMG_TO_USE})
if [ ! -f bmh-image-cache/${IMG_FILENAME} ]; then
  curl -Lk ${IMG_TO_USE} > bmh-image-cache/${IMG_FILENAME}
  pushd bmh-image-cache
  md5sum ${IMG_FILENAME} | tee ${IMG_FILENAME}.md5sum
  popd
fi

if [ $(sudo podman ps -f status=running -f name=bmh-image-cache -q | wc -l) -ne 1 ]; then
  sudo podman run -dit --name bmh-image-cache -p 8080:80 -v ./bmh-image-cache:/usr/local/apache2/htdocs/ docker.io/library/httpd:2.4
  if [ "${VM_NETWORK}" != "default" ]; then
    # Open firewall to enable VM -> cache access via the libvirt bridge
    sudo firewall-cmd --add-port=8080/tcp --zone libvirt
    sudo firewall-cmd --list-all --zone libvirt
  fi
fi
echo "Finished starting sushy-tools podman"


# Get the IP of the libvirt bridge for VM_NETWORK
VIRTHOST_BRIDGE=$(virsh net-info ${VM_NETWORK} | awk '/^Bridge/ {print $2}')
IP_ADDR=$(ip -f inet addr show ${VIRTHOST_BRIDGE} | sed -En -e 's/.*inet ([0-9.]+).*/\1/p')

# We automatically grab the mac address of each vm and the sushy-tools id of each vm
NODEID=$(curl -L http://$IP_ADDR:8000/redfish/v1/Systems/$VMNAME -k | jq -r '.UUID')
echo "Node UUID: $NODEID"

NODEMAC=$(virsh dumpxml $VMNAME | grep 'mac address' | grep -ioE "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}")
echo "Node MAC: $NODEMAC"

# We create custom BMH yamls using the data we collected earlier
# Note the metadata name must be in lowercase
BMH_NAME=$(echo "${VMNAME}" | tr '[:upper:]' '[:lower:]')
echo "Creating the BMH resource yaml file to the output vbmc folder"
cat << EOF > $VMNAME.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${BMH_NAME}-credentials
  namespace: default
type: Opaque
data:
  username: Zm9vCg==
  password: Zm9vCg==
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: ${BMH_NAME}
  namespace: default
  labels:
    cluster-role: control-plane
spec:
  online: true
  image:
    url: "http://$IP_ADDR:8080/${IMG_FILENAME}"
    checksum: "http://$IP_ADDR:8080/${IMG_FILENAME}.md5sum"
  bootMACAddress: $NODEMAC
  bootMode: legacy
  rootDeviceHints:
    deviceName: ${DEVICE_HINT}
  bmc:
    address: redfish-virtualmedia+http://$IP_ADDR:8000/redfish/v1/Systems/$NODEID
    disableCertificateVerification: true
    credentialsName: ${BMH_NAME}-credentials
EOF

echo "Done - now kubectl apply -f ${VMFOLDER}/$VMNAME.yaml"
