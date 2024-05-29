
# Management Cluster in a single-node setup

This is an example of using Edge Image Builder (EIB) to generate a management cluster iso image for SUSE ATIP. The management cluster will contain the following components:
- SUSE Linux Enterprise Micro 5.5 RT Kernel (SLE Micro RT)
- RKE2
- CNI plugins (e.g. Multus, Cilium)
- Rancher Prime
- Neuvector
- Longhorn
- Static IPs or DHCP network configuration
- Metal3 and the CAPI provider

You need to modify the following values in the `mgmt-cluster-multinode.yaml` file:

- `${ROOT_PASSWORD}` - The root password for the management cluster. This could be generated using `openssl passwd -6 PASSWORD` and replacing PASSWORD with the desired password, and then replacing the value in the `mgmt-cluster-multinode.yaml` file.
- `${SCC_REGISTRATION_CODE}` - The registration code for the SUSE Customer Center for the SLE Micro product. This could be obtained from the SUSE Customer Center and replacing the value in the `mgmt-cluster-multinode.yaml` file.
- `${KUBERNETES_VERSION}` - The version of kubernetes to be used in the management cluster (e.g. `v1.28.8+rke2r1`).

You need to modify the following values in the `network/mgmt-cluster-network.yaml` file :

- `${MGMT_GATEWAY}` - This is the gateway IP of your management cluster network.
- `${MGMT_DNS}` - This is the DNS IP of your management cluster network.
- `${MGMT_CLUSTER_IP}` - This is the static IP of your management cluster single node.
- `${MGMT_MAC}` - This is the MAC address of your management cluster node.

You need to modify the `${MGMT_CLUSTER_IP}` with the Node IP in the following files:

- `kubernetes/helm/values/metal3.yaml`

- `kubernetes/helm/values/rancher.yaml`

You need to modify the following values in the `custom/scripts/99-register.sh` file:

- `${SCC_REGISTRATION_CODE}` - The registration code for the SUSE Customer Center for the SL Micro product. This could be obtained from the SUSE Customer Center and replacing the value in the `99-register.sh` file.

- `${SCC_ACCOUNT_EMAIL}` - The email address for the SUSE Customer Center account. This could be obtained from the SUSE Customer Center and replacing the value in the `99-register.sh` file.

You need to modify the following folder:

- `base-images` - To include inside the `SLE-Micro.x86_64-5.5.0-Default-SelfInstall-GM2.install.iso` image downloaded from the SUSE Customer Center.

## Building the Management Cluster Image using EIB

1. Clone this repo and navigate to the `telco-examples/mgmt-cluster/single-node/eib` directory.

2. Modify the files described above.

3. The following command has to be executed from the parent directory where you have the `eib` directory cloned from this example (`mgmt-cluster`).

```
$ cd telco-examples/mgmt-cluster/single-node
$ sudo podman run --rm --privileged -it -v $PWD:/eib \
registry.suse.com/edge/edge-image-builder:1.0.1 \
build --definition-file mgmt-cluster-singlenode.yaml
```

## Deploy the Management Cluster

Once you have the iso image built using EIB into the `eib` folder, you can use it to be deployed on a VM or a baremetal server.
