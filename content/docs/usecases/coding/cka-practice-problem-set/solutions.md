# 풀이 노트 — 시험장에서 떠올릴 것만

| # | 핵심 명령 / 포인트 |
|---|---|
| 1 | `kubectl create deploy api --image=… --replicas=3` → `kubectl set resources deploy api --requests=cpu=100m,memory=64Mi`. YAML 안 써도 된다. |
| 2 | `kubectl set image deploy/api nginx=nginx:1.28-alpine` → `kubectl rollout undo deploy/api`. 컨테이너 이름은 `kubectl get deploy api -o jsonpath='{.spec.template.spec.containers[*].name}'`. |
| 3 | 가장 빠른 건 `--overrides='{"spec":{"nodeName":"cka-worker2"}}'`. nodeSelector `kubernetes.io/hostname` 도 정답. nodeName 은 스케줄러를 건너뛴다. |
| 4 | `kubectl taint node cka-worker dedicated=db:NoSchedule`. toleration 만으로는 "그 노드에서" 가 보장되지 않는다 — nodeSelector 를 같이. |
| 5 | `kubectl expose deploy api --name=api-svc --port=8080 --target-port=80`. 엔드포인트 확인은 `kubectl get endpointslices -l kubernetes.io/service-name=api-svc`. |
| 6 | `podSelector: {app: web}` + `policyTypes: [Ingress]` + `from.podSelector: {access: granted}`. `policyTypes` 를 빼면 ingress 규칙만으로도 동작하지만, 명시하는 습관. 검증은 라벨 있는/없는 busybox 로 wget. |
| 7 | PV 는 cluster-scoped(네임스페이스 없음), PVC 는 namespaced. `storageClassName: manual` 을 양쪽에 똑같이. hostPath 는 파드가 뜬 노드의 경로라는 점 기억. |
| 8 | `create cm --from-literal`, `create secret generic --from-literal`. env 는 `configMapKeyRef` / `secretKeyRef`. `envFrom` 은 키 이름을 바꿀 수 없으니 이 문제엔 안 맞다. |
| 9 | `create role --verb=create,list --resource=deployments` → `create rolebinding --role=… --serviceaccount=apps:ci`. 검증 `kubectl auth can-i … --as=system:serviceaccount:apps:ci`. |
| 10 | `kubectl -n trouble describe pod` → `ErrImagePull … nginx:1.27-alpne`(오타). `kubectl get endpointslices` 가 비어 있으면 selector 불일치 → `kubectl get svc -o yaml` 과 파드 라벨 비교. |
| 11 | `kubectl describe node` → `Kubelet stopped posting node status`. 노드 접속 후 `systemctl status kubelet` → `systemctl start kubelet`. 시험은 `ssh node`, kind 는 `podman exec -it node bash`. **이 문제를 먼저 풀 것.** |
| 12 | `etcdctl --endpoints=https://127.0.0.1:2379 --cacert … --cert … --key … snapshot save`. 인증서 경로는 `/etc/kubernetes/manifests/etcd.yaml` 에서 확인. kind 의 etcd 파드는 `sh` 가 없어 `exec -- etcdctl` 로 바로. |

## 순서 전략
1. 전체를 1분 훑고 **클러스터 상태 문제(NotReady 노드)** 부터 — 방치하면 다른 문제의 파드가 그 노드에 배정돼 Pending 이 되는 걸 이 세트에서 실제로 겪는다.
2. 명령형(`create`, `set`, `expose`, `taint`)으로 끝나는 문제를 먼저 처리.
3. YAML 이 필요한 것(NetworkPolicy, PV/PVC, env)은 `--dry-run=client -o yaml` 로 뼈대를 뽑아 고친다.
4. 각 문제 끝에 `./check.sh` 대신 **문제가 요구한 상태를 kubectl 로 직접 확인** — 시험엔 체커가 없다.
