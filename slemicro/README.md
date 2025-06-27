<div align="center">

# SUSE Edge misc

<p align="center">
  <img alt="SUSE Logo" src="https://www.suse.com/assets/img/suse-white-logo-green.svg" height="140" />
  <h3 align="center">SUSE Edge misc</h3>
</p>

| :warning: **This is an unofficial and unsupported repository. See the [official documentation](https://www.suse.com/solutions/edge-computing/).** |
| --- |

</div>

- [create\_vm\_with\_eib.sh](#create_vm_with_eibsh)
  - [Prerequisites](#prerequisites-6)
  - [Enviroment variables](#enviroment-variables-4)
  - [Usage](#usage-6)
- [create\_vm\_with\_image.sh](#create_vm_with_imagesh)
  - [Prerequisites](#prerequisites-7)
  - [Enviroment variables](#enviroment-variables-5)
  - [Usage](#usage-7)
- [delete\_vm.sh](#delete_vmsh)
  - [Prerequisites](#prerequisites-1)
  - [Enviroment variables](#enviroment-variables-1)
  - [Usage](#usage-1)
- [get\_kubeconfig.sh](#get_kubeconfigsh)
  - [Prerequisites](#prerequisites-2)
  - [Enviroment variables](#enviroment-variables-2)
  - [Usage](#usage-2)
- [get\_ip.sh](#get_ipsh)
  - [Prerequisites](#prerequisites-3)
  - [Enviroment variables](#enviroment-variables-3)
  - [Usage](#usage-3)
- [getvmsip.sh](#getvmsipsh)
  - [Prerequisites](#prerequisites-4)
  - [Usage](#usage-4)
- [What's next?](#whats-next)


**NOTE**: There is a `vm*` pattern already in the `.gitignore` file so you can conviniently name your VM parameters file as `vm-foobar` and they won't be added to git. 

## create_vm_with_eib.sh

This script creates a SLE Micro VM on OSX/Linux using UTM (or Libvirt) based on EIB.

The script will output the virtual terminal to connect to (using `screen` if needed) as well as the
IP that it gets from the OSX DHCPD service.

WARNING: Read the [EIB documentation](https://github.com/suse-edge/edge-image-builder/blob/main/docs/building-images.md) carefully
to understand the folders and files needed as well as the EIB configuration file.

### Prerequisites

* `podman`
* `yq`
* `qemu-img`

NOTE: They can be installed using `brew`.
* `qemu-img` is available via the `qemu` package.

* [UTM 4.2.2](https://docs.getutm.app/) or higest (required for the scripting part)

* EIB configuration file and folder already created, including the SL Micro raw image.
  * Download the raw image file from the SUSE website at https://www.suse.com/download/sle-micro/
  * Select ARM or X86_64 architecture (depending on the Operating system of the host)
  * Look for the raw file (I.e.- `SL-Micro.aarch64-6.0-Default-GM2.raw`)
  * Note: SLE Micro RT image can be used as well.

### Enviroment variables

It requires a few enviroment variables to be set to customize it, the bare minimum is just:

```
# Folder where the VM will be hosted
VMFOLDER="${HOME}/VMs"
MACADDRESS="00:00:00:00:00:00"
```

The rest of them can be observed in the script itself.

The variables can be stored in the script basedir as `.env` or in any file and use the `-f path/to/the/variables` flag.

**NOTE**: There is a `vm*` pattern already in the `.gitignore` file so you can conviniently name your VM parameters file as `vm-foobar` and they won't be added to git. 

NOTE:
1. EIB vars and settings are not verified, EIB will complain by itself if needed.
2. The EIB config file is currently hardcoded as `eib.yaml`
3. The EIB folders and files need to be precreated by the user

### Usage

For a simple example like:

```bash
$ tree --noreport eib 
eib
└── smolvm
    ├── base-images
    │   └── SL-Micro.aarch64-6.0-Default-GM2.raw
    ├── network
    │   └── smolvm1.yaml
    └── eib.yaml

$ cat eib/smolvm/eib.yaml
apiVersion: 1.1
image:
  imageType: raw
  arch: aarch64
  baseImage: SL-Micro.aarch64-6.0-Default-GM2.raw
  outputImageName: eib-image.raw
operatingSystem:
  rawConfiguration:
    diskSize: 30G
  users:
    - username: root
      encryptedPassword: $6$ZDh4zjzEsh8K8Svn$DOmn5N2EZZJ1RCys/937tFwID6LfCcCnblp5o0ralWk72a3pmOyTmhsLaHWobBX9mhwVbEBgvKzdudo1jRee3.

$ cat eib/smolvm/network/smolvm1.yaml
interfaces:
- name: eth0
  type: ethernet
  state: up
  mac-address: 00:00:00:00:00:00
  ipv4:
    dhcp: true
    enabled: true
  ipv6:
    enabled: false
```

NOTE: To create the password, `openssl passwd -6 <password>` can be used. In this example, the password is `foobar`.

```bash
$ ./create_vm_with_eib.sh -f vm-slmicro6-eib -e eib/smolvm
Generating image customization components...
Identifier ................... [SUCCESS]
Custom Files ................. [SKIPPED]
Time ......................... [SKIPPED]
Network ...................... [SKIPPED]
Groups ....................... [SKIPPED]
Users ........................ [SUCCESS]
Proxy ........................ [SKIPPED]
Rpm .......................... [SKIPPED]
Os Files ..................... [SKIPPED]
Systemd ...................... [SKIPPED]
Fips ......................... [SKIPPED]
Elemental .................... [SKIPPED]
Suma ......................... [SKIPPED]
Embedded Artifact Registry ... [SKIPPED]
Keymap ....................... [SUCCESS]
Kubernetes ................... [SKIPPED]
Certificates ................. [SKIPPED]
Cleanup ...................... [SUCCESS]
Building RAW image...
Kernel Params ................ [SKIPPED]
Build complete, the image can be found at: eib-image.raw
VM started. You can connect to the serial terminal as: screen /dev/ttys001
Waiting for IP: ................
VM IP: 192.168.206.60
```

You could also use the `-n` parameter to override the name of the VM to be used:

```bash
$ ./create_vm_with_eib.sh -h
Usage: ./create_vm_with_eib.sh [-f <path/to/variables/file>] [-e <path/to/eib/folder>] [-n <vmname>]
```

See the [eib-examples/](eib-examples/) folder and the [eib-example-k3s-cluster-vm1](eib-example-k3s-cluster-vm1) (also [vm2](eib-example-k3s-cluster-vm2) and [vm2](eib-example-k3s-cluster-vm2)) for more examples.

## create_vm_with_image.sh

This script creates a SLE Micro VM on OSX/Linux using UTM (or Libvirt) based on a precreated EIB image (via [create\_vm\_with\_eib.sh](#create_vm_with_eibsh)).
The intention is to use EIB to create an image for any number of nodes + the first node via [create\_vm\_with\_eib.sh](#create_vm_with_eibsh) and then create the rest of the nodes with this script.

The script will output the virtual terminal to connect to (using `screen` if needed) as well as the
IP that it gets from the OSX DHCPD service.

### Prerequisites

* `qemu-img`

NOTE: They can be installed using `brew`.
* `qemu-img` is available via the `qemu` package.

* [UTM 4.2.2](https://docs.getutm.app/) or higest (required for the scripting part)

* EIB raw image already created.

### Enviroment variables

It requires a few enviroment variables to be set to customize it, the bare minimum is just:

```
# Folder where the VM will be hosted
VMFOLDER="${HOME}/VMs"
MACADDRESS="00:00:00:00:00:00"
```

The rest of them can be observed in the script itself.

The variables can be stored in the script basedir as `.env` or in any file and use the `-f path/to/the/variables` flag.

**NOTE**: There is a `vm*` pattern already in the `.gitignore` file so you can conviniently name your VM parameters file as `vm-foobar` and they won't be added to git. 

### Usage

For a simple example like:

```bash
$ ./create_vm_with_image.sh -f vm-slmicro62-eib -i eib/smolvm/eib-image.raw
VM started. You can connect to the serial terminal as: screen /dev/ttys001
Waiting for IP: ................
VM IP: 192.168.206.61
```

You could also use the `-n` parameter to override the name of the VM to be used:

```bash
$ ./create_vm_with_eib.sh -h
Usage: ./create_vm_with_image.sh [-f <path/to/variables/file>] [-i <path/to/image.qcow2>] [-n <vmname>]
```

**TIP:** To run the VM creation in parallel you can use `for file in vm-*; do ./create_vm_with_image.sh -f ${file} &; done; wait` (the output will be a little bit messy however)

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

## getvmsip.sh

This script is intended to easily show all the VMs IP on the host.

It doesn't require any parameter

### Prerequisites

* A VM already deployed

### Usage

```bash
$ ./getvmsip.sh
bootstraper 192.168.122.2
host1rke2 192.168.122.128
host2rke2 192.168.122.77
host3rke2 192.168.122.31
host1k3s 192.168.122.180
host2k3s 192.168.122.136
host3k3s 192.168.122.215
```

## What's next?

See the [fleet-examples](../fleet-examples/) folder for some workloads you can deploy on top of your new shiny cluster.
