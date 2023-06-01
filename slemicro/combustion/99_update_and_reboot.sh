#!/bin/bash
set -euo pipefail

# Update and reboot as required by transactional-update
if [ "${UPDATEANDREBOOT}" = true ]; then
	cat <<- EOF > /etc/systemd/system/update-and-reboot.service
	[Unit]
	Description=Reboot if required once
	Wants=network-online.target
	# If services doesn't exist is ok
	After=network.target network-online.target ${CLUSTER_INSTALL_SERVICE} rancher_installer.service skip-rancher-bootstrap.service elemental_installer.service
	[Service]
	User=root
	# Run this service the last one
	Type=oneshot
	ExecStart=transactional-update
	ExecStartPost=/bin/sh -c "systemctl disable update-and-reboot.service"
	ExecStartPost=rm -f /etc/systemd/system/update-and-reboot.service
	ExecStartPost=reboot
	RemainAfterExit=yes
	# Long timeout just in case
	TimeoutSec=3600
	[Install]
	WantedBy=multi-user.target
	EOF
	systemctl enable update-and-reboot.service
fi