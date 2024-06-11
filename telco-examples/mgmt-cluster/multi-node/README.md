
# Management Cluster in a multi-node setup

This is an example of using Edge Image Builder (EIB) to generate a management cluster iso image for SUSE ATIP. The management cluster will contain the following components:
- SUSE Linux Enterprise Micro 5.5 RT Kernel (SLE Micro RT)
- RKE2
- CNI plugins (e.g. Multus, Cilium)
- Rancher Prime
- Neuvector
- Longhorn
- Static IPs or DHCP network configuration
- Metal3 and the CAPI provider

## Prerequisites for a multi-node setup

- 3 Reserved IPs:
   - 1 for the API VIP Address
   - 1 for the Ingress VIP Address
   - 1 for the Metal3 VIP Address

You need to modify the following values in the `mgmt-cluster-multinode.yaml` file:

- `${ROOT_PASSWORD}` - The root password for the management cluster. This could be generated using `openssl passwd -6 PASSWORD` and replacing PASSWORD with the desired password, and then replacing the value in the `mgmt-cluster-multinode.yaml` file.
- `${SCC_REGISTRATION_CODE}` - The registration code for the SUSE Customer Center for the SLE Micro product. This could be obtained from the SUSE Customer Center and replacing the value in the `mgmt-cluster-multinode.yaml` file.
- `${KUBERNETES_VERSION}` - The version of kubernetes to be used in the management cluster (e.g. `v1.28.8+rke2r1`).
- `${API_HOST}` - The API host for the management cluster (e.g `192.168.122.10.sslip.io`).
- `${API_VIP}` - The API VIP address for the management cluster (e.g `192.168.122.10`). IMPORTANT: This IP should be reserved for the management cluster.

[IMPORTANT NOTE] - if you want to deploy the management cluster on a HA setup, you need to add more nodes in the `mgmt-cluster-multinode.yaml` file creating the corresponding network files in the `network` folder. The node name in `mgmt-cluster-multinode.yaml` should match with the filename in the network folder (e.g `hostname: mgmt-cluster1` should match with `network/mgmt-cluster1.yaml`) to define the host network. The VIP address will be configured in the LoadBalancer service for all nodes.

You need to modify the following values in the `network/${NODE_HOSTNAME}.yaml` file (The ${NODE_HOSTNAME} is the name configured in the previous mgmt-cluster-multinode.yaml):

- `${MGMT_GATEWAY}` - This is the gateway IP of your management cluster network.
- `${MGMT_DNS}` - This is the DNS IP of your management cluster network.
- `${MGMT_NODE1_IP}` - This is the static IP of your management cluster node. This IP is different for each node (e.g `${MGMT_NODE2_IP}`, `${MGMT_NODE3_IP}), and it's also different from any of the VIP Address reserved before for the Load Balancer.
- `${MGMT_MAC}` - This is the MAC address of your management cluster node.

Inside this file, you can also see some comments to specify the network configuration for the management cluster using a DHCP server.

You need to modify the following values in the `kubernetes/helm/values/metal3.yaml` file:

- `${METAL3_VIP}` - This is the static VIP for the provisioning services of your management cluster node mentioned above.

You need to modify the following values in the `kubernetes/helm/values/rancher.yaml` file:

- `${INGRESS_VIP}` - This is the static INGRESS VIP of your management cluster node mentioned above.

You need to modify the following values in the `kubernetes/manifests/ingress-ippool.yaml` file:

- `${INGRESS_VIP}` - This is the static INGRESS VIP of your management cluster node mentioned above.

You need to modify the following values in the `custom/scripts/99-register.sh` file:

- `${SCC_REGISTRATION_CODE}` - The registration code for the SUSE Customer Center for the SL Micro product. This could be obtained from the SUSE Customer Center and replacing the value in the `99-register.sh` file.

- `${SCC_ACCOUNT_EMAIL}` - The email address for the SUSE Customer Center account. This could be obtained from the SUSE Customer Center and replacing the value in the `99-register.sh` file.

You need to modify the following folder:

- `base-images` - To include inside the `SLE-Micro.x86_64-5.5.0-Default-SelfInstall-GM2.install.iso` image downloaded from the SUSE Customer Center.

## Optional modifications

### Add certificates to use HTTPS server to provide images using TLS

This is an optional step to add certificates to the management cluster to provide images using HTTPS Server (Helm Chart metal3 Version >= 0.7.1)

1. Modify the `kubernetes/helm/values/metal3.yaml` file to set to true the following value in the global section:

```yaml
global:
  additionalTrustedCAs: true
```

2. If you are deploying a mgmt-cluster from scratch using EIB, then add the secret to the manifests folder `kubernetes/manifests/metal3-cacert-secret.yaml` to automate the creation of the secret in the management cluster:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: metal3-system
---
apiVersion: v1
kind: Secret
metadata:
  name: tls-ca-additional
  namespace: metal3-system
type: Opaque
data:
  ca-additional.crt: {{ additional_ca_cert | b64encode }}
```

3. If you want to add the secret manually, then you can use the following command to create the secret:

```bash
kubectl -n meta3-system create secret generic tls-ca-additional --from-file=ca-additional.crt=./ca-additional.crt
```

## Building the Management Cluster Image using EIB

1. Clone this repo and navigate to the `telco-examples/mgmt-cluster/eib` directory.

2. Modify the files described in the prerequisites section.

3. The following command has to be executed from the parent directory where you have the `eib` directory cloned from this example (`mgmt-cluster`).

```
$ cd telco-examples/mgmt-cluster/multi-node
$ sudo podman run --rm --privileged -it -v $PWD:/eib \
registry.suse.com/edge/edge-image-builder:1.0.2 \
build --definition-file mgmt-cluster-multinode.yaml
```

## Deploy the Management Cluster

Once you have the iso image built using EIB into the `eib` folder, you can use it to be deployed on a VM or a baremetal server.
