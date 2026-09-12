# CKAD 연습 문제 세트 (kind-cka 클러스터)

시작: `./setup.sh` · 검증: `./check.sh` · 제한 시간 목표: 12문제 40분 · 기본 네임스페이스는 `ckad`

| # | 영역 | 문제 |
|---|---|---|
| 1 | Design & Build | 파드 `sidecar-pod`: 컨테이너 `web`(`nginx:1.27-alpine`)과 사이드카 `log-tailer`(`busybox:1.36`). 둘이 emptyDir 볼륨을 `/var/log/nginx` 에 공유하고, 사이드카는 `tail -f /var/log/nginx/access.log` 를 실행한다. 사이드카 로그에 `GET /` 요청 줄이 보여야 한다 (파드 안에서 `wget -qO- localhost` 로 한 번 요청). |
| 2 | Design & Build | Job `hasher`(`busybox:1.36`, `sha256sum /etc/hostname`): completions 3, parallelism 2, backoffLimit 2. 3개 모두 성공해야 한다. |
| 3 | Design & Build | CronJob `cleanup`(`busybox:1.36`, `echo cleanup`): 5분마다, concurrencyPolicy `Forbid`, successfulJobsHistoryLimit 2. |
| 4 | Deployment | Deployment `web`(`nginx:1.27-alpine`, 3 replicas). 롤링 업데이트 전략을 maxSurge 1, maxUnavailable 0 으로. |
| 5 | Deployment | Blue/Green: Deployment `app-blue`(라벨 `app=app,version=blue`)와 `app-green`(`version=green`), 각 1 replica, 이미지 `nginx:1.27-alpine`. Service `app`(port 80)이 **green 만** 가리키게 한다. |
| 6 | Deployment | 현재 폴더의 로컬 차트 `./mychart` 를 네임스페이스 `ckad-helm` 에 릴리스 이름 `demo` 로 설치하되, `replicaCount` 를 2 로 한다. |
| 7 | Observability | 파드 `probed`(`nginx:1.27-alpine`): readiness probe httpGet `/` port 80, liveness probe httpGet `/` port 80 initialDelaySeconds 5. |
| 8 | Observability | `ckad` 의 파드 `crasher` 가 CrashLoopBackOff 다. 로그로 원인을 확인하고, 같은 이름의 파드가 `sleep 3600` 을 실행해 Running 이 되게 고친다. |
| 9 | Env & Security | 파드 `secure-pod`(`busybox:1.36`, `sleep 3600`): 파드 레벨 `runAsUser 1000`, `runAsNonRoot true`; 컨테이너 레벨 `allowPrivilegeEscalation false`, capabilities `drop: [ALL]`. |
| 10 | Env & Security | 네임스페이스 `quota-ns` 에 ResourceQuota `app-quota`(pods 3, requests.cpu 1). 파드 `small`(`busybox:1.36`, `sleep 3600`)을 requests cpu `100m` 으로 만들어 Running 이 되게 한다. |
| 11 | Env & Security | ServiceAccount `app-sa`(automountServiceAccountToken false)를 만들고, 파드 `sa-pod`(`busybox:1.36`, `sleep 3600`)가 이 SA 를 쓰게 한다. 파드 안에 토큰이 마운트되지 않아야 한다. |
| 12 | Services & Networking | Deployment `web` 을 ClusterIP Service `web`(port 80)으로 노출하고, Ingress `web-ing`(ingressClassName `nginx`)이 host `web.local` 의 `/` 를 `web:80` 으로 보내게 한다. |
