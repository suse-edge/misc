#!/bin/bash
set -euo pipefail

# Bypass rancher bootstrap
if [ "${RANCHERBOOTSTRAPSKIP}" = true ]; then
	# Mount /usr/local to store the rancher bootstrap skip script
	mount /usr/local || true

	# Install jq
	zypper --non-interactive install jq

	# Create a script that will skip all the rancher bootstrap steps
	# See https://stackoverflow.com/a/61259844 for the reason about ${q} :)
	cat <<- "EOF" > /usr/local/bin/skip-rancher-bootstrap.sh
	#!/bin/bash
	set -euo pipefail
	HOST="https://$(hostname -I | awk '{print $1}').sslip.io"
	# export the kubeconfig using the right kubeconfig path depending on the cluster (k3s or rke2)
	export KUBECONFIG=${KUBECONFIG}
	while ! ${KUBECTL} wait --for condition=ready -n cattle-system $(${KUBECTL} get pods -n cattle-system -l app=rancher -o name) --timeout=10s; do sleep 2 ; done

	# https://github.com/rancher/rke2/issues/3958
	if [ "${CLUSTER}" == "rke2" ]; then
		# Wait for the rke2-ingress-nginx-controller DS to be available if using RKE2
		while ! ${KUBECTL} rollout status daemonset -n kube-system rke2-ingress-nginx-controller --timeout=60s; do sleep 2 ; done
	fi

	# Get token
	TOKEN=$(curl -sk -X POST $${q}HOST/v3-public/localProviders/local?action=login -H 'content-type: application/json' -d '{"username":"admin","password":"${RANCHERBOOTSTRAPPASSWORD}"}' | jq -r .token)

	# Set password
	curl -sk $${q}HOST/v3/users?action=changepassword -H 'content-type: application/json' -H "Authorization: Bearer $${q}TOKEN" -d '{"currentPassword":"${RANCHERBOOTSTRAPPASSWORD}","newPassword":"${RANCHERFINALPASSWORD}"}'

	# Create a temporary API token (ttl=60 minutes)
	APITOKEN=$(curl -sk $${q}HOST/v3/token -H 'content-type: application/json' -H "Authorization: Bearer $${q}TOKEN" -d '{"type":"token","description":"automation","ttl":3600000}' | jq -r .token)

	curl -sk $${q}HOST/v3/settings/server-url -H 'content-type: application/json' -H "Authorization: Bearer $${q}APITOKEN" -X PUT -d "{\"name\":\"server-url\",\"value\":\"$${q}HOST\"}"
	curl -sk $${q}HOST/v3/settings/telemetry-opt -X PUT -H 'content-type: application/json' -H 'accept: application/json' -H "Authorization: Bearer $${q}APITOKEN" -d '{"value":"out"}'
	EOF

	chmod a+x /usr/local/bin/skip-rancher-bootstrap.sh

	# Create a systemd unit to run the steps after rancher has been installed
	# Using "User=root" is required for some environment variables to be present 
	cat <<- EOF > /etc/systemd/system/skip-rancher-bootstrap.service
	[Unit]
	Description=Skip Rancher Bootstrap
	Wants=network-online.target
	After=network.target network-online.target rancher_installer.service
	ConditionPathExists=/usr/local/bin/skip-rancher-bootstrap.sh

	[Service]
	User=root
	Type=forking
	TimeoutStartSec=900
	ExecStart=/usr/local/bin/skip-rancher-bootstrap.sh
	RemainAfterExit=yes
	KillMode=process
	# Disable & delete everything
	ExecStartPost=rm -f /usr/local/bin/skip-rancher-bootstrap.sh
	ExecStartPost=/bin/sh -c "systemctl disable skip-rancher-bootstrap.service"
	ExecStartPost=rm -f /etc/systemd/system/skip-rancher-bootstrap.service

	[Install]
	WantedBy=multi-user.target
	EOF

	systemctl enable skip-rancher-bootstrap.service
fi