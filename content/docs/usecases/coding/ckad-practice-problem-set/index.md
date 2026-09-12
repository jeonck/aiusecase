---
title: "CKAD 연습 문제 12제 — 사이드카·Job·Blue/Green·Probe·SecurityContext까지 자동 채점"
description: "CKAD 5영역을 덮는 12문제와 setup·check·solutions 스크립트. 같은 kind 클러스터에서 CKA 세트와 나란히 쓴다. 두 세트가 서로 간섭한 사고(CKA 세트가 멈춘 kubelet 때문에 네임스페이스 삭제가 11분 멈춤)까지 기록."
weight: 13
date: 2026-09-11
lastmod: 2026-09-11
icon: "developer_guide"
usecase: true
categories: ["코딩·개발"]
tools: ["Claude Code", "kind", "kubectl", "Helm", "Calico"]
difficulty: "중급"
duration: "40분"
tags: ["CKAD", "연습문제", "Kubernetes", "자격증", "채점", "사이드카", "Job"]
---

## 어떤 문제를 해결하나

CKAD 는 CKA 보다 **파드 안쪽**을 봅니다 — 사이드카, Job/CronJob, probe, securityContext, ConfigMap/Secret, ServiceAccount, 배포 전략. 클러스터 운영보다 YAML 을 정확히 빨리 쓰는 시험입니다.

[CKA 세트]({{< relref "/docs/usecases/coding/cka-practice-problem-set" >}})와 같은 구조로 만들었습니다: `setup.sh` 가 시나리오를 심고, `check.sh` 가 결과를 채점하고, `solutions.sh` 로 12/12 를 검증했습니다. 이번엔 만드는 과정에서 **두 세트가 서로 간섭하는 사고**를 겪었고, 그게 setup.sh 의 첫 줄이 됐습니다.

## 사전 준비

- [cka 클러스터]({{< relref "/docs/usecases/coding/cka-practice-cluster-kind-calico" >}}) + `helm`
- 파일 5개: [setup.sh](setup.sh) · [problems.txt](problems.txt) · [check.sh](check.sh) · [solutions.sh](solutions.sh) · [solutions.txt](solutions.txt)
- CKA 세트를 돌린 뒤라면 `cka-worker2` 의 kubelet 이 꺼져 있을 수 있습니다. setup.sh 가 먼저 켭니다 (아래 사고 참조)

## 단계별 사용법

{{< step title="setup.sh — 시나리오 2개를 심는다, 그리고 사고" image="01-setup-and-pitfalls.png" caption="CrashLoopBackOff 파드와 로컬 차트 준비. 첫 solutions 실행의 YAML 오류, 그리고 네임스페이스 삭제가 11분 멈춘 원인." >}}
{{< prompt title="입력 프롬프트" >}}
CKAD 연습 문제 세트도 유스케이스로 작성
{{< /prompt >}}

setup.sh 는 네임스페이스 `ckad`, `ckad-helm`, `quota-ns` 를 초기화하고 두 가지를 심습니다.

- Q8 용 `crasher` 파드 — 시작하자마자 `config file … not found` 를 찍고 exit 1 → CrashLoopBackOff
- Q6 용 로컬 Helm 차트 `./mychart` (helm create 뼈대)

12문제 ([problems.txt](problems.txt) 전문):

| # | 영역 | 문제 |
| --- | --- | --- |
| 1 | Design | nginx + busybox 사이드카, emptyDir 로 access.log 공유·tail |
| 2 | Design | Job completions 3 / parallelism 2 / backoffLimit 2 |
| 3 | Design | CronJob 5분, Forbid, history 2 |
| 4 | Deployment | maxSurge 1 / maxUnavailable 0 |
| 5 | Deployment | Blue/Green — Service 가 green 만 |
| 6 | Deployment | 로컬 차트를 `--set replicaCount=2` 로 설치 |
| 7 | Observability | readiness + liveness httpGet, initialDelay 5 |
| 8 | Observability | CrashLoopBackOff 원인 찾고 고치기 |
| 9 | Security | runAsUser 1000 / nonRoot / no privesc / drop ALL |
| 10 | Security | ResourceQuota 아래서 requests 있는 파드 |
| 11 | Security | automount 끈 SA, 토큰 미마운트 확인 |
| 12 | Networking | Service + Ingress(host, class) |

**사고 1 — 모범 답안의 YAML 오류.** Q5 에서 `create deploy --dry-run` 출력에 `sed` 로 라벨 한 줄을 끼워 넣다 들여쓰기가 깨졌습니다. 라벨이 둘(app, version)인 Deployment 는 처음부터 YAML 로 쓰는 게 빠릅니다. 5/12.

**사고 2 — setup.sh 가 11분 멈춤.** 재실행하려는데 네임스페이스가 `Terminating` 에서 안 끝났습니다.

```
Failed to delete all resource types, 4 remaining: …/apis/projectcalico.org/v3/…/networkpolicies: Unauthorized
```

Calico 의 aggregated API 가 죽어 있었습니다. 왜? **CKA 세트의 Q11 시나리오가 `cka-worker2` 의 kubelet 을 멈춰 뒀고**, 그 노드에 있던 `calico-apiserver` 파드 2개가 `Terminating` 인 채 못 죽고 있었습니다. 네임스페이스 삭제는 모든 API 그룹의 리소스를 지워야 끝나는데 그 API 가 500 을 냅니다.

```bash
podman exec cka-worker2 systemctl start kubelet     # 30초 뒤 Terminating 정리 → 삭제 진행
```

그래서 setup.sh 첫 줄에 "모든 노드 kubelet 시작" 을 넣었습니다. 두 세트를 한 클러스터에서 번갈아 쓸 때 필요한 안전장치입니다.
{{< /step >}}

{{< step title="12/12 — check.sh 가 보는 것" image="02-check-all-pass.png" caption="YAML 을 고치고 노드를 살린 뒤 setup → solutions → check. 12 PASS." >}}
```bash
./setup.sh && ./solutions.sh && ./check.sh
# ----- 12 PASS / 0 FAIL
```

결과 기준 채점의 예:

- Q1 — 사이드카 컨테이너의 **로그에 `GET /` 줄**이 있어야 PASS. emptyDir 을 붙였는지가 아니라 실제로 공유되는지
- Q5 — Service 의 EndpointSlice 주소 목록이 **green 파드 IP 목록과 정확히 일치**해야 PASS
- Q8 — `crasher` 가 `Running` 이고 컨테이너 ready
- Q11 — 파드 안에서 `ls /var/run/secrets/kubernetes.io/serviceaccount` 가 **비어 있어야** PASS. `automountServiceAccountToken: false` 를 SA 에 걸었는지 파드에 걸었는지는 안 봅니다

풀이 노트는 [solutions.txt](solutions.txt). 각 문제의 함정 한 줄: Job 은 `create job` 으로 completions 를 못 준다, securityContext 는 파드 레벨과 컨테이너 레벨 위치가 다르다, 쿼터가 requests.cpu 를 걸면 requests 없는 파드는 거부된다 …
{{< /step >}}

## 결과

| | |
| --- | --- |
| 문제 수 | 12 (5영역) |
| 시나리오 | CrashLoopBackOff 파드, 로컬 Helm 차트 |
| 모범 답안 | 11초, 12/12 |
| 첫 시도 | 5/12 (YAML 들여쓰기) + 세트 간섭 사고 |
| 위치 | `~/ckad-practice/` (CKA 세트는 `~/cka-practice/`) |

CKA·CKAD 두 세트, 24문제, 같은 클러스터. 번갈아 풀 때는 각 setup.sh 가 상대 세트의 흔적(kubelet 정지, taint)을 정리합니다.

## 주의사항

- **두 세트를 한 클러스터에서 쓰면 setup.sh 를 꼭 거치세요.** CKA 의 kubelet 정지·taint 가 CKAD 문제를 이상하게 만들고, 반대로 CKAD 의 ResourceQuota 는 CKA 와 무관하지만 네임스페이스가 겹치지 않게 했습니다.
- **네임스페이스가 Terminating 에서 멈추면 aggregated API 를 의심하세요.** `kubectl get ns X -o jsonpath='{.status.conditions}'` 에 원인이 적혀 있습니다. Calico·metrics-server 같은 aggregated API 의 파드가 죽은 노드에 있으면 이렇게 됩니다. 시험에서도 나올 수 있는 진단입니다.
- **파드의 command 는 못 고칩니다.** Q8 은 지우고 다시 만드는 게 정답. `kubectl edit` 로 command 를 바꾸려 하면 거부됩니다.
- **라벨이 둘 이상인 Deployment 는 YAML 로.** `create deploy` 는 `app=<이름>` 하나만 붙입니다.
- check.sh 의 Q1 은 사이드카가 `access.log` 를 tail 하는 시점에 파일이 있어야 합니다. 모범 답안처럼 `touch` 를 먼저 하거나, nginx 가 파일을 만든 뒤 사이드카가 뜨게 하세요.
- 40분 타이머. CKAD 는 CKA 보다 문제 수가 많고 짧습니다 — 한 문제에 5분 넘게 붙잡히면 넘기세요.

## 응용

- 두 세트를 합쳐 **모의고사 24문제 2시간** — CKA 15 + CKAD 9 식으로 섞기
- 시나리오 추가: init container 순서 문제, `envFrom` 전체 주입, PodDisruptionBudget, Canary(replica 비율)
- check.sh 를 CI 에 걸어 스터디원 제출물을 자동 채점
- 틀린 문제만 다시 심는 `setup.sh --only 5,8` 옵션 (Claude 에게 시키면 5분)
