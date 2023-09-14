# SCC

* [delete_all_systems.sh](./delete_all_systems.sh) a script to delete all systems registered to SCC. Use it with caution!
* [delete_unseen_systems.sh](./delete_unseen_systems.sh) a script to delete all systems registered to SCC that didn't reach scc a number of days (7 by default.) Use it with caution!
* [delete_unseen_systems.yaml](./delete_unseen_systems.yaml) a yaml file contaning an example Kubernetes deployment and secret to run the previous [delete_unseen_systems.sh](./delete_unseen_systems.sh) script as a pod in Kubernetes continuosly.
