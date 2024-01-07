#!/usr/bin/env bash
# SUSE Edge Elemental Node Reset Script
# Copyright 2024 SUSE Software Solutions

# This script attempts to cleanup a node that has been deployed via Edge Image
# Builder with the integrations for Elemental registration; in other words,
# vanilla SLE Micro 5.5, *not* SLE Micro for Rancher (also known as Elemental
# Teal), that has used the "--no-toolkit" registration option.
#
# The default behaviour in Rancher/Elemental is that in the event that a
# cluster is deleted in Rancher, the Kubernetes cluster running on a node (or 
# set of nodes) will not be automatically cleaned up; the cluster will be
# orphaned and will remain running. Furthermore, the Elemental MachineInventory
# will be removed, so it's no longer visible in the list of registered nodes.
#
# This script cleans up the installed Kubernetes cluster so no traces remain
# and forces a re-registration with the original Elemental registration config.
# It is expected that certain parts of this script will fail.
#
# WARNING: This script *will* cause data loss as it removes all Kubernetes
#          persistent data. There is also an unattended switch for automated
#          reset. You have been warned!

usage(){
	cat <<-EOF
================================================================
SUSE Edge Node Cleanup Script (for Elemental registered systems)
================================================================
	Usage: ${0} [-u]

	Options:
	 -u		Runs in unattended mode and doesn't request confirmation. Data loss warning!
	EOF
}

UNATTENDED=false

while getopts 'h:u' OPTION; do
	case "${OPTION}" in
		u)
			UNATTENDED=true
			;;
		h)
			usage && exit 0
			;;
		?)
			usage && exit 2
			;;
	esac
done

if [ $UNATTENDED = "false" ] ;
then
	echo "============================================"
	echo "SUSE Edge Node Cleanup for Elemental Systems"
	echo -e "============================================\n"
	echo -n "WARNING: This script will remove all Kubernetes files and will"
	echo -e " cause data loss!\n"
	while true; do
            read -p "Are you sure you wish to proceed [y/N]? " yn
            case $yn in
                [Yy] ) break;;
                [Nn] ) exit;;
                * ) exit 0;;
            esac
        done
fi

# If we reach this point, we're deleting data and re-registering.

# Stop both the elemental and rancher-system-agents via systemd
systemctl kill --signal=SIGKILL elemental-system-agent
systemctl kill --signal=SIGKILL rancher-system-agent

# Kill all running Kubernetes services
rke2-killall.sh
k3s-killall.sh

# Uninstall all deployed Kubernetes components
rke2-uninstall.sh
k3s-uninstall.sh

# Remove the rancher-system-agent as this gets reinstalled via Elemental
sh /opt/rancher-system-agent/bin/rancher-system-agent-uninstall.sh
rm -rf /opt/rancher-system-agent

# Clean up all old configuration directories and Elemental state
rm -rf /etc/rancher
rm -rf /var/lib/rancher
rm -f /etc/elemental/state.yaml

# Re-register the node via Elemental using the original Elemental config
elemental-register --config-path /etc/elemental/config.yaml --state-path /etc/elemental/state.yaml --install --no-toolkit

# Start the Elemental service which will check in and await adoption
cp -f /var/lib/elemental/agent/elemental_connection.json /etc/rancher/elemental/agent
systemctl restart elemental-system-agent
