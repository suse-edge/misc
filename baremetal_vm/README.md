<div align="center">

# SUSE Edge misc

<p align="center">
  <img alt="SUSE Logo" src="https://www.suse.com/assets/img/suse-white-logo-green.svg" height="140" />
  <h3 align="center">SUSE Edge misc</h3>
</p>

| :warning: **This is an unofficial and unsupported repository. See the [official documentation](https://www.suse.com/solutions/edge-computing/).** |
| --- |

</div>

- [create\_vm.sh](#create_vmsh)
  - [Prerequisites](#prerequisites)
  - [Enviroment variables](#enviroment-variables)
  - [Usage](#usage)
  - [Troubleshooting](#troubleshooting)
- [delete\_vm.sh](#delete_vmsh)
  - [Prerequisites](#prerequisites-1)
  - [Enviroment variables](#enviroment-variables-1)
  - [Usage](#usage-1)

## create_vm.sh

This script creates a VM to emulate a bare-metal host, intended for developer testing of Metal<sup>3</sup>

### Prerequisites

* Currently only works with libvirt on Linux, libvirt is assumed to be installed and operational.
* Helm should be locally installed
* Existing management cluster/node (see below)
* Metal<sup>3</sup> chart installed (see below)

#### Deploying management cluster/node

A k8s cluster must be running to host the Metal<sup>3</sup> services, this can be deployed via the [slemicro scripts](./slemicro/README.md)

After the cluster is running we require some DNS names to reference the VM IP (assuming a single-node k3s cluster), so that the
BareMetalHost VMs created in the following steps can resolve the Ironic endpoints.

This can be achieved by updating the libvirt network for the VMs (either `default` or that referred to via `VM_NETWORK`):

```
> ./get_ip.sh
192.168.122.116

> cat > /tmp/dns.xml << EOF
<host ip='192.168.122.116'>
  <hostname> boot.ironic.suse.baremetal </hostname>
  <hostname> api.ironic.suse.baremetal </hostname>
  <hostname> inspector.ironic.suse.baremetal </hostname>
  <hostname> media.suse.baremetal </hostname>
</host>
EOF
> virsh net-update default add --section dns-host --xml dns.xml --live
```

#### Metal<sup>3</sup> chart installation

The metal3 chart can be installed with a minimal configuration via the following steps:

Note this assumes that kubectl is configured e.g via the `KUBECONFIG` variable to connect to the management cluster created in the previous step.

First enable the charts repo and create a values file which disables the provisioning network:

```
helm repo add suse-edge https://suse-edge.github.io/charts
helm repo update

cat > disable_provnet.yaml <<EOF
global:
  enable_dnsmasq: false
  enable_pxe_boot: false
  provisioningInterface: ""
  provisioningIP: ""
  enable_metal3_media_server: false
EOF
```

Then install the chart from the same directory, using the values file:

```
helm install metal3 suse-edge/metal3 -f ./disable_provnet.yaml
```

After some time this should result in a running Metal<sup>3</sup> deployment:

```
> kubectl get pods
NAME                                                    READY   STATUS    RESTARTS   AGE
baremetal-operator-controller-manager-d6b4fcb69-zxpxr   2/2     Running   0          27m
metal3-metal3-external-dns-59667c9c85-qh9st             1/1     Running   0          27m
metal3-metal3-ironic-854c76c9f9-8qk5p                   4/4     Running   0          27m
metal3-metal3-mariadb-6db7c7dd5f-ktjpg                  1/1     Running   0          27m
metal3-metal3-powerdns-59cf76f57d-bk5sf                 2/2     Running   0          27m

```

### Enviroment variables

Variables can be stored in the script basedir as `.env` or in any file and use the `-f path/to/the/variables` flag.

* `VMNAME` can be used to override the default VM name (or use the `-n` option)
* `VM_NETWORK` can be used to specify an alternative libvirt network if you are not using `default`
* `VMFOLDER` can be used to specify an alternative location for the VM images - if you change this ensure that libvirt has file and selinux permissions to access
* `CLUSTER_VMNAME` can be used to specify the VM hosting the management cluster (assuming a single VM e.g running k3s)
* `CPUS` specifies the number of VCPUS to configure for the VM
* `MEMORY` specifies the amount of memory to configure for the VM
* `DISKSIZE` specifies the disk size to configure for the VM
* `IMG_TO_USE` specifies an image to locally cache and use for provisioning
  * One option is `https://download.opensuse.org/pub/opensuse/distribution/leap/15.4/appliances/openSUSE-Leap-15.4-Minimal-VM.x86_64-OpenStack-Cloud.qcow2`

NOTE: Also see the [env.example](env.example) file for an example config with all options.

### Usage

```bash
$ ./create_vm.sh
...
Done - now kubectl apply -f /var/lib/libvirt/images/BaremetalHost.yaml
```

At this point you should have a new VM defined (but not running, check with `virsh list -a`)

You can also verify the redfish endpoint provided by the `sushy-tools` container is functioning, get the redfish URL from the yaml file output by `create_vm.sh`, then use curl e.g:

```
$ grep address /var/lib/libvirt/images/BaremetalHost.yaml
    address: redfish-virtualmedia+http://192.168.122.1:8000/redfish/v1/Systems/c42def9e-9f16-4aa3-bf0c-d97df0f80a85
$ curl -s http://192.168.122.1:8000/redfish/v1/Systems/c42def9e-9f16-4aa3-bf0c-d97df0f80a85 | jq .Name
"BaremetalHost"
```

Now you can apply the yaml file to provision the Metal<sup>3</sup> BareMetalHost:

```
$ kubectl apply -f /var/lib/libvirt/images/BaremetalHost.yaml

$ kubectl get bmh
NAME                   STATE        CONSUMER   ONLINE   ERROR   AGE
baremetalhost   inspecting              true             19s

# Some time later provisioning should be completed, this may take several minutes
$ kubectl get bmh
NAME                   STATE         CONSUMER   ONLINE   ERROR   AGE
baremetalhost   provisioned              true             3m3s
```

* To better understand the BMH states, refer to the [upstream state-machine docs](https://github.com/metal3-io/baremetal-operator/blob/main/docs/baremetalhost-states.md)
* Refer to the upstream API docs for details of the [BareMetalHost API](https://github.com/metal3-io/baremetal-operator/blob/main/docs/api.md)

### Troubleshooting

* `kubectl get bmh -o yaml` to view details of the BMH resource state
* `virsh console <VMNAME>` to view primary console output (particularly useful if the BMH is stuck inspecting/provisioning so the IPA ramdisk logs can be viewed)


## delete_vm.sh

This script is intended to easily delete the VM created with the `create_vm.sh` script.

You can use the same `-f` or `-n` parameters as well.

:warning: There is no confirmation whatsoever!

### Prerequisites

* Currently only works with libvirt on Linux

### Enviroment variables

The previous environment variables can be used but it requires a few less.

### Usage

```bash
$ ./delete_vm.sh
```
