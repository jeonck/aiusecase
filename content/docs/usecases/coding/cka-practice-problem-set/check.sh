#!/usr/bin/env bash
# 문제별 PASS/FAIL. 정답의 '형태'가 아니라 '결과'를 본다.
export KIND_EXPERIMENTAL_PROVIDER=podman
pass=0; fail=0
ok(){ printf "PASS  Q%-2s %s\n" "$1" "$2"; pass=$((pass+1)); }
ng(){ printf "FAIL  Q%-2s %s\n" "$1" "$2"; fail=$((fail+1)); }
k=kubectl

# Q1 Deployment api: 3 replicas ready, image nginx:1.27-alpine, requests cpu 100m / mem 64Mi
r=$($k -n apps get deploy api -o jsonpath='{.status.readyReplicas}|{.spec.template.spec.containers[0].image}|{.spec.template.spec.containers[0].resources.requests.cpu}|{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
[ "$r" = "3|nginx:1.27-alpine|100m|64Mi" ] && ok 1 "apps/api 3 replicas, 1.27-alpine, requests 100m/64Mi" || ng 1 "apps/api ($r)"

# Q2 rollout: 히스토리에 1.28 이 있고 현재는 1.27 (롤백됨)
h=$($k -n apps rollout history deploy/api 2>/dev/null | grep -c "^[0-9]")
cur=$($k -n apps get deploy api -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
had=$($k -n apps get rs -l app=api -o jsonpath='{range .items[*]}{.spec.template.spec.containers[0].image}{"\n"}{end}' 2>/dev/null | grep -c "1.28")
[ "$h" -ge 2 ] && [ "$cur" = "nginx:1.27-alpine" ] && [ "$had" -ge 1 ] && ok 2 "1.28 로 올렸다가 1.27 로 롤백" || ng 2 "rollout (revisions=$h cur=$cur had128=$had)"

# Q3 pod pinned on cka-worker2
n=$($k -n apps get pod pinned -o jsonpath='{.spec.nodeName}|{.status.phase}' 2>/dev/null)
[ "$n" = "cka-worker2|Running" ] && ok 3 "apps/pinned on cka-worker2" || ng 3 "pinned ($n)"

# Q4 taint + toleration
t=$($k get node cka-worker -o jsonpath='{.spec.taints[?(@.key=="dedicated")].effect}' 2>/dev/null)
d=$($k -n apps get pod db -o jsonpath='{.spec.nodeName}|{.status.phase}' 2>/dev/null)
[ "$t" = "NoSchedule" ] && [ "$d" = "cka-worker|Running" ] && ok 4 "cka-worker tainted, apps/db tolerates and runs there" || ng 4 "taint=$t db=$d"

# Q5 service api-svc 8080->80 with 3 endpoints
s=$($k -n apps get svc api-svc -o jsonpath='{.spec.type}|{.spec.ports[0].port}|{.spec.ports[0].targetPort}' 2>/dev/null)
e=$($k -n apps get endpointslices -l kubernetes.io/service-name=api-svc -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}' 2>/dev/null | grep -c .)
[ "$s" = "ClusterIP|8080|80" ] && [ "$e" = "3" ] && ok 5 "apps/api-svc ClusterIP 8080->80, 3 endpoints" || ng 5 "svc=$s endpoints=$e"

# Q6 NetworkPolicy: granted 만 통과
g=$($k -n secure run chk-g --rm -i --restart=Never --labels=access=granted --image=busybox:1.36 -- wget -qO- -T 3 http://web 2>/dev/null | grep -c "nginx")
b=$($k -n secure run chk-b --rm -i --restart=Never --image=busybox:1.36 -- wget -qO- -T 3 http://web 2>&1 | grep -c "timed out")
[ "$g" -ge 1 ] && [ "$b" -ge 1 ] && ok 6 "secure/web: access=granted 만 접근" || ng 6 "granted=$g blocked=$b"

# Q7 PV/PVC bound + file
p=$($k -n storage get pvc pvc-data -o jsonpath='{.status.phase}|{.spec.volumeName}' 2>/dev/null)
f=$($k -n storage exec data-pod -- cat /data/hello.txt 2>/dev/null)
[ "${p%%|*}" = "Bound" ] && [ "${p##*|}" = "pv-data" ] && [ "$f" = "cka" ] && ok 7 "storage/pvc-data Bound to pv-data, /data/hello.txt=cka" || ng 7 "pvc=$p file=$f"

# Q8 ConfigMap/Secret as env
m=$($k -n apps exec cfg-pod -- sh -c 'echo $MODE:$DB_PASSWORD' 2>/dev/null)
[ "$m" = "prod:s3cret" ] && ok 8 "apps/cfg-pod MODE=prod, DB_PASSWORD from secret" || ng 8 "env=$m"

# Q9 RBAC ci: deployments create/list yes, pods delete no, secrets no
a=$($k auth can-i create deployments --as=system:serviceaccount:apps:ci -n apps 2>/dev/null)
b2=$($k auth can-i list deployments --as=system:serviceaccount:apps:ci -n apps 2>/dev/null)
c=$($k auth can-i delete pods --as=system:serviceaccount:apps:ci -n apps 2>/dev/null)
d2=$($k auth can-i get secrets --as=system:serviceaccount:apps:ci -n apps 2>/dev/null)
[ "$a$b2$c$d2" = "yesyesnono" ] && ok 9 "apps/ci: deployments create/list only" || ng 9 "can-i=$a/$b2/$c/$d2"

# Q10 broken fixed: 2 ready + endpoints 2
r10=$($k -n trouble get deploy broken -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
e10=$($k -n trouble get endpointslices -l kubernetes.io/service-name=broken-svc -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}' 2>/dev/null | grep -c .)
[ "$r10" = "2" ] && [ "$e10" = "2" ] && ok 10 "trouble/broken 2 ready, broken-svc 2 endpoints" || ng 10 "ready=$r10 endpoints=$e10"

# Q11 node Ready
nr=$($k get node cka-worker2 -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
[ "$nr" = "True" ] && ok 11 "cka-worker2 Ready" || ng 11 "cka-worker2 Ready=$nr"

# Q12 etcd backup exists
[ "$(podman exec cka-control-plane sh -c 'test -s /var/lib/etcd/backup.db && echo yes')" = "yes" ] && ok 12 "etcd snapshot /var/lib/etcd/backup.db" || ng 12 "backup.db 없음"

echo "----- $pass PASS / $fail FAIL"
