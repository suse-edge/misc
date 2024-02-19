# Edge clusters for Telco

## Introduction

This is an example to demonstrate how to deploy an edge cluster for Telco using SUSE ATIP and the Zero Touch Provisioning workflow.

There are two steps to deploy an edge cluster:

- Create the image for the edge cluster using the Edge Image Builder in order to prepare all the packages dependencies and the requirements for the edge cluster.
- Deploy the edge cluster using metal3 and the image created in the previous step.

Important notes:

* In the following examples, we will assume that the management cluster is already deployed and running. If you want to deploy the management cluster, please refer to the [Management Cluster example](../mgmt-cluster/README.md).
* In the following examples, we are assuming that the edge cluster will be Baremetal Servers. If you want to deploy the full workflow using virtual machines, please refer to the [metal3-demo repo](https://github.com/suse-edge/metal3-demo)


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
$ sudo podman build -t eib:dev .
```
** Note: see the [EIB documentation](https://github.com/suse-edge/edge-image-builder) for more information on how to build the EIB image.


#### Generate the image with our configuration for Telco profile

```
$ cd telco-examples/edge-clusters 
$ sudo podman run --rm --privileged -it -v ./eib:/eib localhost/eib:dev /bin/eib build -config-file mgmt-cluster.yaml -config-dir /eib -build-dir /eib/_build
```

## Deploy the Edge Clusters

All the following steps have to be executed from the management cluster in order to deploy the edge clusters.

### Deploy a single-node Edge Cluster with the image generated and Telco profiles

There are 2 steps to deploy a single-node edge cluster:

- Enroll the new Baremetal host in the management cluster.
- Provision the new host using the CAPI manifests and the image generated in the previous step.

#### Enroll the new Baremetal host

Using the folder `telco-examples/edge-single-node`, we will create the components required to deploy a single-node edge cluster using the image generated in the previous step and the telco profiles configured.

The first thing is to enroll the new Baremetal host in the management cluster. To do that, you need to modify the `bmh-example.yaml` file and replace the following with your values:

- `${BMC_USERNAME}` - The username for the BMC of the new Baremetal host.
- `${BMC_PASSWORD}` - The password for the BMC of the new Baremetal host.
- `${BMC_MAC}` with the MAC address of the new Baremetal host to be used.
- `${BMC_ADDRESS}` with the URL for the baremetal Host BMC. If you want to know more about the different options available, please check the following [link](https://github.com/metal3-io/baremetal-operator/blob/main/docs/api.md).

Then, you need to apply the changes using the following command into the management cluster:

```
$ kubectl apply -f bmh-example.yaml
```

The new Baremetal host will be enrolled changing the state from registering, inspecting and available. You could check the status using the following command:

``` 
$ kubectl get bmh -A
```

#### Provision the new host using the CAPI manifests and the image generated

Once the new Baremetal host is available, you could provision the new host using the CAPI manifests and the image generated in the previous step.

The first thing is to modify the `telco-metal3-single-node.yaml` file and replace the following with your values:

