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
- [delete\_vm.sh](#delete_vmsh)
  - [Prerequisites](#prerequisites-1)
  - [Enviroment variables](#enviroment-variables-1)
  - [Usage](#usage-1)
- [get\_kubeconfig.sh](#get_kubeconfigsh)
  - [Prerequisites](#prerequisites-2)
  - [Enviroment variables](#enviroment-variables-2)
  - [Usage](#usage-2)
- [get\ip.sh](#get_ip)
  - [Prerequisites](#prerequisites-2)
  - [Enviroment variables](#enviroment-variables-2)
  - [Usage](#usage-2)
- [What's next?](#whats-next)

## create_vm.sh

This script creates a SLE Micro aarch64 VM on OSX using UTM and it is customized using ignition/combustion.

The script will output the virtual terminal to connect to (using `screen` if needed) as well as the
IP that it gets from the OSX DHCPD service.

K3s or RKE2 and Rancher are optionally installed. Rancher access is configured with sslip.io and with a custom bootstrap password.

### Prerequisites

* `butane`
* `mkisofs`
* `qemu-img`

NOTE: They can be installed using `brew`. `envsubst` is available via the `gettext` package.

* [UTM 4.2.2](https://docs.getutm.app/) or higest (required for the scripting part)

* SLE Micro raw image.
  * Download the raw image file from the SUSE website at https://www.suse.com/download/sle-micro/
  * Select ARM or X86_64 architecture (depending on the Operating system of the host)
  * Look for the raw file (I.e.- `SLE-Micro.aarch64-5.3.0-Default-GM.raw.xz`)
  * Note: SLE Micro RT image (I.e.- `SLE-Micro.aarch64-5.3.0-Default-RT-GM.raw.xz`) can be used as well.

### Enviroment variables

It requires a few enviroment variables to be set to customize it, the bare minimum are (see [env-minimal.example](env-minimal.example)):

```
# SLE Micro image
SLEMICROFILE="${HOME}/Downloads/SLE-Micro.aarch64-5.3.0-Default-GM.raw"
# Folder where the VM will be hosted
VMFOLDER="${HOME}/VMs"
```

They can be stored in the script basedir as `.env` or in any file and use the `-f path/to/the/variables` flag.

**NOTE**: There is a `vm*` pattern already in the `.gitignore` file so you can conviniently name your VM parameters file as `vm-foobar` and they won't be added to git. 

```bash
cat << EOF > ${BASEDIR}/.env
# If required to register to https://scc.suse.com
REGISTER=true
# Email & regcode for the registration
EMAIL="foo@bar.com"
REGCODE="ASDF-1"
# SLE Micro image
SLEMICROFILE="${HOME}/Downloads/SLE-Micro.aarch64-5.3.0-Default-GM.raw"
# Folder where the VM will be hosted
VMFOLDER="${HOME}/VMs"
# VM & Hostname
VMNAME="SLEMicro"
# Selfexplanatory
CPUS=4
MEMORY=4096
DISKSIZE=30
# Extra disks (only OSX for now)
EXTRADISKS="30,10"
# Location of the ssh key file to be copied to /root/.ssh/authorized_keys
SSHPUB="${HOME}/.ssh/id_rsa.pub"
# Enable KUBEVIP to manage a VIP for K3s API
KUBEVIP=true
# Set the VIP
VIP="192.168.205.10"
# Set it to false if you don't want K3s or rke2 to be deployed ["k3s"|"rke2"|false]
CLUSTER="k3s"
# Specify a k3s or rke2 cluster version ["v1.25.8+k3s1"|"v1.25.9+rke2r1"]
INSTALL_CLUSTER_VERSION="v1.25.8+k3s1"
# For the first node in an HA environment. This INSTALL_CLUSTER_EXEC will be translated to INSTALL_K3S_EXEC or INSTALL_RKE2_EXEC depending on the value of CLUSTER
# INSTALL_CLUSTER_EXEC="server --cluster-init --write-kubeconfig-mode=644 --tls-san=${VIP} --tls-san=${VIP}.sslip.io"
# For a single node. This INSTALL_CLUSTER_EXEC will be translated to INSTALL_K3S_EXEC or INSTALL_RKE2_EXEC depending on the value of CLUSTER
INSTALL_CLUSTER_EXEC="server --cluster-init --write-kubeconfig-mode=644"
# To add control plane nodes. This INSTALL_CLUSTER_EXEC will be translated to INSTALL_K3S_EXEC or INSTALL_RKE2_EXEC depending on the value of CLUSTER:
# INSTALL_CLUSTER_EXEC="server --server https://${VIP}:6443 --write-kubeconfig-mode=644"
# To add worker nodes. This INSTALL_CLUSTER_EXEC will be translated to INSTALL_K3S_EXEC or INSTALL_RKE2_EXEC depending on the value of CLUSTER:
# INSTALL_CLUSTER_EXEC="agent --server https://${VIP}:6443"
# Cluster token to be used to add more hosts and it will be translated to K3S_TOKEN or RKE2_TOKEN depending on the value of CLUSTER
CLUSTER_TOKEN="foobar"
# Set it to the Rancher flavor you want to install "stable", "latest", "alpha", "prime" or just false to disable it
RANCHERFLAVOR="latest"
# Use latest cert-manager version or a custom one (as prerequisite for Rancher)
# https://ranchermanager.docs.rancher.com/getting-started/quick-start-guides/deploy-rancher-manager/helm-cli#install-rancher-with-helm
CERTMANAGERVERSION="latest"
# Initial Rancher bootstrap password
RANCHERBOOTSTRAPPASSWORD="admin"
# Enable to skip the rancher bootstrap phase
RANCHERBOOTSTRAPSKIP="true"
# Final Rancher password
RANCHERFINALPASSWORD="adminadminadmin"
# Set it to sync the VM clock.
QEMUGUESTAGENT=true
# Enable cockpit
COCKPIT=true
# Enable podman
PODMAN=true
# Update to latest packages and reboot if needed (zypper needs-reboot)
UPDATEANDREBOOT=true
# Disable IPv6
DISABLEIPV6=true
# Disable the rebootmgr service
REBOOTMGR=false
# Disable the transactional-updates timers
TRANSACTIONALUPDATES=false
# To test registration with elemental
# Requires latest elemental which includes [this change](https://github.com/rancher/elemental-operator/pull/516)
ELEMENTAL_REGISTER=true
# Configuration file downloaded from elemental MachineRegistration
# Contains the registration URL and cert to connect to elemental
ELEMENTAL_CONFIG="$HOME/Downloads/test_registrationURL.yaml"
EOF
```

NOTE: See the [env.example](env.example) file for an always up-to-date list of variables.

### Usage

```bash
$ ./create_vm.sh
VM started. You can connect to the serial terminal as: screen /dev/ttys001
Waiting for IP: ................
VM IP: 192.168.206.60
After Rancher is installed, you can access the Web UI as https://rancher-192.168.206.60.sslip.io
```

You could also use the `-f` parameter to specify a path where the variables are stored or `-n` to override the name of the VM to be used:

```bash
$ ./create_vm.sh -h
Usage: ./create_vm.sh [-f <path/to/variables/file>] [-n <vmname>]
```

### Multiple VMs

Using the `-f` flag, you can have multiple VM parameter files and create a cluster easily:

```bash
$ grep ^INSTALL_CLUSTER_EXEC vm-*
vm-master-0:INSTALL_CLUSTER_EXEC="server --cluster-init --write-kubeconfig-mode=644 --tls-san=${VIP} --tls-san=${VIP}.sslip.io"
vm-master-1:INSTALL_CLUSTER_EXEC="server --server https://192.168.205.10:6443 --write-kubeconfig-mode=644"
vm-master-2:INSTALL_CLUSTER_EXEC="server --server https://192.168.205.10:6443 --write-kubeconfig-mode=644"
vm-worker-0:INSTALL_CLUSTER_EXEC="agent --server https://192.168.205.10:6443"
vm-worker-1:INSTALL_CLUSTER_EXEC="agent --server https://192.168.205.10:6443"

for file in vm-*; do ./create_vm.sh -f ${file}; done

# after a while

master-0:~ # kubectl get nodes
NAME       STATUS   ROLES                       AGE   VERSION
master-0   Ready    control-plane,etcd,master   99s   v1.25.9+k3s1
master-1   Ready    control-plane,etcd,master   51s   v1.25.9+k3s1
master-2   Ready    control-plane,etcd,master   37s   v1.25.9+k3s1
worker-0   Ready    <none>                      25s   v1.25.9+k3s1
worker-1   Ready    <none>                      15s   v1.25.9+k3s1
```

**TIP:** To run the VM creation in parallel you can use `for file in vm-*; do ./create_vm.sh -f ${file} &; done; wait` (the output will be a little bit messy however)

### Static IPs

It is possible to deploy a VM with a static IP by setting the `VM_STATIC_IP` variable.

Optionally additional configuration may be specified:
* `VM_STATIC_GATEWAY` (defaults to `192.168.122.1`).
* `VM_STATIC_PREFIX` (defaults to `24`).
* `VM_STATIC_DNS` (defaults to the value of `VM_STATIC_GATEWAY`).

Note that in this configuration you must first disable DHCP for your libvirt network, which can be achieved via `virsh net-edit` to remove the `<dhcp>` stanza, then `virsh net-destroy` followed by `virsh net-start`

## delete_vm.sh

This script is intended to easily delete the previously SLE Micro VM created with the `create_vm.sh` script.

You can use the same `-f` or `-n` parameters as well.

:warning: There is no confirmation whatsoever!

### Prerequisites

* [UTM 4.2.2](https://docs.getutm.app/) or higest (required for the scripting part)

### Enviroment variables

The previous environment variables can be used but it requires a few less.

### Usage

```bash
$ ./delete_vm.sh
```

```bash
$ ./delete_vm.sh -h
Usage: ./delete_vm.sh [-f <path/to/variables/file>] [-n <vmname>]
```

For multiple VMs:

```bash
for file in vm-*; do ./delete_vm.sh -f ${file}; done
```

For multiple VMs in parallel:

```bash
for file in vm-*; do ./delete_vm.sh -f ${file} &; done; wait
```

## get_kubeconfig.sh

This script is intended to easily get the Kubeconfig file of the K3s/RKE2 cluster created with the `create_vm.sh` script.

If Rancher is not deployed, it tries to get the Kubeconfig file via ssh, otherwise it leverages the Rancher API.

You can use the same `-f` or `-n` parameters as well, an extra `-i` parameter to specify the IP manually or the `-w` flag that will wait until the kubeconfig is available.

By default the kubeconfig is output on stdout, or you can use `-o` to specify an output filename.

### Prerequisites

* A VM already deployed via the `create_vm.sh`
  
### Enviroment variables

The previous environment variables can be used but it requires a few less.

### Usage

```bash
$ ./get_kubeconfig.sh
<kubeconfig contents>

$ ./get_kubeconfig.sh -o $KUBECONFIG
# Will write/overwrite the KUBECONFIG file
```

```bash
$ ./get_kubeconfig.sh -h
Usage: ./get_kubeconfig.sh [-f <path/to/variables/file>] [-n <vmname>] [-i <vmip>] [-o <filename>]
```

You can use the script in combination with the `create_vm.sh` one as:

```bash
$ ./create_vm.sh -f vm-foobar
$ ./get_kubeconfig.sh -w -f vm-foobar -o $KUBECONFIG
```

## get_ip.sh

This script is intended to easily get the VM IP created with the `create_vm.sh` script.

You can use the same `-f` or `-n` parameters as well.

### Prerequisites

* A VM already deployed via the `create_vm.sh`
  
### Enviroment variables

The previous environment variables can be used but it requires a few less.

### Usage

```bash
$ ./get_ip.sh
192.168.205.2
```

```bash
$ ./get_ip.sh -h
Usage: ./get_ip.sh [-f <path/to/variables/file>] [-n <vmname>]

Options:
 -f		(Optional) Path to the variables file
 -n		(Optional) Virtual machine name
```

## What's next?

See the [fleet-examples](../fleet-examples/) folder for some workloads you can deploy on top of your new shiny cluster.
