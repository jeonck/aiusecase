# 풀이 노트 — CKAD

| # | 핵심 명령 / 포인트 |
|---|---|
| 1 | 사이드카는 같은 파드의 두 번째 컨테이너 + `emptyDir` 공유. 사이드카가 `tail -f` 하기 전에 파일이 없으면 종료되므로 `touch` 먼저. 로그 확인은 `kubectl logs sidecar-pod -c log-tailer`. |
| 2 | Job 은 `create job` 으로 completions/parallelism 을 못 준다 → `--dry-run=client -o yaml` 로 뼈대 뽑아 세 줄 추가. `restartPolicy: Never` 필수. |
| 3 | `kubectl create cronjob cleanup --image=… --schedule="*/5 * * * *" -- echo cleanup` 후 `patch` 로 `concurrencyPolicy`, `successfulJobsHistoryLimit`. |
| 4 | `create deploy` 후 `patch deploy web -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}}}'`. `kubectl explain deploy.spec.strategy` 로 경로 확인. |
| 5 | 라벨이 두 개(app, version)라 `create deploy` 로는 안 된다 — YAML. Service selector 에 `version: green` 을 넣으면 blue 는 자동으로 빠진다. 전환은 selector 한 줄 `patch`. |
| 6 | `helm install demo ./mychart -n ckad-helm --set replicaCount=2 --wait`. 확인 `helm list -n ckad-helm`. |
| 7 | `readinessProbe.httpGet` / `livenessProbe.httpGet` + `initialDelaySeconds`. `kubectl explain pod.spec.containers.livenessProbe` 가 시험장 문서보다 빠르다. |
| 8 | `kubectl logs crasher` → 원인 메시지. 파드는 `command` 를 바꿀 수 없으니 **지우고 같은 이름으로 다시**. `kubectl get pod crasher -o yaml > p.yaml` 로 살려 고치는 것도 정답. |
| 9 | 파드 레벨 `securityContext: {runAsUser, runAsNonRoot}`, 컨테이너 레벨 `{allowPrivilegeEscalation, capabilities.drop}`. 둘의 위치가 다르다는 게 함정. |
| 10 | `kubectl create quota app-quota --hard=pods=3,requests.cpu=1 -n quota-ns`. 쿼터가 `requests.cpu` 를 걸면 **requests 없는 파드는 거부**된다 — 그래서 문제가 requests 를 요구. |
| 11 | `create sa` → `patch sa app-sa -p '{"automountServiceAccountToken":false}'`. 파드에 `serviceAccountName`. 확인 `exec sa-pod -- ls /var/run/secrets/kubernetes.io/serviceaccount` 가 비어야 함. |
| 12 | `expose deploy web --name=web --port=80` → `kubectl create ingress web-ing --class=nginx --rule="web.local/*=web:80"`. `*` 는 pathType Prefix. |

## 순서 전략
1. **CrashLoopBackOff 파드(Q8)를 먼저** 본다 — 로그 한 줄이면 끝나는데 뒤로 미루면 잊는다.
2. 명령형으로 끝나는 것(Q3, Q4, Q6, Q10, Q11, Q12) 처리.
3. YAML 이 필요한 것(Q1, Q2, Q5, Q7, Q9)은 `kubectl run/create … --dry-run=client -o yaml > f.yaml` 로 뼈대부터.
4. `kubectl explain <kind>.spec…` 를 문서 대신 쓰는 연습.
