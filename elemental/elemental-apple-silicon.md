# Elemental cluster on OSX using UTM

```
cat <<- EOF | kubectl apply -f -
apiVersion: elemental.cattle.io/v1beta1
kind: MachineInventorySelectorTemplate
metadata:
  name: my-machine-selector
  namespace: fleet-default
spec:
  template:
    spec:
      selector:
        matchExpressions:
          - key: location
            operator: In
            values: [ 'europe' ]
EOF

cat <<- EOF | kubectl apply -f -
kind: Cluster
apiVersion: provisioning.cattle.io/v1
metadata:
  name: my-cluster
  namespace: fleet-default
spec:
  rkeConfig:
    machineGlobalConfig:
      etcd-expose-metrics: false
      profile: null
    machinePools:
      - controlPlaneRole: true
        etcdRole: true
        machineConfigRef:
          apiVersion: elemental.cattle.io/v1beta1
          kind: MachineInventorySelectorTemplate
          name: my-machine-selector
        name: pool1
        quantity: 1
        unhealthyNodeTimeout: 0s
        workerRole: true
    machineSelectorConfig:
      - config:
          protect-kernel-defaults: false
    registries: {}
  kubernetesVersion: v1.24.8+k3s1
EOF

cat <<- 'EOF' | kubectl apply -f -
apiVersion: elemental.cattle.io/v1beta1
kind: MachineRegistration
metadata:
  name: my-nodes
  namespace: fleet-default
spec:
  config:
    cloud-config:
      users:
        - name: root
          passwd: root
    elemental:
      install:
        reboot: true
        device: /dev/vda
        debug: true
        disable-boot-entry: true
      registration:
        emulate-tpm: true
  machineInventoryLabels:
    manufacturer: "${System Information/Manufacturer}"
    productName: "${System Information/Product Name}"
    serialNumber: "${System Information/Serial Number}"
    machineUUID: "${System Information/UUID}"
EOF


curl -k $(kubectl get machineregistration -n fleet-default my-nodes -o jsonpath="{.status.registrationURL}") -o livecd-cloud-config.yaml

curl -Lk https://download.opensuse.org/repositories/isv:/Rancher:/Elemental:/Stable:/Teal53/images/rpi.raw -o rpi.raw

curl -Lk https://download.opensuse.org/repositories/isv:/Rancher:/Elemental:/Stable:/Teal53/images/rpi.raw.sha256 -o rpi.raw.sha256

sha256sum -c rpi.raw.sha256


IMAGE=rpi.raw
DEST=$(mktemp -d)

# Linux only
SECTORSIZE=$(sfdisk -J ${IMAGE} | jq '.partitiontable.sectorsize')
DATAPARTITIONSTART=$(sfdisk -J ${IMAGE} | jq '.partitiontable.partitions[1].start')
mount -o rw,loop,offset=$((${SECTORSIZE}*${DATAPARTITIONSTART})) ${IMAGE} ${DEST}
mv livecd-cloud-config.yaml ${DEST}/livecd-cloud-config.yaml
umount ${DEST}
```

Then, boot the VM with rpi.raw as USB and create a new device as virtio for the disk.

Once booted the first time it will reboot infinitely. It is required to stop the VM, remove the USB device and boot it again.

Then:

```
kubectl -n fleet-default label machineinventory $(kubectl get machineinventory -n fleet-default --no-headers -o custom-columns=":metadata.name") location=europe
```