#!/bin/bash

mount /usr/local || true
mount /home || true

## create folder to server httpd media server
mkdir -p /home/metal3/bmh-image-cache

## copy the metal3 yaml file to metal3 folder
cp ./helm-values-metal3.yaml /home/metal3/
cp ./clusterctl.yaml /home/metal3/

# Create the installer script
cat <<- EOF > /usr/local/bin/mgmt-cluster-installer.sh
#!/bin/bash
set -euo pipefail

## install clusterctl and helm
curl -Lk https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.3.5/clusterctl-linux-amd64 -o /usr/local/bin/clusterctl
chmod +x /usr/local/bin/clusterctl
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Wait for cluster to be available
until [ -f /etc/rancher/rke2/rke2.yaml ]; do sleep 2; done
# export the kubeconfig using the right kubeconfig path depending on the cluster (k3s or rke2)
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
# Wait for the node to be available, meaning the K8s API is available
while ! /var/lib/rancher/rke2/bin/kubectl wait --for condition=ready node $(cat /etc/hostname | tr '[:upper:]' '[:lower:]') ; do sleep 2 ; done

helm repo add rancher https://releases.rancher.com/server-charts/latest
helm repo add jetstack https://charts.jetstack.io
helm repo update

while ! /var/lib/rancher/rke2/bin/kubectl rollout status daemonset -n kube-system rke2-ingress-nginx-controller ; do sleep 2 ; done
helm install cert-manager jetstack/cert-manager \
	--namespace cert-manager \
        --create-namespace \
        --set installCRDs=true \
	--version v1.11.1

cd /home/metal3/
git clone https://github.com/rancher/local-path-provisioner.git
cd local-path-provisioner/deploy/chart/local-path-provisioner
helm install local-path-provisioner . -n local-path-storage --create-namespace

## Configure the httpd cache server for images
podman run -dit --name bmh-image-cache -p 8080:80 -v /home/metal3/bmh-image-cache:/usr/local/apache2/htdocs/ docker.io/library/httpd:2.4

helm install rancher rancher/rancher \
	--namespace cattle-system \
	--create-namespace \
	--set hostname=rancher-$(hostname -I | awk '{print $1}').sslip.io \
	--set bootstrapPassword=admin \
	--set replicas=1 \
        --set global.cattle.psp.enabled=false

## install metal3 with helm
helm repo add suse-edge https://suse-edge.github.io/charts
helm install   metal3 suse-edge/metal3   --namespace metal3-system   --create-namespace -f /home/metal3/helm-values-metal3.yaml


## install capi
clusterctl init --core cluster-api:v1.6.0 --infrastructure metal3:v1.6.0
clusterctl init --bootstrap rke2 --control-plane rke2 --config /home/metal3/clusterctl.yaml

rm -f /etc/systemd/system/mgmt-cluster-installer.service
EOF

chmod a+x /usr/local/bin/mgmt-cluster-installer.sh

cat <<- EOF > /etc/systemd/system/mgmt-cluster-installer.service
[Unit]
Description=Deploy mgmt cluster tools on K3S/RKE2
Wants=network-online.target
After=network.target network-online.target rke2-server.target
ConditionPathExists=/usr/local/bin/mgmt-cluster-installer.sh

[Service]
User=root
Type=forking
TimeoutStartSec=900
ExecStart=/usr/local/bin/mgmt-cluster-installer.sh
RemainAfterExit=yes
KillMode=process
# Disable & delete everything
ExecStartPost=rm -f /usr/local/bin/mgmt-cluster-installer.sh
ExecStartPost=/bin/sh -c "systemctl disable mgmt-cluster-installer.service"
ExecStartPost=rm -f /etc/systemd/system/mgmt-cluster-installer.service

[Install]
WantedBy=multi-user.target
EOF

systemctl enable mgmt-cluster-installer.service

umount /usr/local || true
umount /home || true