# Airgap images 

There are two types of airgap images:

- Rancher images

- EIB images for the mgmt-cluster 

## Requirements

To retrieve the airgap images, you need to have the following tools installed:

- helm `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash`

**IMPORTANT**: You need to run the following scripts in a cluster deployed with the final versions (the release you want to retrieve the airgap images list)


## Airgap images for the management cluster

The airgap images for the management cluster are located in the `airgap-images` directory. The images are used to create a management cluster that is not connected to the internet. The images are stored in a tar file and can be loaded into the local container registry using the following command:

```bash
./eib-mgmt-cluster-airgap-images.sh
```

This command will show you the full list images to be included in the EIB definition file for airgap scenarios


## Airgap images for rancher guide

``` 
./retrieve-rancher-airgap-images.sh
```

This will show you the list of images to be included in the rancher guide for airgap environments

## How to get the full list of images

- Deploy an "connected" environment for mgmt-cluster commented the 3 lines here: https://github.com/suse-edge/atip/blob/8e70085f70153e3fa9f34f5c33a804184c0b1ae0/telco-examples/mgmt-cluster/single-node/eib/custom/files/metal3.sh#L42-L45  (the idea is to avoid deleting the pods to have the full list of images during the script execution).
- try to replicate the test for all cni supported (to get all images as possible)
- During the process it will use all images required and then you can use the `./eib-mgmt-cluster-airgap-images.sh` with the full list of images you need for the airgap environment (to be included in the EIB definition file)
