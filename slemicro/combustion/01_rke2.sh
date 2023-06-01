#!/bin/bash
set -euo pipefail

# RKE2
if [ "${CLUSTER}" == "rke2" ]; then
	# Mount /usr/local to store the RKE2 script
	mount /usr/local || true

	curl -L --output rke2_installer.sh https://get.rke2.io && install -m755 rke2_installer.sh /usr/local/bin/
	# Create a systemd unit that installs rke2 if not installed yet. The rke2 service is started after the installation
	cat <<- EOF > /etc/systemd/system/rke2_installer.service
	[Unit]
	Description=Run RKE2 installer
	Wants=network-online.target
	After=network.target network-online.target
	ConditionPathExists=/usr/local/bin/rke2_installer.sh
	ConditionPathExists=!/opt/rke2/bin/rke2

	[Service]
	User=root
	Type=forking
	TimeoutStartSec=600
	Environment="INSTALL_RKE2_VERSION=${INSTALL_CLUSTER_VERSION}"
	Environment="RKE2_TOKEN=${CLUSTER_TOKEN}"
	ExecStart=/usr/local/bin/rke2_installer.sh
	RemainAfterExit=yes
	KillMode=process
	ExecStartPost=/bin/sh -c "systemctl enable --now rke2-server.service; systemctl start --no-block --now rke2-server.service"
	# update path in exec start post to include rke2 bin path
	ExecStartPost=/bin/sh -c "echo 'export KUBECONFIG=/etc/rancher/rke2/rke2.yaml' >> ~/.bashrc ; echo 'export PATH=${PATH}:/var/lib/rancher/rke2/bin' >> ~/.bashrc ; source ~/.bashrc"
	# Load the proper modules for kube-vip lb to work
	ExecStartPost=/bin/sh -c "[ -f /root/ipvs.conf ] && mv /root/ipvs.conf /etc/modules-load.d/ipvs.conf || true"
	ExecStartPost=/bin/sh -c "[ -f /etc/modules-load.d/ipvs.conf ] && systemctl restart systemd-modules-load || true"
	# Move the kube-vip file if exists
	ExecStartPost=/bin/sh -c "mkdir -p /var/lib/rancher/rke2/server/manifests"
	ExecStartPost=/bin/sh -c "[ -f /root/kube-vip.yaml ] && mv /root/kube-vip.yaml /var/lib/rancher/rke2/server/manifests/kube-vip.yaml || true"
	ExecStartPost=/bin/sh -c "[ -f /var/lib/rancher/rke2/server/manifests/kube-vip.yaml ] && chcon -t container_var_lib_t /var/lib/rancher/rke2/server/manifests/kube-vip.yaml || true"
	# Disable & delete everything
	ExecStartPost=rm -f /usr/local/bin/rke2_installer.sh
	ExecStartPost=/bin/sh -c "systemctl disable rke2_installer"
	ExecStartPost=rm -f /etc/systemd/system/rke2_installer.service

	[Install]
	WantedBy=multi-user.target
	EOF

	# RKE2 doesn't suport INSTALL_RKE2_EXEC it seems... but a systemd override works
	if [[ "${INSTALL_CLUSTER_EXEC}" == "server*" ]]; then
		TYPE="server"
	else
		TYPE="agent"
	fi
	mkdir -p /etc/systemd/system/rke2-${TYPE}.service.d/
	cat <<- EOF > /etc/systemd/system/rke2-${TYPE}.service.d/override.conf
	[Service]
	ExecStart=
	ExecStart=/opt/rke2/bin/rke2 ${INSTALL_CLUSTER_EXEC}
	EOF
	
	systemctl enable rke2_installer.service
fi
