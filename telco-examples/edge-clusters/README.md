# Edge clusters for Telco

## Introduction

This is an example to demonstrate how to deploy an edge cluster for Telco using SUSE ATIP and the Zero Touch Provisioning workflow.

There are two steps to deploy an edge cluster:

- Create the image for the edge cluster using the Edge Image Builder in order to prepare all the packages dependencies and the requirements for the edge cluster.
- Deploy the edge cluster using metal3 and the image created in the previous step.

Important notes:

* In the following examples, we will assume that the management cluster is already deployed and running. If you want to deploy the management cluster, please refer to the [Management Cluster example](../mgmt-cluster/README.md).
* In the following examples, we are assuming that the edge cluster will use Baremetal Servers. If you want to deploy the full workflow using virtual machines, please refer to the [metal3-demo repo](https://github.com/suse-edge/metal3-demo)


## Create the image for the edge cluster

### Prerequisites

Using the example folder `telco-examples/edge-clusters/eib`, we will create the basic structure in order to build the image for the edge cluster: 

You need to modify the following values in the `telco-edge-cluster.yaml` file:

- `${ROOT_PASSWORD}` - The root password for the management cluster. This could be generated using `openssl passwd -6 PASSWORD` and replacing PASSWORD with the desired password, and then replacing the value in the `telco-edge-cluster.yaml` file.
- `${SCC_REGISTRATION_CODE}` - The registration code for the SUSE Customer Center for the SLE Micro product. This could be obtained from the SUSE Customer Center and replacing the value in the `telco-edge-cluster.yaml` file.

You need to modify the following folder:

- `base-images` - To include inside the `SLE-Micro.x86_64-5.5.0-Default-RT-GM.raw` image downloaded from the SUSE Customer Center.

### Building the Edge Cluster Image using EIB

All the following commands in this section could be executed using any linux laptop/server x86_64 with podman installed. You don't need to have a specific environment to build the image. 

#### Prepare and build the EIB image (only once)

``` 
$ git clone https://github.com/suse-edge/edge-image-builder.git
$ cd edge-image-builder
$ git checkout tags/v1.0.0-rc0
```

In case you have cgroup version 1 (`podman info | grep cgroup`), you need to launch the following command using `sudo`:
```
$ podman build -t eib:dev .
```
** Note: see the [EIB documentation](https://github.com/suse-edge/edge-image-builder) for more information on how to build the EIB image.


#### Generate the image with our configuration for Telco profile

```
$ cd telco-examples/edge-clusters 
$ sudo podman run --rm --privileged -it -v ./eib:/eib localhost/eib:dev /bin/eib build -config-file mgmt-cluster.yaml -config-dir /eib -build-dir /eib/_build
```

## Deploy the Edge Clusters

All the following steps have to be executed from the management cluster in order to deploy the edge clusters.
There are two different examples:
- [Example 1 - Deploy a single-node Edge Cluster with the image generated and Telco profiles](#example-1---deploy-a-single-node-edge-cluster-with-the-image-generated-and-telco-profiles): In this example we will demostrate how to deploy a single-node edge cluster using the image generated in the previous step and the telco profiles configured in order to use telco capabilities like SRIOV, DPDK, CPU pinning and so on.
- [Example 2 - Deploy a multi-node HA cluster using metal3, metallb and the image generated](#example-2---deploy-a-multi-node-ha-cluster-using-metal3-metallb-and-the-image-generated): In this example we will demostrate how to deploy a multi-node edge cluster using metal3, metallb and the image generated in the previous step.

### Example 1 - Deploy a single-node Edge Cluster with the image generated and Telco profiles

There are 2 steps to deploy a single-node edge cluster:

- Enroll the new Baremetal host in the management cluster.
- Provision the new host using the CAPI manifests and the image generated in the previous step.

#### Enroll the new Baremetal host

Using the folder `telco-examples/edge-telco-single-node`, we will create the components required to deploy a single-node edge cluster using the image generated in the previous step and the telco profiles configured.

The first step is to enroll the new Baremetal host in the management cluster. To do that, you need to modify the `bmh-example.yaml` file and replace the following with your values:

- `${BMC_USERNAME}` - The username for the BMC of the new Baremetal host.
- `${BMC_PASSWORD}` - The password for the BMC of the new Baremetal host.
- `${BMC_MAC}` - The MAC address of the new Baremetal host to be used.
- `${BMC_ADDRESS}` - The URL for the Baremetal host BMC (e.g `redfish-virtualmedia://192.168.200.75/redfish/v1/Systems/1/`). If you want to know more about the different options available depending on your hardware provider, please check the following [link](https://github.com/metal3-io/baremetal-operator/blob/main/docs/api.md).

Then, you need to apply the changes using the following command into the management cluster:

```
$ kubectl apply -f bmh-example.yaml
```

The new Baremetal host will be enrolled changing the state from registering to inspecting and available. You could check the status using the following command:

``` 
$ kubectl get bmh
```

#### Provision the new host using the CAPI manifests and the image generated

Once the new Baremetal host is available, you need to provision the new host using the CAPI manifests and the image generated in the previous step.

The first thing is to modify the `telco-capi-single-node.yaml` file and replace the following with your values:

- `${EDGE_CONTROL_PLANE_IP}` - The IP address to be used as a endpoint for the edge cluster (should match with the kubeapi-server endpoint).
- `${SRIOV_VENDOR}` - The vendor of the SRIOV network device to be used (e.g `8086` which means intel. You can get that info using `lspci` command with grep to find the vendors and device codes). For more information, please check the following [link](https://github.com/k8snetworkplumbingwg/sriov-network-device-plugin#configurations)
- `${SRIOV_DEVICE}` - The device of the SRIOV network device to be used (e.g `57c1` which means the FEC acc card. You can get that info using `lspci` command with grep to find the vendors and device codes). For more information, please check the following [link](https://github.com/k8snetworkplumbingwg/sriov-network-device-plugin#configurations)
- `${SRIOV_NET_INTERFACE}` - The network interface to be used for the SRIOV network device (e.g `eth0` which means the first network interface in the server. You can get that info using `ip link` command to list the network interfaces).
- `${ISOLATED_CPU_CORES}` - The isolated CPU cores to be used for workloads pinning some specific cpu cores. You could get that info using `lscpu` command to list the CPU cores and then, select the cores to be used for the edge cluster in case you need cpu pinning for your workloads. For example, `1-18,21-38` could be used for the isolated cores.
- `${NON-ISOLATED_CPU_CORES}` - The cores listed could be used shared for the rest of the process running on the edge cluster. For example, `0,20,21,39` could be used for the non-isolated cores.
- `${CPU_FREQUENCY}` - The frequency to be used for the CPU cores. For example, `2500000` represents 2.5Ghz configuration and it could be used to set the CPU cores to the max performance.
- `${DPDK_PCI_ADDRESS}` - The PCI device to be used for the DPDK configuration. You could get that info using `lspci` command to list the PCI devices and then selecting the device to be used for the DPDK configuration. For example, `0000:00:1f.6` could be used for the DPDK configuration.
- `${RKE2_VERSION}` - The RKE2 version to be used for the edge cluster. For example, `v1.28.3+rke2r1` could be used for the edge cluster.

You can also modify any other parameter in the `telco-capi-single-node.yaml` file to match with your requirements e.g. DPDK configuration, number of VFs to generate, number of SRIOV interfaces, etc. This is basically a template to be used for the edge cluster deployment. 

** Note: Remember to locate the `eibimage-slemicro55rt-telco.raw` file generated in [Create the image for the edge cluster](#create-the-image-for-the-edge-cluster) into the management cluster httpd cache folder to be used during the edge cluster provision step.

Then, you need to apply the changes using the following command into the management cluster:

```
$ kubectl apply -f telco-capi-single-node.yaml
```


### Example 2 - Deploy a multi-node HA cluster using metal3, metallb and the image generated

There are 2 steps to deploy a multi-node edge cluster:

- Enroll the 3 Baremetal hosts in the management cluster.
- Provision the new hosts using the CAPI manifests and the image generated in the previous step.

#### Enroll the new Baremetal host

Using the folder `telco-examples/edge-metallb-multi-node`, we will create the components required to deploy a multi-node edge cluster with 3 control-plane replicas, using the image generated in the previous step and metallb as a load balancer.

The first step is to enroll the new Baremetal hosts in the management cluster. To do that, you need to modify the `bmh-node1-example.yaml` file and replace the following with your values:

- `${BMC_NODE1_USERNAME}` - The username for the BMC of the first Baremetal host.
- `${BMC_NODE1_PASSWORD}` - The password for the BMC of the first Baremetal host.
- `${BMC_NODE1_MAC}` - The MAC address of the first Baremetal host to be used.
- `${BMC_NODE1_ADDRESS}` - The URL for the first Baremetal host BMC (e.g `redfish-virtualmedia://192.168.200.75/redfish/v1/Systems/1/`). If you want to know more about the different options available depending on your hardware provider, please check the following [link](https://github.com/metal3-io/baremetal-operator/blob/main/docs/api.md).

You need to replace the same variables (change the values respectively) for the second and third Baremetal hosts in the `bmh-node2-example.yaml` and `bmh-node3-example.yaml` files.

Then, you need to apply the changes using the following command into the management cluster:

```
$ kubectl apply -f bmh-node1-example.yaml 
$ kubectl apply -f bmh-node2-example.yaml 
$ kubectl apply -f bmh-node3-example.yaml
```

The new Baremetal hosts will be enrolled changing the state from registering to inspecting and available. You could check the status using the following command:

``` 
$ kubectl get bmh -owide
```

#### Provision the new hosts using the CAPI manifests and the image generated

Once the new Baremetal hosts are available, you need to provision the new hosts using the CAPI manifests and the image generated in the previous step.

The first thing is to modify the `telco-capi-metallb-multi-node.yaml` file and replace the following with your values:

- `${EDGE_VIP_ADDRESS}` - The IP address to be used as a endpoint for the edge cluster (should be the VIP address reserved previously).
- `${RKE2_VERSION}` - The RKE2 version to be used for the edge cluster. For example, `v1.28.3+rke2r1` could be used for the edge cluster.

** Note: Remember to locate the `eibimage-slemicro55rt-telco.raw` file generated in [Create the image for the edge cluster](#create-the-image-for-the-edge-cluster) into the management cluster httpd cache folder to be used during the edge cluster provision step.

Then, you need to apply the changes using the following command into the management cluster:

```
$ kubectl apply -f telco-capi-single-node.yaml
```