---
title: "CKA 유형별 연습 문제 12제 — setup·check 스크립트로 채점까지 자동"
description: "시험 5개 영역을 덮는 12문제. setup.sh가 고장 시나리오(오타 이미지, 잘못된 selector, kubelet 중지)를 심고, check.sh가 결과 기준으로 PASS/FAIL을 찍는다. 모범 답안을 순서대로 풀다 노드 문제를 뒤로 미뤄 두 문제가 Pending이 된 것까지 그대로."
weight: 12
date: 2026-09-11
lastmod: 2026-09-11
icon: "quiz"
usecase: true
categories: ["코딩·개발"]
tools: ["Claude Code", "kind", "kubectl", "Calico"]
difficulty: "중급"
duration: "40분"
tags: ["CKA", "연습문제", "Kubernetes", "자격증", "채점", "트러블슈팅"]
---

## 어떤 문제를 해결하나

CKA 연습의 어려움은 문제가 아니라 **채점**입니다. 풀고 나서 맞았는지 스스로 확인해야 하고, 고장 시나리오는 누군가 미리 망가뜨려 놔야 합니다. 혼자 하면 둘 다 안 됩니다.

[앞 사례의 cka 클러스터]({{< relref "/docs/usecases/coding/cka-practice-cluster-kind-calico" >}}) 위에서 Claude Code 가 세 가지를 만들었습니다.

- `setup.sh` — 네임스페이스를 초기화하고 고장 시나리오 3개를 심는다 (이미지 태그 오타, Service selector 불일치, worker2 kubelet 중지)
- `problems.txt` — 12문제. 시험 커리큘럼 5영역(아키텍처·워크로드·네트워킹·스토리지·트러블슈팅)
- `check.sh` — 문제마다 **결과**를 검사해 PASS/FAIL. readyReplicas, endpoint 수, wget 성공/타임아웃, `can-i`, 파일 내용

그리고 모범 답안을 직접 풀어 12/12 를 확인했습니다 — 첫 시도는 8/12 였고, 그 실패가 이 세트의 가장 중요한 교훈이 됐습니다.

## 사전 준비

- [cka 클러스터]({{< relref "/docs/usecases/coding/cka-practice-cluster-kind-calico" >}}) (worker 2 + Calico). NetworkPolicy 문제(Q6)는 Calico 없이는 채점이 안 됩니다
- `export KIND_EXPERIMENTAL_PROVIDER=podman`
- 파일 5개를 한 폴더에: [setup.sh](setup.sh) · [problems.txt](problems.txt) · [check.sh](check.sh) · [solutions.sh](solutions.sh) · [solutions.txt](solutions.txt)

## 단계별 사용법

{{< step title="setup.sh 로 시나리오를 심고, 풀기 전 check.sh 를 본다" image="01-setup-check-before.png" caption="풀기 전 11 FAIL. Q11 만 PASS 인 건 kubelet 을 멈춘 직후라 노드 상태가 아직 NotReady 로 바뀌기 전(약 40초 걸림)." >}}
{{< prompt title="입력 프롬프트" >}}
cka 시험 유형별 연습 문제 세트도 유스케이스로 작성
{{< /prompt >}}

```bash
./setup.sh      # ns apps/secure/storage/trouble 초기화, taint·PV·백업 제거, 고장 3개 심기
./check.sh      # 11 FAIL — 이 상태에서 시작
```

12문제 요약 ([problems.txt](problems.txt) 전문):

| # | 영역 | 문제 |
| --- | --- | --- |
| 1 | Workloads | Deployment `api` 3 replicas, requests 100m/64Mi |
| 2 | Workloads | 1.28 로 롤링 업데이트 후 롤백 |
| 3 | Scheduling | 파드를 `cka-worker2` 에 고정 |
| 4 | Scheduling | taint `dedicated=db:NoSchedule` + toleration 파드를 그 노드에 |
| 5 | Services | ClusterIP 8080→80 |
| 6 | Networking | `access=granted` 만 접근 허용하는 NetworkPolicy |
| 7 | Storage | hostPath PV + PVC + 마운트 후 파일 쓰기 |
| 8 | Config | ConfigMap·Secret 을 env 로 |
| 9 | RBAC | deployments create/list 만 되는 SA |
| 10 | Troubleshooting | 안 뜨는 Deployment + 안 가는 Service 고치기 |
| 11 | Troubleshooting | NotReady 노드 복구 |
| 12 | Cluster | etcd 스냅샷 |
{{< /step >}}

{{< step title="첫 시도 — 순서대로 풀다 두 문제가 Pending 이 된다" image="02-first-attempt-lesson.png" caption="Q3·Q7 의 파드가 NotReady 인 worker2 에 배정돼 Pending. 원인은 아직 안 푼 Q11. 클러스터 상태 문제를 뒤로 미룬 대가." >}}
모범 답안을 1번부터 순서대로 실행했습니다. Q7 에서 `data-pod` 가 뜨지 않아 멈췄고, 체커는 8/12.

- Q3 `pinned` — `nodeName: cka-worker2` 로 박았는데 그 노드가 NotReady → Pending
- Q7 `data-pod` — 스케줄러가 worker2 에 올렸는데 kubelet 이 죽어 있음 → Pending
- Q11 — 아직 안 풀었음. `kubectl describe node cka-worker2` → `Kubelet stopped posting node status`

시험에서도 똑같이 일어납니다. 트러블슈팅 문제(30%)는 뒤쪽에 있지만, **클러스터 상태에 관한 것은 먼저 풀어야** 앞 문제들이 정상 동작합니다. `solutions.sh` 는 이 교훈을 반영해 Q11 을 맨 앞으로 옮겼습니다.

```bash
podman exec cka-worker2 systemctl start kubelet      # 시험: ssh cka-worker2 → sudo systemctl start kubelet
```
{{< /step >}}

{{< step title="노드부터 살리고 다시 — 12/12" image="03-check-all-pass.png" caption="setup.sh 로 초기화 후 순서를 바꾼 solutions.sh 실행. 15초, 12 PASS." >}}
```bash
./setup.sh && ./solutions.sh && ./check.sh
# ----- 12 PASS / 0 FAIL
```

check.sh 가 보는 것은 정답 YAML 이 아니라 결과입니다. 예를 들어 Q6 은 라벨 있는 busybox 와 없는 busybox 로 실제 `wget` 을 쏴서 하나는 응답, 하나는 `timed out` 이어야 PASS. Q9 는 `kubectl auth can-i` 네 번. Q7 은 파드 안의 파일 내용. 어떤 방법으로 풀든(명령형·YAML·nodeName·nodeSelector) 결과가 맞으면 통과합니다.

풀이 노트는 [solutions.txt](solutions.txt) — 문제마다 시험장에서 떠올릴 명령 한 줄과 함정.
{{< /step >}}

## 결과

| | |
| --- | --- |
| 문제 수 | 12 (5영역) |
| 자동 채점 | check.sh, 문제당 결과 기준 |
| 고장 시나리오 | 3 (이미지 오타 · selector 불일치 · kubelet 중지) |
| 모범 답안 실행 | 15초, 12/12 |
| 첫 시도 | 8/12 — 순서 교훈 |
| 초기화 | `./setup.sh` 로 몇 번이고 |

40분 목표로 풀고 `./check.sh`, 틀린 것만 `solutions.txt` 보고 다시. 세트를 다 맞히면 `setup.sh` 의 고장 시나리오를 바꿔서(다른 오타, 다른 네임스페이스, PVC accessMode 불일치) 새 세트를 만들면 됩니다 — Claude 에게 "고장 시나리오 3개 더" 라고 하면 됩니다.

## 주의사항

- **클러스터 상태 문제를 먼저.** 이 세트가 실제로 증명한 것. NotReady 노드를 두고 파드 문제를 풀면 파드가 그 노드로 가서 Pending 이 됩니다.
- **check.sh 는 시험에 없습니다.** 연습 때는 문제를 푼 뒤 체커 대신 `kubectl get/describe` 로 직접 확인하는 습관을 들이세요. 체커는 마지막에 한 번.
- **setup.sh 는 kubelet 을 멈춥니다.** Q11 시나리오 때문입니다. 연습을 안 할 때도 `cka-worker2` 가 NotReady 로 남으니, 끝나면 `podman exec cka-worker2 systemctl start kubelet`.
- **PV 는 cluster-scoped.** 네임스페이스를 지워도 `pv-data` 는 남습니다. setup.sh 가 지우지만 직접 만든 PV 는 직접 정리.
- Q3 을 `nodeName` 으로 풀면 스케줄러를 건너뛰어 노드가 죽어 있어도 배정됩니다. 시험에선 빠르지만, 실무에선 nodeSelector/affinity.
- 시간 제한 없이 풀면 의미가 없습니다. 타이머 40분.

## 응용

- 같은 구조로 **CKAD 세트**(Probe, Job/CronJob, multi-container, SecurityContext) — setup/check 패턴 그대로
- 팀 스터디: 한 사람이 setup.sh 에 고장 시나리오를 추가하고, 나머지가 푼다
- 기출 유형 추가: 인증서 만료 확인(`kubeadm certs check-expiration`), 정적 파드, Ingress 규칙, HPA
- check.sh 결과를 매일 기록해 영역별 약점 추적
