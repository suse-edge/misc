#!/bin/bash
set -euo pipefail

# Rancher
if [ "${RANCHERFLAVOR}" != false ]; then
	# Mount /usr/local to store the rancher install script
	mount /usr/local || true

	# Download helm as required to install rancher
	curl -fsSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 |bash

	# Create a script to install rancher that will be called via a systemd service
	# See https://stackoverflow.com/a/61259844 for the reason about ${q} :)
	cat <<- EOF > /usr/local/bin/rancher_installer.sh
	#!/bin/bash
	set -euo pipefail
	# Wait for cluster to be available
	until [ -f ${KUBECONFIG} ]; do sleep 2; done
	# export the kubeconfig using the right kubeconfig path depending on the cluster (k3s or rke2)
	export KUBECONFIG=${KUBECONFIG}
	# Wait for the node to be available, meaning the K8s API is available
	while ! ${KUBECTL} wait --for condition=ready node $(cat /etc/hostname | tr '[:upper:]' '[:lower:]') --timeout=60s; do sleep 2 ; done
	# https://ranchermanager.docs.rancher.com/pages-for-subheaders/install-upgrade-on-a-kubernetes-cluster
	case ${RANCHERFLAVOR} in
		"latest" | "stable" | "alpha")
			helm repo add rancher https://releases.rancher.com/server-charts/${RANCHERFLAVOR}
		;;
		"prime")
			helm repo add rancher https://charts.rancher.com/server-charts/prime
		;;
		*)
			echo "Rancher flavor not detected, using latest"
			helm repo add rancher https://releases.rancher.com/server-charts/latest
		;;
	esac

	helm repo add jetstack https://charts.jetstack.io
	# Update your local Helm chart repository cache
	helm repo update

	# Install the cert-manager Helm chart
	helm install cert-manager jetstack/cert-manager \
		--namespace cert-manager \
		--create-namespace \
		--set installCRDs=true \
		--version v1.12.0

	# https://github.com/rancher/rke2/issues/3958
	if [ "${CLUSTER}" == "rke2" ]; then
		# Wait for the rke2-ingress-nginx-controller DS to be available if using RKE2
		while ! ${KUBECTL} rollout status daemonset -n kube-system rke2-ingress-nginx-controller --timeout=60s; do sleep 2 ; done
	fi

	# Install rancher using sslip.io as hostname and with just a single replica
	# The double dollar sign is because envsubst _removes_ the first one
	helm install rancher rancher/rancher \
		--namespace cattle-system \
		--create-namespace \
		--set hostname=rancher-$(hostname -I | awk '{print $$1}').sslip.io \
		--set bootstrapPassword=${RANCHERBOOTSTRAPPASSWORD} \
		--set replicas=1 \
		--set global.cattle.psp.enabled=false

	rm -f /etc/systemd/system/rancher_installer.service
	EOF

	chmod a+x /usr/local/bin/rancher_installer.sh

	# Create a systemd unit to install rancher once
	# Using "User=root" is required for some environment variables to be present
	cat <<- EOF > /etc/systemd/system/rancher_installer.service
	[Unit]
	Description=Deploy Rancher on K3S/RKE2
	Wants=network-online.target
	After=network.target network-online.target ${CLUSTER_INSTALL_SERVICE}
	ConditionPathExists=/usr/local/bin/rancher_installer.sh

	[Service]
	User=root
	Type=forking
	TimeoutStartSec=900
	ExecStart=/usr/local/bin/rancher_installer.sh
	RemainAfterExit=yes
	KillMode=process
	# Disable & delete everything
	ExecStartPost=rm -f /usr/local/bin/rancher_installer.sh
	ExecStartPost=/bin/sh -c "systemctl disable rancher_installer.service"
	ExecStartPost=rm -f /etc/systemd/system/rancher_installer.service

	[Install]
	WantedBy=multi-user.target
	EOF

	systemctl enable rancher_installer.service
fi