#!/usr/bin/env bash
# CKAD 연습 문제 세트 — 시나리오 준비. 컨텍스트 kind-cka. 여러 번 실행 가능.
set -euo pipefail
export KIND_EXPERIMENTAL_PROVIDER=podman
kubectl config use-context kind-cka >/dev/null
# CKA 세트가 worker2 kubelet 을 멈춰 둔 상태면 Calico apiserver 파드가 못 죽어 네임스페이스 삭제가 멈춘다 → 먼저 살린다
for n in cka-worker cka-worker2; do podman exec $n systemctl start kubelet >/dev/null 2>&1 || true; done
for ns in ckad ckad-helm quota-ns; do kubectl delete ns $ns --ignore-not-found --wait=false >/dev/null; done
helm uninstall demo -n ckad-helm >/dev/null 2>&1 || true
for ns in ckad ckad-helm quota-ns; do until ! kubectl get ns $ns >/dev/null 2>&1; do sleep 1; done; kubectl create ns $ns >/dev/null; done

# Q8 준비: 시작하자마자 죽는 파드 (CrashLoopBackOff)
kubectl -n ckad run crasher --image=busybox:1.36 --restart=Always -- sh -c 'echo "config file /etc/app/config.yaml not found"; exit 1' >/dev/null
# Q6 준비: 로컬 차트 뼈대
rm -rf mychart && helm create mychart >/dev/null && rm -f mychart/templates/{hpa,serviceaccount,httproute,ingress}.yaml && sed -i '' '/serviceAccountName:/d' mychart/templates/deployment.yaml
echo "setup done — problems.md 를 열어 시작. 검증: ./check.sh"
