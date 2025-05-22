#!/usr/bin/env bash
set -euo pipefail

kubectl get pods --all-namespaces -o jsonpath="{..image}" | tr -s '[[:space:]]' '\n' | sort | uniq
