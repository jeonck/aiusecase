---
title: "Argo CD GitOps 배포 — Git 커밋이 곧 배포, 손으로 바꾸면 되돌아온다"
description: "앞 사례의 kind 클러스터에 Argo CD를 올리고, 이 저장소의 deploy/ 차트를 Application으로 등록해 자동 동기화. values.yaml을 커밋하면 파드가 늘고, kubectl로 줄이면 1초 만에 Git 상태로 되돌아온다. CRD 크기 오류와 3분 폴링 지연까지 기록."
weight: 10
date: 2026-09-11
lastmod: 2026-09-11
icon: "sync"
usecase: true
categories: ["코딩·개발"]
tools: ["Claude Code", "Argo CD", "Helm", "kind", "GitHub"]
difficulty: "고급"
duration: "5분"
tags: ["GitOps", "ArgoCD", "Kubernetes", "배포", "selfHeal", "kind"]
---

## 어떤 문제를 해결하나

`helm upgrade` 를 누가 언제 어떤 값으로 쳤는지는 셸 히스토리에만 남습니다. 누군가 `kubectl scale` 로 손을 대면 그 사실은 아무 데도 안 남습니다.
GitOps 는 이걸 뒤집습니다 — **Git 이 원본, 클러스터는 그 사본.** Argo CD 가 저장소를 보고 있다가 커밋이 들어오면 배포하고, 클러스터가 Git 과 달라지면 되돌립니다.

[로컬 kind]({{< relref "/docs/usecases/coding/local-k8s-dev-env-kind-podman" >}}) + [Helm 차트]({{< relref "/docs/usecases/coding/helm-chart-deploy-test-on-kind" >}}) 위에 Argo CD 를 얹어, 이 사이트 저장소의 `deploy/` 폴더를 Application 으로 등록하고 두 가지를 실험했습니다: **Git 을 바꾸면 클러스터가 따라오는가**, **클러스터를 손으로 바꾸면 Git 으로 돌아오는가.**

## 사전 준비

- kind 클러스터 + ingress-nginx + `localhost/aiusecases:dev` 이미지 적재 (앞 사례)
- Argo CD 가 읽을 수 있는 Git 저장소. 여기서는 이 사이트 저장소([jeonck/aiusecase](https://github.com/jeonck/aiusecase))에 `deploy/aiusecases` 차트를 넣었습니다 — 공개 저장소라 인증 불필요
- Helm 으로 설치해 둔 같은 이름의 릴리스가 있으면 **먼저 `helm uninstall`**. 두 주인이 한 Deployment 를 다투게 하면 안 됩니다

## 단계별 사용법

{{< step title="Argo CD 를 올리고 (CRD 오류 하나) Application 을 등록한다" image="01-install-and-app.png" caption="client-side apply 가 applicationsets CRD 에서 'Too long' — server-side apply 로 재적용. 45초 뒤 기동, Application 등록 40초 뒤 Synced/Healthy." >}}
{{< prompt title="입력 프롬프트" >}}
ArgoCD로 GitOps 배포 유스케이스도 작성
{{< /prompt >}}

```bash
helm uninstall aiusecases -n demo
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

`--server-side` 가 없으면 `applicationsets.argoproj.io` CRD 가 `metadata.annotations: Too long` 으로 거부됩니다. client-side apply 는 전체 manifest 를 `last-applied` 주석에 넣는데 이 CRD 가 256KB 를 넘기 때문입니다. Claude 가 오류 메시지를 보고 바로 바꿔 적용했습니다.

차트를 저장소에 넣고 Application 을 만듭니다 — [argocd-app.yaml](argocd-app.yaml):

```yaml
spec:
  source:
    repoURL: https://github.com/jeonck/aiusecase.git
    targetRevision: main
    path: deploy/aiusecases          # Helm 차트 디렉터리 → Argo CD 가 helm template 으로 렌더
  destination: { server: https://kubernetes.default.svc, namespace: demo }
  syncPolicy:
    automated:
      prune: true                    # Git 에서 지운 리소스는 클러스터에서도 지운다
      selfHeal: true                 # 클러스터를 손으로 바꾸면 Git 상태로 되돌린다
```

`kubectl apply -f deploy/argocd-app.yaml` → 40초 뒤 `Synced Healthy`, 사이트 200.
{{< /step >}}

{{< step title="UI 에서 Application 을 본다" image="02-argocd-app.png" caption="Argo CD v3.5 Applications 화면. Healthy · Synced, Repository·Path·Target Revision·Last Sync 가 한 카드에." >}}
```bash
kubectl -n argocd patch cm argocd-cmd-params-cm --type merge -p '{"data":{"server.insecure":"true"}}'
kubectl -n argocd rollout restart deploy/argocd-server
kubectl -n argocd port-forward svc/argocd-server 8081:80
```

로컬에서는 TLS 를 끄고(`server.insecure`) HTTP 로 port-forward 하는 게 편합니다. 초기 비밀번호는 `argocd-initial-admin-secret` 에 있습니다. 브라우저 조작(로그인·화면 이동·캡처)은 Claude 가 ego lite 로 했습니다.
{{< /step >}}

{{< step title="리소스 트리 — 차트가 무엇을 만들었는지 한눈에" image="03-argocd-tree.png" caption="Application → Service · Deployment · Ingress · (helm test 파드). Deployment 아래 ReplicaSet rev 1 과 파드 2개. 커밋 메시지가 'LAST SYNC' 에 그대로." >}}
Helm 차트의 리소스 4개가 트리로 보이고, 각 노드에 Health(하트)와 Sync(체크) 아이콘이 붙습니다. `helm test` 훅으로 들어간 `test-connection` 파드도 Argo CD 가 실행해 `completed 0/1` 로 표시합니다.

상단 `LAST SYNC` 에 **커밋 해시·작성자·커밋 메시지**가 뜹니다. "이 배포가 어느 커밋인가" 를 셸 히스토리가 아니라 UI 에서 봅니다.
{{< /step >}}

{{< step title="Git 을 바꾸면 클러스터가 따라오고, 손으로 바꾸면 되돌아온다" image="04-sync-and-selfheal.png" caption="values.yaml 의 replicaCount 1→2 커밋 → 2분 48초 뒤 파드 2개. kubectl scale 로 1개로 줄이자 1초 안에 2개로 복구." >}}
**실험 1 — Git → 클러스터.** `deploy/aiusecases/values.yaml` 의 `replicaCount: 2` 로 바꿔 커밋·푸시. 17:17:40 에 푸시했고 17:20:28 에 파드 2개가 Ready 됐습니다. **2분 48초** — Argo CD 기본 폴링 주기가 3분이기 때문입니다. GitHub 웹훅을 걸면 수 초로 줄어듭니다.

**실험 2 — 클러스터 → Git (selfHeal).**

```bash
kubectl -n demo scale deploy/aiusecases --replicas=1
kubectl -n demo get deploy aiusecases -o jsonpath='{.spec.replicas}'   # 1초 뒤: 2
```

Argo CD 가 Deployment 변경 이벤트를 받자마자 Git 의 값(2)으로 되돌렸습니다. `kubectl` 로 낸 변경은 **그냥 사라집니다** — 이게 GitOps 의 규칙이고, 운영 중 "누가 손댔지" 가 없어지는 이유입니다.
{{< /step >}}

{{< step title="History — 어느 커밋이 언제 배포됐나" image="05-argocd-history.png" caption="HISTORY AND ROLLBACK. 리비전 c08418e(첫 배포) → 045c37a(replicaCount 2). 배포 시각·커밋 메시지·자동 동기화 여부가 기록." >}}
`helm history` 가 리비전 번호만 보여 주던 것과 달리, Argo CD 히스토리는 **Git 커밋**과 1:1 입니다. 롤백도 여기서 커밋 단위로 합니다 — 단, 자동 동기화가 켜져 있으면 롤백 직후 다시 최신 커밋으로 돌아가므로, 진짜 롤백은 **Git 에서 revert 커밋**을 만드는 것입니다.
{{< /step >}}

## 결과

| 단계 | 시각 |
| --- | --- |
| Argo CD 설치 (CRD 오류 수정 포함) | 17:15:36 → 17:16:21 |
| 차트 커밋·푸시, Application 등록, 첫 Sync | → 17:17:26 |
| Git 변경 → 자동 반영 | 17:17:40 → 17:20:28 (폴링 3분) |
| selfHeal (kubectl scale 되돌림) | 1초 |
| UI 확인·캡처 | → 17:22 |

이제 이 클러스터의 `demo` 네임스페이스는 **`deploy/aiusecases` 폴더의 커밋 히스토리 그 자체**입니다. `kubectl apply` 도 `helm upgrade` 도 더 이상 쓰지 않습니다 — 써도 되돌아옵니다.

## 주의사항

- **`--server-side` 로 설치하세요.** Argo CD 의 CRD 는 client-side apply 의 주석 한도(256KB)를 넘습니다. 오류 메시지가 "invalid… Too long" 이면 이겁니다.
- **Helm 릴리스와 Argo CD Application 이 같은 리소스를 관리하게 두지 마세요.** 이 사례에서 `helm uninstall` 을 먼저 했습니다. Argo CD 가 Helm 차트를 배포할 때는 `helm template` 으로 렌더만 하고 `helm install` 을 하지 않습니다 — `helm list` 에 안 나오는 게 정상입니다.
- **폴링 3분은 로컬에서 답답합니다.** `argocd-cm` 의 `timeout.reconciliation` 을 줄이거나 GitHub 웹훅(`/api/webhook`)을 걸면 즉시 반영됩니다. 프로덕션에서는 웹훅이 표준입니다.
- **`selfHeal: true` 는 디버깅을 방해합니다.** 문제 파드를 `kubectl edit` 로 잠깐 고쳐 보려 해도 되돌아갑니다. 디버깅 중엔 `argocd app set --sync-policy none` 으로 잠시 끄고, 끝나면 다시 켜세요.
- **`prune: true` 는 Git 에서 지운 것을 실제로 지웁니다.** 차트에서 리소스를 제거하고 커밋하는 순간 클러스터에서도 사라집니다. 의도한 동작이지만 처음엔 놀랍니다.
- 초기 admin 비밀번호는 로그인 후 바꾸고 `argocd-initial-admin-secret` 을 지우는 게 공식 권장입니다. 로컬 kind 라 그대로 뒀습니다.
- 캡처의 커밋 작성자 이메일은 가렸습니다. Argo CD UI 는 Git 작성자를 그대로 노출하니 공유 시 주의.

## 응용

- `deploy/values-dev.yaml` / `values-prod.yaml` 을 두고 Application 두 개로 환경 분리 — 같은 차트, 다른 값, 다른 네임스페이스
- ApplicationSet 으로 저장소의 `apps/*/` 폴더마다 Application 자동 생성
- PR 이 머지되면 배포되는 흐름: 브랜치 보호 + `main` 만 `targetRevision` 으로 → 코드 리뷰가 곧 배포 승인
- 롤백을 Git revert 로 통일 — `helm rollback` 대신 `git revert <sha> && git push`, Argo CD 가 나머지를 함
