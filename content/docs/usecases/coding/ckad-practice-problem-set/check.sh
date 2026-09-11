#!/usr/bin/env bash
export KIND_EXPERIMENTAL_PROVIDER=podman
pass=0; fail=0; k=kubectl
ok(){ printf "PASS  Q%-2s %s\n" "$1" "$2"; pass=$((pass+1)); }
ng(){ printf "FAIL  Q%-2s %s\n" "$1" "$2"; fail=$((fail+1)); }

# Q1 sidecar-pod: 2 containers ready, shared emptyDir at /var/log/nginx, sidecar tails access.log
r=$($k -n ckad get pod sidecar-pod -o jsonpath='{.status.containerStatuses[*].ready}|{.spec.volumes[?(@.emptyDir)].name}' 2>/dev/null)
lg=$($k -n ckad logs sidecar-pod -c log-tailer --tail=3 2>/dev/null | grep -c "GET /")
[ "${r%%|*}" = "true true" ] && [ -n "${r##*|}" ] && [ "$lg" -ge 1 ] && ok 1 "ckad/sidecar-pod 2/2, emptyDir 공유, 사이드카가 access.log 출력" || ng 1 "sidecar-pod ready=$r taillines=$lg"

# Q2 Job hasher: completions 3 parallelism 2 backoffLimit 2, succeeded 3
j=$($k -n ckad get job hasher -o jsonpath='{.spec.completions}|{.spec.parallelism}|{.spec.backoffLimit}|{.status.succeeded}' 2>/dev/null)
[ "$j" = "3|2|2|3" ] && ok 2 "ckad/hasher completions 3 / parallelism 2 / backoffLimit 2, succeeded 3" || ng 2 "job=$j"

# Q3 CronJob cleanup: */5, Forbid, successfulJobsHistoryLimit 2
c=$($k -n ckad get cronjob cleanup -o jsonpath='{.spec.schedule}|{.spec.concurrencyPolicy}|{.spec.successfulJobsHistoryLimit}' 2>/dev/null)
[ "$c" = "*/5 * * * *|Forbid|2" ] && ok 3 "ckad/cleanup */5, Forbid, history 2" || ng 3 "cronjob=$c"

# Q4 Deployment web: 3 ready, maxSurge 1, maxUnavailable 0, image nginx:1.27-alpine
w=$($k -n ckad get deploy web -o jsonpath='{.status.readyReplicas}|{.spec.strategy.rollingUpdate.maxSurge}|{.spec.strategy.rollingUpdate.maxUnavailable}|{.spec.template.spec.containers[0].image}' 2>/dev/null)
[ "$w" = "3|1|0|nginx:1.27-alpine" ] && ok 4 "ckad/web 3 ready, maxSurge 1 / maxUnavailable 0" || ng 4 "web=$w"

# Q5 blue/green: svc app selects version=green, endpoints == green pod IPs only
sel=$($k -n ckad get svc app -o jsonpath='{.spec.selector.version}' 2>/dev/null)
g=$($k -n ckad get pods -l version=green -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' 2>/dev/null | sort)
e=$($k -n ckad get endpointslices -l kubernetes.io/service-name=app -o jsonpath='{range .items[*]}{range .endpoints[*]}{.addresses[0]}{"\n"}{end}{end}' 2>/dev/null | sort)
[ "$sel" = "green" ] && [ -n "$g" ] && [ "$g" = "$e" ] && ok 5 "ckad/app → green 파드만 엔드포인트" || ng 5 "selector=$sel green=$(echo $g) ep=$(echo $e)"

# Q6 helm release demo in ckad-helm, deployed, replicaCount 2
h=$(helm -n ckad-helm list -o json 2>/dev/null | grep -o '"status":"deployed"' | wc -l | tr -d ' ')
hr=$($k -n ckad-helm get deploy -l app.kubernetes.io/instance=demo -o jsonpath='{.items[0].status.readyReplicas}' 2>/dev/null)
[ "$h" = "1" ] && [ "$hr" = "2" ] && ok 6 "ckad-helm/demo deployed, 2 replicas ready" || ng 6 "helm deployed=$h ready=$hr"

# Q7 probed: readiness httpGet / :80, liveness httpGet /healthz? -> spec: liveness httpGet path / port 80 initialDelay 5, readiness httpGet / port 80; ready
p=$($k -n ckad get pod probed -o jsonpath='{.spec.containers[0].readinessProbe.httpGet.path}|{.spec.containers[0].livenessProbe.httpGet.path}|{.spec.containers[0].livenessProbe.initialDelaySeconds}|{.status.containerStatuses[0].ready}' 2>/dev/null)
[ "$p" = "/|/|5|true" ] && ok 7 "ckad/probed readiness+liveness httpGet /, initialDelay 5, ready" || ng 7 "probes=$p"

# Q8 crasher fixed: Running, restarts stable
cr=$($k -n ckad get pod crasher -o jsonpath='{.status.phase}|{.status.containerStatuses[0].ready}' 2>/dev/null)
[ "$cr" = "Running|true" ] && ok 8 "ckad/crasher Running" || ng 8 "crasher=$cr"

# Q9 secure-pod securityContext
sc=$($k -n ckad get pod secure-pod -o jsonpath='{.spec.securityContext.runAsUser}|{.spec.securityContext.runAsNonRoot}|{.spec.containers[0].securityContext.allowPrivilegeEscalation}|{.spec.containers[0].securityContext.capabilities.drop[0]}|{.status.phase}' 2>/dev/null)
[ "$sc" = "1000|true|false|ALL|Running" ] && ok 9 "ckad/secure-pod runAsUser 1000, nonRoot, no privesc, drop ALL" || ng 9 "sc=$sc"

# Q10 quota: pods 3, requests.cpu 1; pod small running with requests
q=$($k -n quota-ns get resourcequota app-quota -o jsonpath='{.spec.hard.pods}|{.spec.hard.requests\.cpu}' 2>/dev/null)
qp=$($k -n quota-ns get pod small -o jsonpath='{.spec.containers[0].resources.requests.cpu}|{.status.phase}' 2>/dev/null)
[ "$q" = "3|1" ] && [ "${qp##*|}" = "Running" ] && [ -n "${qp%%|*}" ] && ok 10 "quota-ns/app-quota pods 3, cpu 1; small 파드 requests 있음" || ng 10 "quota=$q pod=$qp"

# Q11 app-sa automount false, pod uses it
sa=$($k -n ckad get sa app-sa -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null)
sp=$($k -n ckad get pod sa-pod -o jsonpath='{.spec.serviceAccountName}|{.status.phase}' 2>/dev/null)
mt=$($k -n ckad exec sa-pod -- sh -c 'ls /var/run/secrets/kubernetes.io/serviceaccount 2>/dev/null | wc -l' 2>/dev/null | tr -d ' ')
[ "$sa" = "false" ] && [ "$sp" = "app-sa|Running" ] && [ "${mt:-0}" = "0" ] && ok 11 "ckad/app-sa automount false, sa-pod 에 토큰 미마운트" || ng 11 "sa=$sa pod=$sp mounted=$mt"

# Q12 svc web 80 + ingress web-ing host web.local / -> web:80 class nginx
sv=$($k -n ckad get svc web -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
ig=$($k -n ckad get ingress web-ing -o jsonpath='{.spec.ingressClassName}|{.spec.rules[0].host}|{.spec.rules[0].http.paths[0].path}|{.spec.rules[0].http.paths[0].backend.service.name}|{.spec.rules[0].http.paths[0].backend.service.port.number}' 2>/dev/null)
[ "$sv" = "80" ] && [ "$ig" = "nginx|web.local|/|web|80" ] && ok 12 "ckad/web-ing web.local / → web:80 (class nginx)" || ng 12 "svc=$sv ingress=$ig"

echo "----- $pass PASS / $fail FAIL"
