# Example deployment of a SUSE Edge 3.3.1 management cluster

- Find and replace the "REPLACEME" strings.
- Follow the SUSE Edge documentation on how to [Build an updated SUSE Linux Micro image](https://documentation.suse.com/suse-edge/3.3/html/edge/guides-kiwi-builder-images.html). You can use the "Base" profile.
- Drop the resulting image in the `base-images` folder.
- Create the Management Cluster as:

```
./create_eib.sh -e eib-examples/edge-331-mgmt-cluster-metal3/ -f vm1
for vm in vm1 vm2 vm3 ; do
  ./create_vm_with_image.sh -i eib-examples/edge-331-mgmt-cluster-metal3/331-mgmt-cluster.raw -f ${vm}
done
```

The vm files look like:

```
VMFOLDER="/var/lib/libvirt/images/"
VMNAME="vm1"
CPUS="10"
MEMORY="10240"
# +1 to the latest octet per VM
MACADDRESS="00:00:00:00:01:01"
LIBVIRT_DISK_SETTINGS="bus=virtio,cache=unsafe"
EIB_IMAGE="registry.suse.com/edge/3.3/edge-image-builder:1.2.1"
```

Please adjust to your enviornment according to your needs.
