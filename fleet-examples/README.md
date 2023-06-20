# fleet-examples

* [Simple](./fleets/simple) a deployment + service (x86_64 & arm64)

```
kubectl apply -f https://raw.githubusercontent.com/suse-edge/misc/main/fleet-examples/gitrepos/simple-gitrepo.yaml
```

* [Akri](./fleets/akri) - [Akri](https://github.com/project-akri/akri) via [SUSE Edge charts repository](https://suse-edge.github.io/charts/)

```
kubectl apply -f https://raw.githubusercontent.com/suse-edge/misc/main/fleet-examples/gitrepos/akri-suse-edge-gitrepo.yaml
```

* [Elemental](./fleets/elemental) - [Elemental Operator](https://github.com/rancher/elemental-operator), including the [Rancher's UI Plugin Operator](https://github.com/rancher/ui-plugin-operator) and the [Elemental's Rancher UI Plugin](https://github.com/rancher/ui-plugin-charts/):

```
kubectl apply -f https://raw.githubusercontent.com/suse-edge/misc/main/fleet-examples/gitrepos/elemental-gitrepo.yaml
```