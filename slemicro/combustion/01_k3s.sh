#!/bin/bash
set -euo pipefail

# K3s
if [ "${CLUSTER}" == "k3s" ]; then
	# Mount /usr/local to store the k3s script
	mount /usr/local || true
	# Stolen from https://code.opensuse.org/adathor/combustion-dotconf/blob/main/f/K3s%20cluster/k3s_master/script
	# Download and install the latest k3s installer
	curl -L --output k3s_installer.sh https://get.k3s.io && install -m755 k3s_installer.sh /usr/local/bin/
	# Create a systemd unit that installs k3s if not installed yet. The k3s service is started after the installation
	cat <<- EOF > /etc/systemd/system/k3s_installer.service
	[Unit]
	Description=Run K3s installer
	Wants=network-online.target
	After=network.target network-online.target
	ConditionPathExists=/usr/local/bin/k3s_installer.sh
	ConditionPathExists=!/usr/local/bin/k3s

	[Service]
	User=root
	Type=forking
	TimeoutStartSec=600
	Environment="INSTALL_K3S_EXEC=${INSTALL_CLUSTER_EXEC}"
	Environment="INSTALL_K3S_VERSION=${INSTALL_CLUSTER_VERSION}"
	Environment="K3S_TOKEN=${CLUSTER_TOKEN}"
	Environment="INSTALL_K3S_SKIP_START=false"
	ExecStart=/usr/local/bin/k3s_installer.sh
	RemainAfterExit=yes
	KillMode=process
	# Load the proper modules for kube-vip lb to work
	ExecStartPost=/bin/sh -c "[ -f /root/ipvs.conf ] && mv /root/ipvs.conf /etc/modules-load.d/ipvs.conf || true"
	ExecStartPost=/bin/sh -c "[ -f /etc/modules-load.d/ipvs.conf ] && systemctl restart systemd-modules-load || true"
	# Move the kube-vip file if exists
	ExecStartPost=/bin/sh -c "[ -f /root/kube-vip.yaml ] && mkdir -p /var/lib/rancher/k3s/server/manifests || true"
	ExecStartPost=/bin/sh -c "[ -f /root/kube-vip.yaml ] && mv /root/kube-vip.yaml /var/lib/rancher/k3s/server/manifests/kube-vip.yaml || true"
	ExecStartPost=/bin/sh -c "[ -f /var/lib/rancher/k3s/server/manifests/kube-vip.yaml ] && chcon -t container_var_lib_t /var/lib/rancher/k3s/server/manifests/kube-vip.yaml || true"
	# Disable & delete everything
	ExecStartPost=rm -f /usr/local/bin/k3s_installer.sh
	ExecStartPost=/bin/sh -c "systemctl disable k3s_installer"
	ExecStartPost=rm -f /etc/systemd/system/k3s_installer.service
	
	[Install]
	WantedBy=multi-user.target
	EOF

	systemctl enable k3s_installer.service
fi
