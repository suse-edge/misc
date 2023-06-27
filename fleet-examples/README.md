# fleet-examples

* [Simple](./fleets/simple) a deployment + service (x86_64 & arm64)

```
kubectl apply -f https://raw.githubusercontent.com/suse-edge/misc/main/fleet-examples/gitrepos/simple-gitrepo.yaml
```

* [Akri](./fleets/akri) - [Akri](https://github.com/project-akri/akri) via [SUSE Edge charts repository](https://suse-edge.github.io/charts/)

```
kubectl apply -f https://raw.githubusercontent.com/suse-edge/misc/main/fleet-examples/gitrepos/akri-suse-edge-gitrepo.yaml
```

* [Kubevirt](./fleets/kubevirt) - [Kubevirt](https://github.com/kubevirt/kubevirt) via [SUSE Edge charts repository](https://suse-edge.github.io/charts/)

```
kubectl apply -f https://raw.githubusercontent.com/suse-edge/misc/main/fleet-examples/gitrepos/kubevirt-suse-edge-gitrepo.yaml
```

* [Elemental](./fleets/elemental) - [Elemental Operator](https://github.com/rancher/elemental-operator), including the [Elemental's Rancher UI Plugin](https://github.com/rancher/ui-plugin-charts/):

```
kubectl apply -f https://raw.githubusercontent.com/suse-edge/misc/main/fleet-examples/gitrepos/elemental-gitrepo.yaml
```

NOTE: If the [Rancher's UI Plugin Operator](https://github.com/rancher/ui-plugin-operator) is not installed, enable the installation in the [Elemental Gitrepo](./gitrepos/elemental-gitrepo.yaml) file.

* [Opni](./fleets/opni) - [Opni](https://github.com/rancher/opni), including the [Opni's Rancher UI Plugin](https://github.com/rancher/opni-ui/):

```
kubectl apply -f https://raw.githubusercontent.com/suse-edge/misc/main/fleet-examples/gitrepos/opni-gitrepo.yaml
```

NOTE: If the [Rancher's UI Plugin Operator](https://github.com/rancher/ui-plugin-operator) is not installed, enable the installation in the [Opni Gitrepo](./gitrepos/opni-gitrepo.yaml) file.

* [Rancher's UI Plugin Operator](./fleets/rancher-ui-plugin-operator) - [Rancher's UI Plugin Operator](https://github.com/rancher/ui-plugin-operator):

```
kubectl apply -f https://raw.githubusercontent.com/suse-edge/misc/main/fleet-examples/gitrepos/rancher-ui-plugin-operator-gitrepo.yaml
```

* [Longhorn](./fleets/longhorn) - [Longhorn](https://longhorn.io/):

```
kubectl apply -f https://raw.githubusercontent.com/suse-edge/misc/main/fleet-examples/gitrepos/longhorn-gitrepo.yaml
```

A few notes about this example:

* Longhorn creates its own `storageclass` and if using K3s default configuration you can end up with two default `storageclasses`:

```
$ kubectl get sc
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  26m
longhorn (default)     driver.longhorn.io      Delete          Immediate              true                   2s
```

To make the `longhorn` one the default, you can remove the `is-default-class` annotation from the `local-path` one as:

```
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

If you want to remove the annotation to the `longhorn` one, you need to tweak the [Helm parameters](https://github.com/longhorn/longhorn/blob/master/chart/values.yaml#L83-L84) as:

```
persistence.defaultClass=false
```

* The Longhorn UI is not exposed by default. If you want to expose it, you need to specify a couple of Helm values such as:

```
ingress:
  enabled: true
  host: "longhorn-example.com"
```

You can modify the Longhorn's [fleet.yaml](./fleets/longhorn/fleet.yaml) file to fit your needs.

* You can configure Fleet to read Helm custom values in a configmap created somewhere in the cluster such as:

```
  valuesFrom:
  - configMapKeyRef:
      name: longhorn-chart-values
      # default to namespace of bundle
      namespace: fleet-local
      key: values.yaml
```

Basically you can create a configmap there with the `values.yaml` content you want to provide. This is not restricted to ingress but anything included in the [Longhorn Helm Chart values.yaml](https://github.com/longhorn/longhorn/blob/master/chart/values.yaml) can be used:

```
cat <<- EOF | kubectl apply -f -
apiVersion: v1
data:
  values.yaml: |
    ingress:
      enabled: true
      host: "longhorn-example.com"
kind: ConfigMap
metadata:
  name: longhorn-chart-values
  namespace: fleet-local
EOF
```

* The Fleet included here contains a customization such as:

```
targetCustomizations:
  # Customization Name
- name: local
  # If the local cluster is used
  clusterSelector:
    matchLabels:
      management.cattle.io/cluster-display-name: local
  helm:
    values:
      ingress:
        # Use this custom Helm values
        enabled: true
        # This is a manual annotation that needs to be set in the clusters.fleet.cattle.io/local object
        host: longhorn-${ .ClusterAnnotations.ingressip }.sslip.io
        # This annotation will enable user/password authentication for the Longhorn UI
        annotations:
          traefik.ingress.kubernetes.io/router.middlewares: longhorn-system-longhorn-basic-auth@kubernetescrd
  # This kustomization will create the required objects for the user/password authentication
  kustomize:
    dir: overlays/local
```

This means:
  * If using a local cluster
  * If the Traefik Ingress controller is deployed
  * If the Traefik Ingress uses sslip.io
  * If the local cluster has been annotated with the Ingress IP:

`kubectl annotate clusters.fleet.cattle.io/local -n fleet-local  "ingressip=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"`

It will enable the Longhorn UI protected via user/password using a [kustomization overlay](./fleets/longhorn/longhorn/overlays/kustomization.yaml)

This is basically intended to be used with the [create-vm.sh](../slemicro/create_vm.sh) script as:

```
./create_vm.sh -f myvm
export KUBECONFIG=$(./get_kubeconfig.sh -f myvm -w)
kubectl annotate clusters.fleet.cattle.io/local -n fleet-local "ingressip=$(kubectl get svc -n kube-system traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
kubectl apply -f https://raw.githubusercontent.com/suse-edge/misc/main/fleet-examples/gitrepos/longhorn-gitrepo.yaml
```

**NOTE:** Due to https://github.com/rancher/fleet/issues/1507, this needs to be done before applying the longhorn gitrepo:

```
helm -n cattle-fleet-system upgrade --create-namespace fleet-crd https://github.com/rancher/fleet/releases/download/v0.7.0/fleet-crd-0.7.0.tgz
helm -n cattle-fleet-system upgrade --create-namespace fleet https://github.com/rancher/fleet/releases/download/v0.7.0/fleet-0.7.0.tgz
```

* To uninstall the application, it is required to set the `deleting-confirmation-flag` to true as per [the instructions](https://longhorn.io/docs/1.4.2/deploy/uninstall/#prerequisite) before removing the Helm chart or the `gitrepo` object:

```
kubectl -n longhorn-system patch -p '{"value": "true"}' --type=merge lhs deleting-confirmation-flag
```