An example app (nginx) to be managed via GitOps by Fleet

```
kind: GitRepo
apiVersion: fleet.cattle.io/v1alpha1
metadata:
  name: simple
  namespace: fleet-local
spec:
  repo: https://github.com/e-minguez/fleet-example
	branch: main
  paths:
  - simple
```

`fleet.yaml` contains the namespace for those workloads that doesn't specify any (all in this case)