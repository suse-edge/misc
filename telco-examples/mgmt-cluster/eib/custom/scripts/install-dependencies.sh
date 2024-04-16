#!/bin/bash

mount /usr/local || true
mount /home || true

## create folder to server httpd media server
mkdir -p /home/metal3/bmh-image-cache

## copy the metal3 yaml file to metal3 folder
cp ./helm-values-metal3.yaml ./clusterctl.yaml ./disable-embedded-capi.yaml /home/metal3/

## KUBECTL command var
export KUBECTL=/var/lib/rancher/rke2/bin/kubectl

# Create the installer script
cat <<- EOF > /usr/local/bin/mgmt-cluster-installer.sh
#!/bin/bash
set -euo pipefail

## install clusterctl and helm
curl -Lk https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.6.0/clusterctl-linux-amd64 -o /usr/local/bin/clusterctl
chmod +x /usr/local/bin/clusterctl
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

## Wait for RKE2 cluster to be available
until [ -f /etc/rancher/rke2/rke2.yaml ]; do sleep 2; done
# export the kubeconfig using the right kubeconfig path depending on the cluster (k3s or rke2)
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
# Wait for the node to be available, meaning the K8s API is available
while ! ${KUBECTL} wait --for condition=ready node $(hostname | tr '[:upper:]' '[:lower:]') ; do sleep 2 ; done

## Add Helm repos
helm repo add rancher-prime https://charts.rancher.com/server-charts/prime
helm repo add jetstack https://charts.jetstack.io
helm repo update

while ! ${KUBECTL} rollout status daemonset -n kube-system rke2-ingress-nginx-controller ; do sleep 2 ; done

## install cert-manager
helm install cert-manager jetstack/cert-manager \
	--namespace cert-manager \
        --create-namespace \
        --set installCRDs=true \
	--version v1.11.1

## Local path provisioner
${KUBECTL} apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.26/deploy/local-path-storage.yaml
until [ \$(${KUBECTL} get sc -o name | wc -l) -ge 1 ]; do sleep 10; done
${KUBECTL} patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

## Example in case you want to configure the httpd cache server for images
## podman run -dit --name bmh-image-cache -p 8080:80 -v /home/metal3/bmh-image-cache:/usr/local/apache2/htdocs/ docker.io/library/httpd:2.4

## install rancher
helm install rancher rancher-prime/rancher \
	--namespace cattle-system \
	--create-namespace \
	--set hostname=rancher-$(hostname -I | awk '{print $1}').sslip.io \
	--set bootstrapPassword=admin \
	--set replicas=1 \
        --set global.cattle.psp.enabled=false
while ! ${KUBECTL} wait --for condition=ready -n cattle-system \$(${KUBECTL} get pods -n cattle-system -l app=rancher -o name) --timeout=10s; do sleep 2 ; done

## install metal3 with helm
helm repo add suse-edge https://suse-edge.github.io/charts
helm install   metal3 suse-edge/metal3   --namespace metal3-system   --create-namespace -f /home/metal3/helm-values-metal3.yaml


## install capi
if [ \$(${KUBECTL} get pods -n cattle-system -l app=rancher -o name | wc -l) -ge 1 ]; then
	${KUBECTL} apply -f /home/metal3/disable-embedded-capi.yaml
	${KUBECTL} delete mutatingwebhookconfiguration.admissionregistration.k8s.io mutating-webhook-configuration
	${KUBECTL} delete validatingwebhookconfigurations.admissionregistration.k8s.io validating-webhook-configuration
	${KUBECTL} wait --for=delete namespace/cattle-provisioning-capi-system --timeout=300s
fi

clusterctl init --core "cluster-api:v1.6.2" --infrastructure "metal3:v1.6.0" --bootstrap "rke2:v0.2.6" --control-plane "rke2:v0.2.6" --config /home/metal3/clusterctl.yaml

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