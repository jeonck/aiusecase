#!/usr/bin/env bash
# CKAD 모범 답안 — 명령형 우선, 필요한 곳만 짧은 YAML
set -euo pipefail
export KIND_EXPERIMENTAL_PROVIDER=podman
k=kubectl; n="-n ckad"

# Q8 (먼저) — 진단: kubectl logs crasher → "config file … not found". 같은 이름으로 다시 만든다
$k $n logs crasher || true
$k $n delete pod crasher --wait=true
$k $n run crasher --image=busybox:1.36 -- sleep 3600

# Q1 사이드카
cat <<'Y' | $k $n apply -f -
apiVersion: v1
kind: Pod
metadata: { name: sidecar-pod }
spec:
  volumes: [{ name: logs, emptyDir: {} }]
  containers:
    - name: web
      image: nginx:1.27-alpine
      volumeMounts: [{ name: logs, mountPath: /var/log/nginx }]
    - name: log-tailer
      image: busybox:1.36
      command: [sh, -c, "touch /var/log/nginx/access.log; tail -f /var/log/nginx/access.log"]
      volumeMounts: [{ name: logs, mountPath: /var/log/nginx }]
Y
$k $n wait --for=condition=ready pod/sidecar-pod --timeout=120s
$k $n exec sidecar-pod -c log-tailer -- wget -qO- localhost >/dev/null

# Q2 Job
cat <<'Y' | $k $n apply -f -
apiVersion: batch/v1
kind: Job
metadata: { name: hasher }
spec:
  completions: 3
  parallelism: 2
  backoffLimit: 2
  template:
    spec:
      restartPolicy: Never
      containers: [{ name: h, image: busybox:1.36, command: [sha256sum, /etc/hostname] }]
Y
$k $n wait --for=condition=complete job/hasher --timeout=120s

# Q3 CronJob
$k $n create cronjob cleanup --image=busybox:1.36 --schedule="*/5 * * * *" -- echo cleanup
$k $n patch cronjob cleanup -p '{"spec":{"concurrencyPolicy":"Forbid","successfulJobsHistoryLimit":2}}'

# Q4 Deployment + strategy
$k $n create deploy web --image=nginx:1.27-alpine --replicas=3
$k $n patch deploy web -p '{"spec":{"strategy":{"rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}}}'
$k $n rollout status deploy/web --timeout=120s

# Q5 Blue/Green — 라벨이 두 개(app, version)라 create deploy 로는 안 되고 YAML
for v in blue green; do cat <<Y | $k $n apply -f -
apiVersion: apps/v1
kind: Deployment
metadata: { name: app-$v }
spec:
  replicas: 1
  selector: { matchLabels: { app: app, version: $v } }
  template:
    metadata: { labels: { app: app, version: $v } }
    spec: { containers: [{ name: web, image: nginx:1.27-alpine }] }
Y
done
$k $n rollout status deploy/app-green --timeout=120s
cat <<'Y' | $k $n apply -f -
apiVersion: v1
kind: Service
metadata: { name: app }
spec:
  selector: { app: app, version: green }
  ports: [{ port: 80, targetPort: 80 }]
Y

# Q6 Helm
helm install demo ./mychart -n ckad-helm --set replicaCount=2 --wait --timeout 120s

# Q7 probes
cat <<'Y' | $k $n apply -f -
apiVersion: v1
kind: Pod
metadata: { name: probed }
spec:
  containers:
    - name: web
      image: nginx:1.27-alpine
      readinessProbe: { httpGet: { path: /, port: 80 } }
      livenessProbe:  { httpGet: { path: /, port: 80 }, initialDelaySeconds: 5 }
Y

# Q9 securityContext
cat <<'Y' | $k $n apply -f -
apiVersion: v1
kind: Pod
metadata: { name: secure-pod }
spec:
  securityContext: { runAsUser: 1000, runAsNonRoot: true }
  containers:
    - name: bb
      image: busybox:1.36
      command: [sleep, "3600"]
      securityContext: { allowPrivilegeEscalation: false, capabilities: { drop: [ALL] } }
Y

# Q10 quota
$k -n quota-ns create quota app-quota --hard=pods=3,requests.cpu=1
$k -n quota-ns run small --image=busybox:1.36 --overrides='{"spec":{"containers":[{"name":"small","image":"busybox:1.36","command":["sleep","3600"],"resources":{"requests":{"cpu":"100m"}}}]}}' -- sleep 3600

# Q11 SA automount false
$k $n create sa app-sa
$k $n patch sa app-sa -p '{"automountServiceAccountToken":false}'
$k $n run sa-pod --image=busybox:1.36 --overrides='{"spec":{"serviceAccountName":"app-sa"}}' -- sleep 3600

# Q12 Service + Ingress
$k $n expose deploy web --name=web --port=80
$k $n create ingress web-ing --class=nginx --rule="web.local/*=web:80"

$k $n wait --for=condition=ready pod/probed pod/secure-pod pod/sa-pod --timeout=120s
$k -n quota-ns wait --for=condition=ready pod/small --timeout=120s
