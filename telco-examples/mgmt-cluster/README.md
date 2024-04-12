
# Management Cluster

This is an example of using Edge Image Builder (EIB) to generate a management cluster iso image for SUSE ATIP. The management cluster will contain the following components:
- SUSE Linux Enterprise Micro 5.5 RT Kernel (SLE Micro RT)
- RKE2
- CNI plugins (e.g. Multus, Calico)
- Rancher
- Static IPs network configuration
- Metal3 and the CAPI provider

## Prerequisites

You need to modify the following values in the `mgmt-cluster.yaml` file:

- `${ROOT_PASSWORD}` - The root password for the management cluster. This could be generated using `openssl passwd -6 PASSWORD` and replacing PASSWORD with the desired password, and then replacing the value in the `mgmt-cluster.yaml` file.
- `${SCC_REGISTRATION_CODE}` - The registration code for the SUSE Customer Center for the SLE Micro product. This could be obtained from the SUSE Customer Center and replacing the value in the `mgmt-cluster.yaml` file.
- `${KUBERNETES_VERSION}` - The version of kubernetes to be used in the management cluster (e.g. `v1.25.9+rke2r1`).

You need to modify the following values in the `custom/files/helm-values-metal3.yaml` file:

- `${MGMT_CLUSTER_IP}` - This is the static IP of your management cluster node.

You need to modify the following values in the `network/mgmt-cluster-network.yaml` file:

- `${MGMT_GATEWAY}` - This is the gateway IP of your management cluster network.
- `${MGMT_DNS}` - This is the DNS IP of your management cluster network.
- `${MGMT_CLUSTER_IP}` - This is the static IP of your management cluster node.
- `${MGMT_MAC}` - This is the MAC address of your management cluster node.

You need to modify the following folder:

- `base-images` - To include inside the `SLE-Micro.x86_64-5.5.0-Default-RT-SelfInstall-GM.install.iso` image downloaded from the SUSE Customer Center.

## Building the Management Cluster Image using EIB

1. Clone this repo and navigate to the `telco-examples/mgmt-cluster/eib` directory.

2. Modify the files described in the prerequisites section.

3. The following command has to be executed from the parent directory where you have the `eib` directory cloned from this example (`mgmt-cluster`).

```
$ cd telco-examples/mgmt-cluster
$ podman run --rm --privileged -it -v ./eib:/eib \
           registry.opensuse.org/isv/suse/edge/edgeimagebuilder/containerfile/suse/edge-image-builder:1.0.0.rc1 \
           build -config-file mgmt-cluster.yaml -config-dir /eib -build-dir /eib/_build
```

## Deploy the Management Cluster

Once you have the iso image built using EIB into the `eib` folder, you can use it to be deployed on a VM or a baremetal server.
