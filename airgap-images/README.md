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