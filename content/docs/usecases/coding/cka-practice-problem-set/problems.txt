# CKA 연습 문제 세트 (kind-cka 클러스터)

시작: `./setup.sh` · 검증: `./check.sh` · 제한 시간 목표: 12문제 40분

| # | 영역 | 문제 |
|---|---|---|
| 1 | Workloads | 네임스페이스 `apps` 에 Deployment `api` 를 만든다. 이미지 `nginx:1.27-alpine`, replicas 3, 컨테이너 requests cpu `100m` / memory `64Mi`. |
| 2 | Workloads | `api` 의 이미지를 `nginx:1.28-alpine` 으로 롤링 업데이트한 뒤, 직전 리비전으로 롤백한다. |
| 3 | Scheduling | `apps` 에 파드 `pinned`(이미지 `nginx:1.27-alpine`)를 만들되 반드시 `cka-worker2` 노드에서 실행되게 한다. |
| 4 | Scheduling | 노드 `cka-worker` 에 taint `dedicated=db:NoSchedule` 을 건다. `apps` 에 파드 `db`(이미지 `redis:7-alpine`)를 만들어 그 taint 를 허용하고 **`cka-worker` 에서** 실행되게 한다. |
| 5 | Services | Deployment `api` 를 ClusterIP Service `api-svc` 로 노출한다. 서비스 포트 8080 → 컨테이너 80. |
| 6 | Networking | `secure` 네임스페이스에 `web` 파드(`app=web`)와 서비스가 있다. NetworkPolicy 를 만들어 라벨 `access=granted` 가 있는 파드만 `web` 의 80 포트에 접근할 수 있게 한다. 그 외는 모두 차단. |
| 7 | Storage | hostPath(`/mnt/data`) 1Gi PV `pv-data`(accessMode RWO, storageClassName `manual`)와 이를 바인딩하는 PVC `pvc-data`(ns `storage`)를 만든다. 파드 `data-pod`(`busybox:1.36`, `sleep 3600`)가 PVC 를 `/data` 에 마운트하고, `/data/hello.txt` 에 `cka` 라는 내용이 있어야 한다. |
| 8 | Config | `apps` 에 ConfigMap `app-config`(`MODE=prod`)와 Secret `db-secret`(`password=s3cret`)을 만든다. 파드 `cfg-pod`(`busybox:1.36`, `sleep 3600`)에 환경변수 `MODE`(ConfigMap)와 `DB_PASSWORD`(Secret 의 password)를 주입한다. |
| 9 | RBAC | `apps` 에 ServiceAccount `ci` 를 만들고, **deployments 에 대해 create·list 만** 할 수 있는 Role/RoleBinding 을 준다. pods 삭제, secrets 조회는 안 돼야 한다. |
| 10 | Troubleshooting | `trouble` 네임스페이스의 Deployment `broken` 이 뜨지 않고, Service `broken-svc` 로 트래픽이 가지 않는다. 둘 다 고쳐 파드 2개 Ready, 엔드포인트 2개가 되게 한다. |
| 11 | Troubleshooting | 노드 `cka-worker2` 가 NotReady 다. 원인을 찾아 Ready 로 되돌린다. (노드 접속: `podman exec -it cka-worker2 bash`) |
| 12 | Cluster | etcd 스냅샷을 `/var/lib/etcd/backup.db` 에 저장한다. (etcd 인증서: `/etc/kubernetes/pki/etcd/`) |
