#!/usr/bin/env bash
set -euo pipefail

# ——— CONFIGURATION ———
WORKDIR="./hauler_temp"
mkdir -p "${WORKDIR}"

# ——— 1. Add & update the Prime Helm repo ———
helm repo add rancher-prime https://charts.rancher.com/server-charts/prime
helm repo update

# ——— 2. Auto-detect Rancher version from your cluster (fallback to Helm) ———
if RANCHER_IMAGE=$(kubectl -n cattle-system get deployment rancher \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null); then
  RANCHER_VERSION="${RANCHER_IMAGE##*:}"
  echo "→ Detected Rancher image in cluster: ${RANCHER_IMAGE}"
  echo "→ Using Rancher version: ${RANCHER_VERSION}"
else
  echo "→ Could not detect Rancher in cattle-system, falling back to Helm query"
  RANCHER_VERSION=$(helm search repo rancher-prime/rancher \
    | awk 'NR==2 {print $3}')
  echo "→ Using Rancher GitHub release tag: ${RANCHER_VERSION}"
fi

# ——— 3. Download & fail if the tag doesn’t exist ———
PRIME_BASE="https://prime.ribs.rancher.io/rancher/${RANCHER_VERSION}"
curl -fSL "${PRIME_BASE}/rancher-images.txt" \
  -o "${WORKDIR}/orig-rancher-images.txt" \
|| {
  echo >&2 "ERROR: Rancher Prime release ${RANCHER_VERSION} not found at ${PRIME_BASE}"
  exit 1
}

# ——— 4. Filter out unneeded images ———
sed -E '/neuvector|minio|gke|aks|eks|sriov|harvester|mirrored|longhorn|thanos|tekton|istio|hyper|jenkins|windows/d' \
  "${WORKDIR}/orig-rancher-images.txt" \
  > "${WORKDIR}/cleaned-rancher-images.txt"

# Re-add Cluster API and kubectl entries
grep cluster-api "${WORKDIR}/orig-rancher-images.txt" >> "${WORKDIR}/cleaned-rancher-images.txt"
grep kubectl      "${WORKDIR}/orig-rancher-images.txt" >> "${WORKDIR}/cleaned-rancher-images.txt"

# ——— 5. Pick the latest tag for each repo ———
> "${WORKDIR}/rancher-unsorted.txt"
awk -F: '{print $1}' "${WORKDIR}/cleaned-rancher-images.txt" | sort -u |
while read -r repo; do
  grep -w "$repo" "${WORKDIR}/cleaned-rancher-images.txt" \
    | sort -Vr | head -1 \
    >> "${WORKDIR}/rancher-unsorted.txt"
done

# ——— 6. Final sort & dedupe ———
sort -u "${WORKDIR}/rancher-unsorted.txt" > "${WORKDIR}/rancher-images.txt"

# ——— 7. Manual fix-ups ———
{
  echo "rancher/kubectl:v1.20.2"
  echo "rancher/shell:v0.1.24"
  grep mirrored-ingress-nginx "${WORKDIR}/orig-rancher-images.txt"
} >> "${WORKDIR}/rancher-images.txt"

# ——— 8. Generate airgap_hauler.yaml ———
cat > airgap_hauler.yaml <<EOF
images:
EOF
while read -r img; do
  echo "  - name: ${img}"
done < "${WORKDIR}/rancher-images.txt" >> airgap_hauler.yaml

echo "  • ${WORKDIR}/rancher-images.txt"
echo "  • airgap_hauler.yaml"
