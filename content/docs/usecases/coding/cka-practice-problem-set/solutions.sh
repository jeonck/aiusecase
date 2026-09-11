#!/usr/bin/env bash
# 모범 답안 — 시험처럼 kubectl 명령형 + 짧은 YAML 로. (각 문제는 독립적으로 실행 가능)
set -euo pipefail
export KIND_EXPERIMENTAL_PROVIDER=podman
k=kubectl

# 순서 팁: 트러블슈팅(노드 NotReady)을 먼저 푼다. 아니면 Q3·Q7 파드가 죽은 노드에 배정돼 Pending 이 된다 (실제로 겪음)
# Q11 (먼저) — 진단: describe node → kubelet stopped. 노드에 들어가 재시작
podman exec cka-worker2 systemctl start kubelet
until [ "$($k get node cka-worker2 -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = "True" ]; do sleep 3; done



# Q1
$k -n apps create deploy api --image=nginx:1.27-alpine --replicas=3
$k -n apps set resources deploy api --requests=cpu=100m,memory=64Mi
$k -n apps rollout status deploy/api --timeout=120s

# Q2
$k -n apps set image deploy/api nginx=nginx:1.28-alpine
$k -n apps rollout status deploy/api --timeout=120s
$k -n apps rollout undo deploy/api
$k -n apps rollout status deploy/api --timeout=120s

# Q3
$k -n apps run pinned --image=nginx:1.27-alpine --overrides='{"spec":{"nodeName":"cka-worker2"}}'

# Q4
$k taint node cka-worker dedicated=db:NoSchedule
cat <<'Y' | $k -n apps apply -f -
apiVersion: v1
kind: Pod
metadata: { name: db }
spec:
  nodeSelector: { kubernetes.io/hostname: cka-worker }
  tolerations: [{ key: dedicated, operator: Equal, value: db, effect: NoSchedule }]
  containers: [{ name: redis, image: redis:7-alpine }]
Y

# Q5
$k -n apps expose deploy api --name=api-svc --port=8080 --target-port=80

# Q6
cat <<'Y' | $k -n secure apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: web-allow-granted }
spec:
  podSelector: { matchLabels: { app: web } }
  policyTypes: [Ingress]
  ingress:
    - from: [{ podSelector: { matchLabels: { access: granted } } }]
      ports: [{ port: 80 }]
Y

# Q7
cat <<'Y' | $k apply -f -
apiVersion: v1
kind: PersistentVolume
metadata: { name: pv-data }
spec:
  capacity: { storage: 1Gi }
  accessModes: [ReadWriteOnce]
  storageClassName: manual
  hostPath: { path: /mnt/data }
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: pvc-data, namespace: storage }
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: manual
  resources: { requests: { storage: 1Gi } }
---
apiVersion: v1
kind: Pod
metadata: { name: data-pod, namespace: storage }
spec:
  containers:
    - name: bb
      image: busybox:1.36
      command: [sleep, "3600"]
      volumeMounts: [{ name: data, mountPath: /data }]
  volumes: [{ name: data, persistentVolumeClaim: { claimName: pvc-data } }]
Y
$k -n storage wait --for=condition=ready pod/data-pod --timeout=120s
$k -n storage exec data-pod -- sh -c 'echo -n cka > /data/hello.txt'

# Q8
$k -n apps create cm app-config --from-literal=MODE=prod
$k -n apps create secret generic db-secret --from-literal=password=s3cret
cat <<'Y' | $k -n apps apply -f -
apiVersion: v1
kind: Pod
metadata: { name: cfg-pod }
spec:
  containers:
    - name: bb
      image: busybox:1.36
      command: [sleep, "3600"]
      env:
        - { name: MODE, valueFrom: { configMapKeyRef: { name: app-config, key: MODE } } }
        - { name: DB_PASSWORD, valueFrom: { secretKeyRef: { name: db-secret, key: password } } }
Y

# Q9
$k -n apps create sa ci
$k -n apps create role deploy-ci --verb=create,list --resource=deployments
$k -n apps create rolebinding deploy-ci --role=deploy-ci --serviceaccount=apps:ci

# Q10 — 진단: describe 로 ErrImagePull(오타), svc selector 불일치
$k -n trouble set image deploy/broken nginx=nginx:1.27-alpine
$k -n trouble patch svc broken-svc -p '{"spec":{"selector":{"app":"broken"}}}'
$k -n trouble rollout status deploy/broken --timeout=120s

# Q12
$k -n kube-system exec etcd-cka-control-plane -- etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/lib/etcd/backup.db
