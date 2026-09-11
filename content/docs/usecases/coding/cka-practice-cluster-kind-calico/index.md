---
title: "CKA 연습용 클러스터 — worker 2 + Calico + metrics-server, 시험 범위 4가지 검증까지"
description: "kind 로 control-plane 1 + worker 2 클러스터를 만들되 기본 CNI 를 끄고 Calico 를 올려 NetworkPolicy 가 실제로 동작하게 한다. metrics-server 까지 붙인 뒤 NetworkPolicy·drain·etcd 스냅샷·RBAC 네 가지를 시험 문제처럼 돌려 확인. 재현 스크립트 포함."
weight: 11
date: 2026-09-11
lastmod: 2026-09-11
icon: "school"
usecase: true
categories: ["코딩·개발"]
tools: ["Claude Code", "kind", "Calico", "metrics-server", "kubectl"]
difficulty: "중급"
duration: "6분"
tags: ["CKA", "Kubernetes", "kind", "Calico", "NetworkPolicy", "etcd", "RBAC", "자격증"]
---

## 어떤 문제를 해결하나

CKA 는 손으로 푸는 시험입니다. 연습 환경이 있어야 하는데, `kind create cluster` 기본값으로 만든 클러스터는 두 가지가 빠져 있습니다.

- **NetworkPolicy 가 안 먹습니다.** 기본 CNI(kindnet)가 정책을 구현하지 않아, 정책을 만들어도 트래픽이 그냥 통합니다. 시험에서 가장 자주 틀리는 영역인데 연습이 안 되는 셈
- **`kubectl top` 이 안 됩니다.** metrics-server 가 없고, 넣어도 kind 의 자체 서명 인증서 때문에 옵션을 하나 더 줘야 합니다

[앞 사례]({{< relref "/docs/usecases/coding/local-k8s-dev-env-kind-podman" >}})의 개발용 클러스터를 지우고, 시험 범위에 맞춘 클러스터를 새로 만들었습니다. 만들고 끝이 아니라 **시험 문제 유형 네 가지를 실제로 돌려** 환경이 맞는지 확인했습니다.

## 사전 준비

- kind, kubectl, Podman machine (앞 사례와 동일). `export KIND_EXPERIMENTAL_PROVIDER=podman`
- 메모리: 3노드 + Calico 가 약 2.5GB. Podman machine 6GiB 에서 다른 클러스터와 동시에 띄우기는 빠듯해 기존 `dev` 는 지웠습니다
- 재현은 [cka-setup.sh](cka-setup.sh) 한 번 — 아래 단계를 순서·대기 포함해 그대로 담았습니다

## 단계별 사용법

{{< step title="기본 CNI 를 끄고 만든다 → Calico → metrics-server" image="01-create-calico-metrics.png" caption="NotReady 3개(CNI 없음, 정상) → Calico 적용 → Ready 3개 → kubectl top nodes." >}}
{{< prompt title="입력 프롬프트" >}}
cka 연습용 클러스터 하나 더 만들어줘. 만들면서 유스케이스로도 작성하면 일석이조.
만든이후에는 기존에 argocd 유스케이스까지 했던 클러스터는 삭제해도 될 것 같은데.
{{< /prompt >}}

[kind-cka.yaml](kind-cka.yaml) 의 핵심은 두 줄입니다.

```yaml
networking:
  disableDefaultCNI: true        # kindnet 대신 Calico 를 쓰기 위해
  podSubnet: 192.168.0.0/16      # Calico 기본 IPPool 과 맞춘다
nodes: [control-plane, worker, worker]
```

```bash
kind create cluster --config kind-cka.yaml                                  # 29초, 노드는 NotReady
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/tigera-operator.yaml
kubectl -n tigera-operator rollout status deploy/tigera-operator             # ← 이걸 기다리고
kubectl apply  -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.2/manifests/custom-resources.yaml
```

operator 직후 custom-resources 를 넣으면 `no matches for kind "Whisker"` — CRD 가 아직 없어서입니다. operator 가 뜬 뒤 다시 넣으면 됩니다. 2분쯤 지나면 `kubectl get tigerastatus` 가 전부 `AVAILABLE True`, 노드 3개 Ready.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deploy metrics-server --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl top nodes
```
{{< /step >}}

{{< step title="시험 범위 4가지를 문제처럼 돌려 본다" image="02-cka-smoke.png" caption="NetworkPolicy 가 실제로 막고 푸는 것, drain 후 파드 이동, etcd 스냅샷 상태, RBAC can-i." >}}
환경이 시험과 같은지는 문제를 풀어 봐야 압니다. 네 가지를 골랐습니다.

**① NetworkPolicy** — [deny-all.yaml](deny-all.yaml), [allow-probe.yaml](allow-probe.yaml)

| 상태 | `wget http://web` 결과 |
| --- | --- |
| 정책 없음 | `Welcome to nginx!` |
| default-deny-ingress 적용 | `download timed out` ← **Calico 라서 막힘** |
| `role=probe` 파드만 허용 | `Welcome to nginx!` |

기본 kindnet 이었으면 두 번째 줄도 통과해서, 정책을 잘못 써도 모릅니다.

**② drain / cordon** — worker 두 개라 가능합니다. `web` 4 replicas 를 2/2 로 올린 뒤 `kubectl drain cka-worker --ignore-daemonsets --delete-emptydir-data` → 4개가 전부 `cka-worker2` 로. `Ready,SchedulingDisabled` 확인 후 `uncordon`.

**③ etcd 스냅샷** — 시험 단골. kind 의 etcd 컨테이너는 **distroless 라 `sh` 가 없습니다.** `exec -- sh -c` 는 실패하고 `etcdctl` 을 바로 실행해야 합니다.

```bash
kubectl -n kube-system exec etcd-cka-control-plane -- etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/lib/etcd/snap.db
kubectl -n kube-system exec etcd-cka-control-plane -- etcdutl snapshot status /var/lib/etcd/snap.db -w table
# | 5c90bd24 | 3484 | 927 | 11 MB | 3.6.0 |
```

시험 환경은 노드에 `etcdctl` 이 깔려 있어 `ssh node` 뒤에 바로 칩니다. 여기서는 `podman exec cka-control-plane` 이 그 `ssh` 에 해당합니다.

**④ RBAC** — `sa` + `role(get,list pods)` + `rolebinding` 만들고 `kubectl auth can-i … --as=system:serviceaccount:default:deploy-viewer` 로 yes/no/no 확인.
{{< /step >}}

## 결과

| 단계 | 소요 |
| --- | --- |
| dev 클러스터 삭제 + cka 생성 | 29초 |
| Calico (CRD 대기 포함) | 약 2분 |
| metrics-server | 약 1분 |
| 시험 유형 4가지 검증 | 1분 30초 |

NetworkPolicy 가 진짜로 막히고, 노드 3개라 drain 이 되고, `kubectl top` 이 나오고, etcd 스냅샷이 떠지는 클러스터. 연습 후 지저분해지면 `kind delete cluster --name cka && ./cka-setup.sh` 로 5분 안에 새 것.

## 주의사항

- **Calico custom-resources 는 operator 가 뜬 뒤에.** 바로 넣으면 `no matches for kind` 로 실패합니다. 스크립트에는 `until kubectl get crd installations.operator.tigera.io` 대기를 넣었습니다.
- **`podSubnet` 을 Calico 기본값(192.168.0.0/16)에 맞추세요.** 안 맞으면 custom-resources 의 `cidr` 도 같이 고쳐야 합니다.
- **etcd 파드에 `sh` 가 없습니다.** `exec -- etcdctl …` 처럼 바이너리를 직접. 시험에서는 노드에 SSH 해서 치므로 이 차이만 알아 두면 됩니다.
- **drain 은 시스템 파드도 쫓아냅니다.** `--ignore-daemonsets` 를 빼면 DaemonSet 때문에 실패하고, `--delete-emptydir-data` 를 빼면 emptyDir 파드에서 멈춥니다. 시험에서 나오는 오류 메시지 그대로 연습됩니다.
- **kind 는 노드를 나중에 추가하지 못합니다.** worker 를 더 원하면 yaml 고치고 재생성.
- Mac 재부팅 후에는 `podman start cka-control-plane cka-worker cka-worker2` 로 노드 컨테이너를 다시 올려야 합니다. etcd 데이터는 컨테이너 안에 있어 유지됩니다.
- `~/.zshrc` 에 `export KIND_EXPERIMENTAL_PROVIDER=podman` 을 넣어 두면 매번 안 잊습니다.

## 응용

- 시험 유형별 연습 세트: `kubectl create deploy … --dry-run=client -o yaml` 로 YAML 뼈대 뽑기, `kubectl explain`, 노드 장애 시뮬레이션(`podman stop cka-worker2`), 인증서 갱신(`kubeadm certs check-expiration` 은 control-plane 컨테이너 안에서)
- 업그레이드 연습은 kind 로는 제한적(노드 이미지 교체 방식). 필요하면 kubeadm 기반 VM 으로
- Ingress 문제 유형이 필요하면 앞 사례의 ingress-nginx 설치를 그대로 추가 (포트 매핑은 이 yaml 에 없으니 `extraPortMappings` 추가)
- 같은 스크립트로 팀 스터디원 전원이 동일 환경 — `cka-setup.sh` 하나 공유
