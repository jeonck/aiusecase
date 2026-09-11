#!/usr/bin/env bash
# CKA 연습용 kind 클러스터: control-plane 1 + worker 2, Calico(NetworkPolicy), metrics-server
# 사용: ./cka-setup.sh            (Podman machine 실행 중이어야 한다)
set -euo pipefail
export KIND_EXPERIMENTAL_PROVIDER=podman
DIR="$(cd "$(dirname "$0")" && pwd)"

kind create cluster --config "$DIR/kind-cka.yaml"

# Calico — Tigera operator. CRD 가 등록될 시간을 준 뒤 custom-resources 를 넣는다 (바로 넣으면 'no matches for kind' 로 실패)
CALICO=$(curl -s https://api.github.com/repos/projectcalico/calico/releases/latest | grep -m1 '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/v$CALICO/manifests/tigera-operator.yaml"
kubectl -n tigera-operator rollout status deploy/tigera-operator --timeout=180s
until kubectl get crd installations.operator.tigera.io >/dev/null 2>&1; do sleep 2; done
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/v$CALICO/manifests/custom-resources.yaml"
until [ "$(kubectl get nodes --no-headers | grep -c ' Ready')" = 3 ]; do sleep 5; done

# metrics-server — kind 는 kubelet 인증서가 자체 서명이라 insecure-tls 필요
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deploy metrics-server --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl -n kube-system rollout status deploy/metrics-server --timeout=180s

kubectl get nodes -o wide
kubectl get tigerastatus
echo "done. context: kind-cka"
