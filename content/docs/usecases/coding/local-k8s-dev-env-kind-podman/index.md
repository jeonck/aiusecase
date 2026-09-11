---
title: "로컬 k8s 개발 환경 3분 — kind + Podman으로 클러스터·Ingress·로컬 이미지 배포까지"
description: "Docker Desktop 없이 Podman machine 위에 kind 클러스터(control-plane + worker)를 만들고, ingress-nginx로 localhost:8080에 앱을 붙이고, 로컬에서 빌드한 이미지를 레지스트리 없이 배포한다. 중간에 만난 404와 '응답 없음' 두 가지를 Claude가 진단해 고친 기록."
weight: 8
date: 2026-09-11
lastmod: 2026-09-11
icon: "hub"
usecase: true
categories: ["코딩·개발"]
tools: ["Claude Code", "kind", "Podman", "kubectl", "ingress-nginx"]
difficulty: "중급"
duration: "3분"
tags: ["Kubernetes", "kind", "Podman", "로컬개발", "Ingress", "인프라"]
---

## 어떤 문제를 해결하나

"로컬에 k8s 하나 띄워서 테스트하고 싶다" 는 늘 미뤄지는 일입니다. 도구는 많고(kind, minikube, k3d, Docker Desktop 내장), 문서 URL 은 죽어 있고, Ingress 가 localhost 로 안 붙어서 한두 시간 날리기 딱 좋습니다.

이 Mac 에는 Docker Desktop 이 없고 **Podman machine** 만 돕니다. Claude Code 에 "로컬 k8s 테스트 환경 만들어 줘" 라고 하면 설치된 도구를 확인하고(kind, kubectl, helm, podman 있음 / minikube, k3d, docker 데몬 없음) 그에 맞는 경로로 갑니다.
결과: **2분 43초** 만에 2노드 클러스터 + Ingress + 로컬 빌드 이미지 배포. 중간에 두 번 막혔고, 둘 다 Claude 가 원인을 찾아 고쳤습니다.

## 사전 준비

- `brew install kind kubectl` (있었음). `podman machine` 이 실행 중일 것 (`podman machine list`)
- Docker 데몬이 없으면 `KIND_EXPERIMENTAL_PROVIDER=podman`. 이 환경변수 없이 `kind` 를 부르면 `docker.sock` 을 찾다가 실패합니다
- 메모리: Podman machine 6GiB 로 control-plane + worker + ingress + 앱 3개가 넉넉히 돕니다

## 단계별 사용법

{{< step title="클러스터 정의를 파일로 쓰고 22초에 띄운다" image="01-create-cluster.png" caption="kind create cluster. Podman provider 경고 한 줄, 노드 2개 Ready. control-plane 컨테이너에 8080→80, 8443→443 포트 매핑." >}}
{{< prompt title="입력 프롬프트" >}}
개발을 위한 인프라 환경으로 로컬형 k8s테스트 환경 구축 유스케이스 작성 가능할까?
{{< /prompt >}}

Claude 가 쓴 [kind-dev.yaml](kind-dev.yaml):

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: dev
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"     # Ingress 컨트롤러를 이 노드에 붙이기 위한 라벨
    extraPortMappings:
      - { containerPort: 80,  hostPort: 8080, protocol: TCP }   # 호스트 80 은 권한 문제로 8080
      - { containerPort: 443, hostPort: 8443, protocol: TCP }
  - role: worker
```

```bash
export KIND_EXPERIMENTAL_PROVIDER=podman
kind create cluster --config kind-dev.yaml     # 22초 (노드 이미지 캐시 있을 때)
```

worker 를 하나 둔 이유: 파드가 control-plane 이 아닌 노드에 뜨는 걸 봐야 "스케줄링" 이 보입니다. 바로 다음 단계에서 그게 문제가 됩니다.
{{< /step >}}

{{< step title="Ingress를 붙이다 두 번 막히고, 두 번 고친다" image="02-ingress-fix.png" caption="404 → raw GitHub URL 로. '응답 없음' → 컨트롤러가 worker 에 뜬 걸 발견, control-plane 으로 고정." >}}
**첫 번째 벽 — 문서의 manifest URL 이 404.** kind 공식 문서가 가리키는 `kubernetes.github.io/ingress-nginx/…/kind/deploy.yaml` 이 죽어 있습니다. 같은 파일을 GitHub raw 로 받아 적용합니다.

```bash
curl -sSfL -o ingress-nginx-kind.yaml \
  https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
kubectl apply -f ingress-nginx-kind.yaml
```

**두 번째 벽 — 앱을 올렸는데 `localhost:8080` 이 응답 없음.** Claude 의 진단 순서:

1. `podman ps` — 포트 매핑은 `dev-control-plane` 에 있음 ✓
2. `kubectl -n ingress-nginx get pods -o wide` — 컨트롤러 파드가 **`dev-worker`** 에 떠 있음 ✗
3. 컨트롤러 Deployment 의 nodeSelector 확인 — `kubernetes.io/os: linux` 뿐. 최신 manifest 에서 `ingress-ready` 선택자가 빠져 있음

호스트 포트는 control-plane 컨테이너에만 뚫려 있는데 컨트롤러는 worker 에서 80 을 열고 있으니 연결될 리 없습니다. 컨트롤러를 control-plane 에 고정하고 taint 를 허용합니다.

```bash
kubectl -n ingress-nginx patch deploy ingress-nginx-controller --type=merge -p '{"spec":{"template":{"spec":{
  "nodeSelector":{"ingress-ready":"true","kubernetes.io/os":"linux"},
  "tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Equal","effect":"NoSchedule"}]}}}}'
```

재배포 뒤 `curl localhost:8080` 네 번 → 파드 두 개가 번갈아 응답합니다.
{{< /step >}}

{{< step title="샘플 앱으로 라운드로빈을 눈으로 본다" image="03-whoami.png" caption="브라우저에서 localhost:8080. whoami 가 자기 파드 이름·IP·요청 헤더를 돌려줍니다. 새로고침마다 Hostname 이 바뀝니다." >}}
[app.yaml](app.yaml) — `traefik/whoami` 2 replicas + Service + Ingress(`/`). 리소스 requests/limits 를 붙여 두면 나중에 HPA·리소스 쿼터 실험을 그대로 이어 갈 수 있습니다.

```bash
kubectl apply -f app.yaml
kubectl -n demo rollout status deploy/whoami
for i in 1 2 3 4; do curl -s http://localhost:8080/ | grep ^Hostname; done
```
{{< /step >}}

{{< step title="로컬에서 빌드한 이미지를 레지스트리 없이 배포한다" image="04-local-image.png" caption="podman build → podman save → kind load image-archive → imagePullPolicy: Never. 이 사이트의 정적 빌드가 클러스터에서 서빙됩니다." >}}
로컬 k8s 의 진짜 용도는 **내 코드를 이미지로 만들어 올려 보는 것**입니다. 레지스트리에 푸시하지 않고 노드에 직접 넣습니다.

```bash
hugo -b http://aiusecases.localtest.me:8080/ -d site         # 이 사이트를 빌드
podman build -q -t aiusecases:dev .                          # FROM nginx:1.27-alpine + COPY site/
podman save aiusecases:dev -o aiusecases-dev.tar
kind load image-archive aiusecases-dev.tar --name dev        # Docker 면 kind load docker-image
kubectl apply -f site.yaml
```

[site.yaml](site.yaml) 에서 빠뜨리면 안 되는 두 줄:

```yaml
image: localhost/aiusecases:dev     # podman 은 이미지 이름 앞에 localhost/ 를 붙인다
imagePullPolicy: Never              # 없으면 docker.io 에서 pull 하려다 ErrImagePull
```

Ingress 는 host 기반(`aiusecases.localtest.me`)으로 뒀습니다. `*.localtest.me` 는 공개 DNS 가 127.0.0.1 로 풀어 주는 도메인이라 `/etc/hosts` 를 안 건드립니다.
{{< /step >}}

{{< step title="브라우저로 확인한다" image="05-site-on-k8s.png" caption="aiusecases.localtest.me:8080 — 로컬 kind 클러스터 안의 nginx 파드가 서빙하는 이 사이트. 방금 넣은 필터 바까지 그대로." >}}
```bash
curl -s http://aiusecases.localtest.me:8080/docs/usecases/ | grep -o '<title>[^<]*</title>' | head -1
# <title>유스케이스 | AI Usecases</title>
```

여기서부터가 개발 루프입니다: 코드 수정 → `podman build` → `kind load` → `kubectl rollout restart deploy/aiusecases` → 새로고침. 레지스트리·CI 없이 10초 안에 돕니다.
{{< /step >}}

## 결과

| 단계 | 시각 | 누적 |
| --- | --- | --- |
| 도구 확인 + 클러스터 정의 + 생성 | 16:54:49 → 16:55:11 | 22초 |
| ingress-nginx (404 우회 포함) | → 16:56:02 | 1분 13초 |
| 앱 배포 + '응답 없음' 진단·수정 | → 16:57:01 | 2분 12초 |
| 로컬 이미지 빌드·적재·배포·확인 | → 16:57:32 | **2분 43초** |

사람이 문서 보며 하면 첫 벽(404)에서 검색 10분, 둘째 벽(포트 매핑 vs 스케줄링)에서 30분 — 이 두 벽이 이 작업의 전부입니다. Claude 가 빨랐던 건 명령을 빨리 쳐서가 아니라 **`podman ps` 와 `get pods -o wide` 를 나란히 놓고 노드 불일치를 본 것**입니다.

정리는 `kind delete cluster --name dev` 한 줄. 컨테이너 두 개가 사라지고 끝입니다.

## 주의사항

- **`KIND_EXPERIMENTAL_PROVIDER=podman` 을 셸 프로필에 넣으세요.** 빼먹으면 `kind get clusters` 조차 docker.sock 오류로 실패해 "클러스터가 사라졌나" 하고 당황합니다.
- **호스트 80 대신 8080.** macOS 에서 1024 이하 포트 매핑은 권한 문제가 생깁니다. `extraPortMappings` 의 `hostPort` 를 8080/8443 으로.
- **ingress-nginx 의 kind 전용 manifest 는 nodeSelector 가 바뀔 수 있습니다.** 적용 후 반드시 컨트롤러가 포트 매핑이 있는 노드(control-plane)에 떴는지 `get pods -o wide` 로 확인하세요. 단일 노드 클러스터면 이 문제가 안 보이지만, worker 를 두는 순간 나타납니다.
- **Podman 이미지는 `localhost/` 접두어.** `podman build -t foo:dev` 하면 실제 이름은 `localhost/foo:dev` 입니다. manifest 에 그대로 써야 `imagePullPolicy: Never` 가 찾습니다.
- **`kind load docker-image` 는 Docker 전용.** Podman 은 `podman save` → `kind load image-archive` 두 단계입니다.
- 이 환경은 **테스트용**입니다. 데이터는 노드 컨테이너 안에 있어 `kind delete` 하면 사라집니다. 영속 데이터 실험은 `extraMounts` 로 호스트 디렉터리를 붙이세요.

## 응용

- 같은 `kind-dev.yaml` 에 worker 를 하나 더 → 노드 장애(`podman stop dev-worker2`) 시 파드 재스케줄링 실험
- Helm 차트 개발: `helm install --dry-run` 이 아니라 실제 클러스터에 넣고 `kubectl get events -w` 로 보기
- CI 에서 같은 구성으로 e2e 테스트 (GitHub Actions 의 `helm/kind-action`)
- 이 사이트처럼 정적 사이트를 파드로 띄워 **Ingress 경로·헤더·리다이렉트 규칙**을 배포 전에 검증
