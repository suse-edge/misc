#!/bin/bash
set -euo pipefail

# Elemental
if [ "${ELEMENTAL}" = true ]; then
	# Helm should be installed at this point
	# Mount /usr/local to store the rancher script
	mount /usr/local || true

	# Create a script to deploy elemental that will be called via a systemd service
	cat <<- "EOF" > /usr/local/bin/elemental_installer.sh
	#!/bin/bash
	set -euo pipefail

	# Wait for k3s to be available
	until [ -f ${KUBECONFIG} ]; do sleep 2; done
	# export the kubeconfig using the right kubeconfig path depending on the cluster (k3s or rke2)
	export KUBECONFIG=${KUBECONFIG}
	# Wait for the node to be available, meaning the K8s API is available
	while ! ${KUBECTL} wait --for condition=ready node $(cat /etc/hostname | tr '[:upper:]' '[:lower:]') --timeout=60s; do sleep 2 ; done

	# https://github.com/rancher/rke2/issues/3958
	if [ "${CLUSTER}" == "rke2" ]; then
		# Wait for the rke2-ingress-nginx-controller DS to be available if using RKE2
		while ! ${KUBECTL} rollout status daemonset -n kube-system rke2-ingress-nginx-controller --timeout=60s; do sleep 2 ; done
	fi

	# Add the official Rancher charts to install the ui-plugin operator & CRDs
	helm repo add rancher-charts https://charts.rancher.io/
	helm upgrade --create-namespace -n cattle-ui-plugin-system --install ui-plugin-operator rancher-charts/ui-plugin-operator
	helm upgrade --create-namespace -n cattle-ui-plugin-system --install ui-plugin-operator-crd rancher-charts/ui-plugin-operator-crd 

	# Wait for the operator to be up
	while ! ${KUBECTL} wait --for condition=ready -n cattle-ui-plugin-system $(${KUBECTL} get pods -n cattle-ui-plugin-system -l app.kubernetes.io/instance=ui-plugin-operator -o name) --timeout=10s; do sleep 2 ; done

	# Deploy the elemental UI plugin
	# NOTE: TABs and then spaces...
	cat <<- FOO | ${KUBECTL} apply -f -
	apiVersion: catalog.cattle.io/v1
	kind: UIPlugin
	metadata:
	  name: elemental
	  namespace: cattle-ui-plugin-system
	spec:
	  plugin:
	    endpoint: https://raw.githubusercontent.com/rancher/ui-plugin-charts/main/extensions/elemental/1.1.0
	    name: elemental
	    noCache: false
	    version: 1.1.0
	FOO

	# Or
	# helm repo add rancher-ui-plugins https://raw.githubusercontent.com/rancher/ui-plugin-charts/main
	# helm upgrade --install elemental rancher-ui-plugins/elemental --namespace cattle-ui-plugin-system --create-namespace

	while ! ${KUBECTL} wait --for condition=namesaccepted CustomResourceDefinition globalroles.management.cattle.io --timeout=10s; do sleep 2 ; done

	# Install elemental using an OCI registry
	helm upgrade --create-namespace -n cattle-elemental-system --install elemental-operator oci://registry.opensuse.org/isv/rancher/elemental/stable/charts/rancher/elemental-operator-chart

	EOF

	chmod a+x /usr/local/bin/elemental_installer.sh

	# Create a systemd unit to install elemental once
	# Using "User=root" is required for some environment variables to be present 
	cat <<- EOF > /etc/systemd/system/elemental_installer.service
	[Unit]
	Description=Deploy Elemental on Rancher on Cluster k3s/rke2
	Wants=network-online.target
	After=network.target network-online.target rancher_installer.service
	ConditionPathExists=/usr/local/bin/elemental_installer.sh

	[Service]
	User=root
	Type=forking
	TimeoutStartSec=900
	ExecStart=/usr/local/bin/elemental_installer.sh
	RemainAfterExit=yes
	KillMode=process
	# Disable & delete everything
	ExecStartPost=rm -f /usr/local/bin/elemental_installer.sh
	ExecStartPost=/bin/sh -c "systemctl disable elemental_installer.service"
	ExecStartPost=rm -f /etc/systemd/system/elemental_installer.service

	[Install]
	WantedBy=multi-user.target
	EOF

	systemctl enable elemental_installer.service
fi
