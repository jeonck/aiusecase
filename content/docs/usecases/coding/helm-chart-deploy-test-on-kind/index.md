---
title: "Helm 차트 배포 테스트 — install·test·upgrade·실패·rollback을 로컬 kind에서 2분에"
description: "앞 사례의 kind 클러스터 위에 helm create로 차트를 만들고, lint → template → install → helm test → upgrade → 일부러 깨뜨린 upgrade → rollback까지 한 바퀴. 실패한 업그레이드 중에도 서비스가 살아 있는 걸 curl로 확인한다."
weight: 9
date: 2026-09-11
lastmod: 2026-09-11
icon: "deployed_code_update"
usecase: true
categories: ["코딩·개발"]
tools: ["Claude Code", "Helm", "kind", "kubectl"]
difficulty: "중급"
duration: "2분"
tags: ["Helm", "Kubernetes", "배포", "롤백", "kind", "테스트"]
---

## 어떤 문제를 해결하나

Helm 차트는 "values 만 바꾸면 되는 배포 단위" 인데, 실제로 그 차트가 **업그레이드와 롤백에서 어떻게 동작하는지**는 프로덕션에서 처음 겪는 팀이 많습니다. 실패한 업그레이드가 서비스를 끊는지, 롤백이 정말 이전 상태로 돌아오는지, `helm test` 가 뭘 검증하는지.

[로컬 kind 클러스터]({{< relref "/docs/usecases/coding/local-k8s-dev-env-kind-podman" >}})가 있으면 이걸 2분에 한 바퀴 돌 수 있습니다. Claude Code 에 "helm 차트 배포 테스트" 라고 하면 차트 생성부터 롤백 확인까지 명령과 결과를 남깁니다.

## 사전 준비

- 앞 사례의 kind 클러스터 (`kind-dev`) + ingress-nginx + `localhost/aiusecases:dev` 이미지가 노드에 적재된 상태
- `helm` (v4.2 사용). `brew install helm`
- 같은 이름의 Deployment 가 plain manifest 로 떠 있으면 먼저 지웁니다 (`kubectl delete -f site.yaml`). Helm 은 자기가 만들지 않은 리소스를 덮어쓰지 않습니다

## 단계별 사용법

{{< step title="helm create 로 뼈대를 만들고 안 쓰는 것을 뺀다" image="01-chart-lint-template.png" caption="차트 구조, lint 결과, template 출력에서 image·host·pullPolicy 확인. 렌더된 manifest 에 test hook 파드가 보입니다." >}}
{{< prompt title="입력 프롬프트" >}}
helm 차트 배포 테스트 유스케이스도 작성
{{< /prompt >}}

```bash
helm create aiusecases
rm aiusecases/templates/{hpa,serviceaccount,httproute}.yaml   # 이번엔 안 씀
sed -i '' '/serviceAccountName:/d' aiusecases/templates/deployment.yaml
```

[values.yaml](values.yaml) 에서 바꾼 것은 다섯 줄입니다.

```yaml
image:
  repository: localhost/aiusecases
  tag: "dev"
  pullPolicy: Never              # kind load 로 넣은 로컬 이미지
ingress:
  enabled: true
  className: "nginx"
  hosts: [{ host: aiusecases.localtest.me, … }]
```

배포 전 두 가지 검사:

```bash
helm lint aiusecases                                   # 1 chart(s) linted, 0 chart(s) failed
helm template aiusecases ./aiusecases -n demo | grep -E '^kind:|image:|host:|imagePullPolicy'
```

`template` 출력을 grep 으로 훑는 습관이 중요합니다. `install` 전에 이미지 이름·호스트·pullPolicy 가 의도대로 렌더됐는지 10초에 확인됩니다.
{{< /step >}}

{{< step title="install → helm test → upgrade" image="02-install-test-upgrade.png" caption="REVISION 1 배포, curl 200, 테스트 파드 Succeeded, replicaCount=2 로 REVISION 2." >}}
```bash
helm install aiusecases ./aiusecases -n demo --wait --timeout 120s
helm test aiusecases -n demo
helm upgrade aiusecases ./aiusecases -n demo --set replicaCount=2 --wait
```

`--wait` 는 파드가 Ready 될 때까지 기다렸다가 성공/실패를 돌려줍니다. 없으면 "deployed" 라고 해 놓고 파드는 CrashLoop 인 상황이 생깁니다.

`helm test` 는 차트에 들어 있는 `tests/test-connection.yaml` — busybox 파드가 서비스에 `wget` 하는 것 — 을 실행합니다. 기본 테스트는 "서비스가 응답하나" 수준이지만, 여기에 헬스체크 URL 이나 응답 본문 검사를 넣으면 배포 후 스모크 테스트가 됩니다.
{{< /step >}}

{{< step title="일부러 깨뜨리고 롤백한다" image="03-fail-rollback.png" caption="존재하지 않는 태그로 upgrade → UPGRADE FAILED. 새 파드만 ErrImageNeverPull, 기존 파드 2개는 Running, curl 은 200. rollback 2 → REVISION 4." >}}
```bash
helm upgrade aiusecases ./aiusecases -n demo --set image.tag=v2-typo --wait --timeout 45s
# Error: UPGRADE FAILED: resource Deployment/demo/aiusecases not ready … Updated: 1/2
```

여기서 볼 것 세 가지:

1. **서비스는 살아 있다.** 롤링 업데이트는 새 파드가 Ready 되기 전엔 기존 파드를 안 지웁니다. 실패 중에 `curl` 해도 200. 이게 "배포 실패 = 장애" 가 아닌 이유입니다
2. **실패한 리비전은 `failed` 로 기록**된다. `helm history` 에 3번이 남아 있어서, 나중에 "언제 누가 뭘 하다 실패했나" 를 추적할 수 있습니다
3. **롤백은 새 리비전**이다. `helm rollback aiusecases 2` 는 2번으로 "되돌리는" 게 아니라 2번과 같은 내용의 **4번**을 만듭니다. `helm get values` 를 보면 `replicaCount: 2` 만 남고 `image.tag` 오버라이드는 사라졌습니다

```bash
helm rollback aiusecases 2 -n demo --wait      # Rollback was a success!
helm history aiusecases -n demo                 # 1 superseded / 2 superseded / 3 failed / 4 deployed
```
{{< /step >}}

## 결과

| 단계 | 시각 |
| --- | --- |
| 차트 생성·values·lint·template | 17:03:54 → 17:04:18 |
| install + test | → 17:04:31 |
| upgrade (rev 2) | → 17:04:39 |
| 깨진 upgrade 실패 확인 (rev 3) | → 17:05:26 |
| rollback (rev 4) + 검증 | → 17:05:36 |
| **합계** | **1분 42초** |

차트 하나의 생애주기 — install, test, upgrade, failed upgrade, rollback — 를 실제 클러스터에서 겪었고, 각 단계의 리비전·파드 상태·서비스 응답이 기록으로 남았습니다. 이걸 프로덕션에서 처음 겪으면 각 단계가 30분짜리 사건입니다.

차트 파일: [aiusecases-0.1.0.tgz](aiusecases-0.1.0.tgz)

## 주의사항

- **`--wait` 없는 install/upgrade 는 성공을 보장하지 않습니다.** Helm 은 manifest 를 제출한 시점에 "deployed" 를 찍습니다. `--wait --timeout` 을 항상 붙이고, 타임아웃은 파드 기동 시간의 2~3배로.
- **롤백은 values 오버라이드도 되돌립니다.** `--set` 으로 얹은 값은 그 리비전에만 있습니다. 롤백 후 `helm get values` 로 현재 값을 확인하세요. 이 사례에서 `image.tag=v2-typo` 는 사라지고 `replicaCount=2` 만 남았습니다.
- **`helm test` 기본 테스트는 얕습니다.** "서비스에 연결된다" 만 봅니다. `tests/` 에 `/healthz` 호출, 기대 응답 문자열 검사, DB 연결 확인 파드를 추가해야 배포 게이트로 쓸 수 있습니다.
- **`helm create` 뼈대의 serviceAccount·hpa·httproute 는 안 쓰면 지우세요.** 남겨 두면 values 의 `enabled: false` 로 꺼지긴 하지만, 6개월 뒤 누군가 "이거 왜 있지" 하며 30분을 씁니다.
- **plain manifest 와 Helm 을 섞지 마세요.** 같은 이름의 Deployment 가 `kubectl apply` 로 떠 있으면 `helm install` 이 "already exists" 로 실패합니다. 한쪽으로 통일.
- 로컬 이미지(`pullPolicy: Never`)라서 태그 오류가 `ErrImageNeverPull` 로 즉시 드러났습니다. 레지스트리를 쓰면 `ImagePullBackOff` 로 같은 시나리오가 됩니다.

## 응용

- 사내 차트에 `tests/` 를 채우고 CI 에서 `kind create → helm install --wait → helm test` 를 PR 게이트로
- `helm upgrade --dry-run --debug` 와 `helm diff` 플러그인으로 업그레이드 전 변경 리소스만 보기
- `values-dev.yaml` / `values-prod.yaml` 을 나누고 로컬 kind 에서는 dev 값으로 같은 차트 검증
- 실패 리비전이 쌓이는 걸 막으려면 `helm upgrade --atomic` — 실패 시 자동 롤백
