# Example deployment of a SUSE Edge 3.3.1 downstream single-node cluster

You need to have sushy-emulator running for BMC management via libvirt (see the [create_vm.sh](https://github.com/suse-edge/misc/blob/main/baremetal_vm/create_vm.sh) script for inspiration)

- Find and replace the "REPLACEME" strings.
- Follow the SUSE Edge documentation on how to [Build an updated SUSE Linux Micro image](https://documentation.suse.com/suse-edge/3.3/html/edge/guides-kiwi-builder-images.html). You can use the "Base" profile.
- Drop the resulting image in the `base-images` folder.
- Create the EIB image as:

```
./create_eib.sh -e eib-examples/edge-331-downstream-cluster-single-node-metal3/ -f vm1-downstream
```

- Copy the raw image to a webserver and generate the sha256sum:

```
cp eib-examples/edge-331-downstream-cluster-single-node-metal3/331-downstream-cluster.raw /path/to/my/webserver/files/
pushd /path/to/my/webserver/files/
sha256sum 331-downstream-cluster.raw > 331-downstream-cluster.raw.sha256
popd
```

- Create an empty VM:

```
./create_empty_vm.sh -f vm1-downstream -s "40"
```

- The VM will be provisioned by the [management cluster](../edge-331-mgmt-cluster-metal3)

The vm1-downstream file looks like:

```
VMFOLDER="/var/lib/libvirt/images/"
VMNAME="vm1-downstream"
CPUS="8"
MEMORY="10240"
MACADDRESS="00:00:00:10:01:01"
LIBVIRT_DISK_SETTINGS="bus=virtio,cache=unsafe"
EIB_IMAGE="registry.suse.com/edge/3.3/edge-image-builder:1.2.1"
```

Please adjust to your enviornment according to your needs.
