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


## create_vm.sh

This script creates a SLE Micro aarch64 VM on OSX using UTM and it is customized using ignition/combustion.

The script will output the virtual terminal to connect to (using `screen` if needed) as well as the
IP that it gets from the OSX DHCPD service.

K3s and Rancher are optionally installed. Rancher access is configured with sslip.io and with a custom bootstrap password.

### Prerequisites

* `butane`
* `mkisofs`
* `qemu-img`

NOTE: They can be installed using `brew`

* [UTM 4.2.2](https://docs.getutm.app/) or higest (required for the scripting part)

* SLE Micro raw image.
  * Download the raw image file from the SUSE website at https://www.suse.com/download/sle-micro/
  * Select ARM architecture
  * Look for the raw file (I.e.- `SLE-Micro.aarch64-5.3.0-Default-GM.raw.xz`)

### Enviroment variables

It requires a few enviroment variables to be set to customize it. Store them in the script basedir as `.env`

```bash
cat << EOF > ${BASEDIR}/.env
# If required to register to https://scc.suse.com
export REGISTER=true
# Email & regcode for the registration
export EMAIL="foo@bar.com"
export REGCODE="ASDF-1"
# SLE Micro image
export SLEMICROFILE="${HOME}/Downloads/SLE-Micro.aarch64-5.3.0-Default-GM.raw"
# Folder where the VM will be hosted
export VMFOLDER="${HOME}/VMs"
# VM & Hostname
export VMNAME="SLEMicro"
# Selfexplanatory
export CPUS=4
export MEMORY=4096
export DISKSIZE=30
# Location of the ssh key file to be copied to /root/.ssh/authorized_keys
export SSHPUB="${HOME}/.ssh/id_rsa.pub"
# Set it to false if you don't want K3s to be deployed
export K3S=true
# Specify a K3s version
export K3s_VERSION="v1.25.8+k3s1"
# Set it to false if you don't want Rancher to be deployed
export RANCHER=true
# Initial Rancher bootstrap password
export RANCHERBOOTSTRAPPASSWORD="admin"
# Enable cockpit
export COCKPIT=true
# Enable podman
export PODMAN=true
# Update to latest packages and reboot if needed (zypper needs-reboot)
export UPDATEANDREBOOT=true
EOF
```

NOTE: See the [env.example](env.example) file for an always up-to-date list of variables.

### Usage

```bash
$ ./create_vm.sh
VM started. You can connect to the serial terminal as: screen /dev/ttys001
Waiting for IP: ................
VM IP: 192.168.206.60
After Rancher is installed, you can access the Web UI as https://192.168.206.60.sslip.io
```

## delete_vm.sh

This script is intended to easily delete the previously SLE Micro aarch64 VM on OSX using UTM.

:warning: There is no confirmation whatsoever!

### Prerequisites

* [UTM 4.2.2](https://docs.getutm.app/) or higest (required for the scripting part)

### Enviroment variables

The previous environment variables can be used but it requires a few less.

### Usage

```bash
$ ./delete_vm.sh
```
