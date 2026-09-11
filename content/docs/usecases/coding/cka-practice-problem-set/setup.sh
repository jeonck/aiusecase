#!/usr/bin/env bash
# CKA 연습 문제 세트 — 시나리오 준비. 컨텍스트 kind-cka 에서 실행. 여러 번 실행해도 된다(초기화 후 재생성).
set -euo pipefail
export KIND_EXPERIMENTAL_PROVIDER=podman
kubectl config use-context kind-cka >/dev/null
for ns in apps secure storage trouble; do kubectl delete ns $ns --ignore-not-found --wait=false >/dev/null; done
kubectl taint node cka-worker dedicated- >/dev/null 2>&1 || true
kubectl delete pv pv-data --ignore-not-found >/dev/null
podman exec cka-control-plane rm -f /var/lib/etcd/backup.db
kubectl uncordon cka-worker2 >/dev/null 2>&1 || true
podman exec cka-worker2 systemctl start kubelet >/dev/null 2>&1 || true
for ns in apps secure storage trouble; do until ! kubectl get ns $ns >/dev/null 2>&1; do sleep 1; done; kubectl create ns $ns >/dev/null; done

# Q6 준비: secure/web 과 접근 시도용 파드
kubectl -n secure run web --image=nginx:1.27-alpine --labels=app=web --port=80 >/dev/null
kubectl -n secure expose pod web --port=80 >/dev/null

# Q10 준비: 고장난 Deployment 와 Service
kubectl -n trouble create deploy broken --image=nginx:1.27-alpne --replicas=2 >/dev/null
kubectl -n trouble create svc clusterip broken-svc --tcp=80:80 >/dev/null
kubectl -n trouble patch svc broken-svc -p '{"spec":{"selector":{"app":"brokn"}}}' >/dev/null

# Q11 준비: worker2 kubelet 중지 → NotReady
podman exec cka-worker2 systemctl stop kubelet
echo "setup done — problems.md 를 열어 시작. 검증: ./check.sh"
