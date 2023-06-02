#!/bin/bash
set -euo pipefail

# If Kubevip is enabled to have a VIP for the K3s API
# The official way would be:
# export VIP=192.168.205.68
# export INTERFACE=eth0
# export KVVERSION="v0.5.12"
# podman run --rm --network=host ghcr.io/kube-vip/kube-vip:$KVVERSION manifest daemonset \
#     --interface $INTERFACE \
#     --address $VIP \
#     --inCluster \
#     --taint \
#     --controlplane \
#     --arp \
#     --leaderElection > foobar.yaml
if [ "${KUBEVIP}" = true ]; then
	# lb_enable requires loading the ip_vs modules
	# https://kube-vip.io/docs/about/architecture/?query=lb_enable#control-plane-load-balancing
	# But at this point that folder is not valid and it won't work
	cat <<- EOF > /root/ipvs.conf
	ip_vs
	ip_vs_rr
	ip_vs_wrr
	ip_vs_sh
	nf_conntrack
	EOF
	
	# The proper path would be /var/lib/rancher/k3s/server/manifests
	# but as this is done at combustion time, the folder will be
	# overwritten when installing K3s as:
	# Apr 27 10:44:30 cp01 k3s_installer.sh[2437]: Warning: The following files were changed in the snapshot, but are shadowed by
	# Apr 27 10:44:30 cp01 k3s_installer.sh[2437]: other mounts and will not be visible to the system:
	# Apr 27 10:44:30 cp01 k3s_installer.sh[2437]: /.snapshots/3/snapshot/var/lib/rancher/k3s/server/manifests/kube-vip.yaml
	# So, instead, just create it somewhere and move it 
	# as an ExecStartPost in the k3s_installer service.
	# I've tried in /tmp and /var/tmp but 
	# those seem to be ephemeral at combustion time
	cat <<- EOF > /root/kube-vip.yaml
	apiVersion: v1
	kind: ServiceAccount
	metadata:
	  name: kube-vip
	  namespace: kube-system
	---
	apiVersion: rbac.authorization.k8s.io/v1
	kind: ClusterRole
	metadata:
	  annotations:
	    rbac.authorization.kubernetes.io/autoupdate: "true"
	  name: system:kube-vip-role
	rules:
	  - apiGroups: [""]
	    resources: ["services", "services/status", "nodes", "endpoints"]
	    verbs: ["list","get","watch", "update"]
	  - apiGroups: ["coordination.k8s.io"]
	    resources: ["leases"]
	    verbs: ["list", "get", "watch", "update", "create"]
	---
	kind: ClusterRoleBinding
	apiVersion: rbac.authorization.k8s.io/v1
	metadata:
	  name: system:kube-vip-binding
	roleRef:
	  apiGroup: rbac.authorization.k8s.io
	  kind: ClusterRole
	  name: system:kube-vip-role
	subjects:
	- kind: ServiceAccount
	  name: kube-vip
	  namespace: kube-system
	---
	apiVersion: apps/v1
	kind: DaemonSet
	metadata:
	  labels:
	    app.kubernetes.io/name: kube-vip-ds
	    app.kubernetes.io/version: v0.5.12
	  name: kube-vip-ds
	  namespace: kube-system
	spec:
	  selector:
	    matchLabels:
	      app.kubernetes.io/name: kube-vip-ds
	  template:
	    metadata:
	      labels:
	        app.kubernetes.io/name: kube-vip-ds
	        app.kubernetes.io/version: v0.5.12
	    spec:
	      affinity:
	        nodeAffinity:
	          requiredDuringSchedulingIgnoredDuringExecution:
	            nodeSelectorTerms:
	            - matchExpressions:
	              - key: node-role.kubernetes.io/master
	                operator: Exists
	            - matchExpressions:
	              - key: node-role.kubernetes.io/control-plane
	                operator: Exists
	      containers:
	      - args:
	        - manager
	        env:
	        - name: vip_arp
	          value: "true"
	        - name: port
	          value: "6443"
	        - name: vip_interface
	          value: eth0
	        - name: vip_cidr
	          value: "32"
	        - name: cp_enable
	          value: "true"
	        - name: cp_namespace
	          value: kube-system
	        - name: vip_ddns
	          value: "false"
	        - name: vip_leaderelection
	          value: "true"
	        - name: vip_leaseduration
	          value: "30"
	        - name: vip_renewdeadline
	          value: "20"
	        - name: vip_retryperiod
	          value: "4"
	        - name: address
	          value: ${VIP}
	        - name: lb_enable
	          value: "true"
	        - name: prometheus_server
	          value: :2112
	        image: ghcr.io/kube-vip/kube-vip:v0.5.12
	        imagePullPolicy: Always
	        name: kube-vip
	        securityContext:
	          capabilities:
	            add:
	            - NET_ADMIN
	            - NET_RAW
	      hostNetwork: true
	      nodeSelector:
	        node-role.kubernetes.io/master: "true"
	      serviceAccountName: kube-vip
	      tolerations:
	      - effect: NoSchedule
	        operator: Exists
	      - effect: NoExecute
	        operator: Exists
	EOF
fi