#!/usr/bin/env bash
#
# Task 4 — пункт 4: создание namespace и ролей RBAC.
#
# Создаёт:
#   - 12 namespace по продуктовым командам (метка domain=<домен>);
#   - 3 ClusterRole (cluster-privileged, cluster-security-auditor, cluster-viewer);
#   - в каждом namespace по 2 Role (ns-editor, ns-viewer).
#
# Принцип минимальных привилегий: verbs/resources перечислены явно, без "*".
# Идемпотентно: используется kubectl apply.

set -euo pipefail
command -v kubectl >/dev/null || { echo "ОШИБКА: kubectl не найден"; exit 1; }

# namespace в формате "имя:домен"
NAMESPACES=(
  "sales-storefront:sales"
  "sales-mart:sales"
  "sales-estate:sales"
  "sales-tour:sales"
  "sales-crm:sales"
  "sales-auth:sales"
  "jku-tenant:jku"
  "jku-crm:jku"
  "jku-smarthome:jku"
  "finance-accounting:finance"
  "data-analytics:data"
  "platform-system:platform"
)

# --- 1. Namespaces ------------------------------------------------------------
echo ">>> Создание namespace (метка domain=<домен>)"
for entry in "${NAMESPACES[@]}"; do
  NS="${entry%%:*}"
  DOMAIN="${entry##*:}"
  kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl label namespace "${NS}" "domain=${DOMAIN}" --overwrite >/dev/null
  echo "    ${NS} (domain=${DOMAIN})"
done
echo

# --- 2. Кластерные роли -------------------------------------------------------
echo ">>> Создание ClusterRole"

# 2.1 cluster-privileged — полное управление + secrets (привилегированная роль)
kubectl apply -f - >/dev/null <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-privileged
  labels: { app.kubernetes.io/part-of: propdevelopment-rbac }
rules:
  - apiGroups: [""]
    resources: [pods, pods/log, services, configmaps, secrets, persistentvolumeclaims, serviceaccounts]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: ["apps"]
    resources: [deployments, statefulsets, daemonsets, replicasets]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: ["batch"]
    resources: [jobs, cronjobs]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: ["networking.k8s.io"]
    resources: [ingresses, networkpolicies]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [""]
    resources: [nodes, namespaces, persistentvolumes]
    verbs: [get, list, watch]
EOF
echo "    cluster-privileged (управление всем + secrets)"

# 2.2 cluster-security-auditor — read-only incl. secrets + объекты RBAC (ИБ-аудит)
kubectl apply -f - >/dev/null <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-security-auditor
  labels: { app.kubernetes.io/part-of: propdevelopment-rbac }
rules:
  - apiGroups: [""]
    resources: [pods, services, configmaps, secrets, persistentvolumeclaims, serviceaccounts, nodes, namespaces, events]
    verbs: [get, list, watch]
  - apiGroups: ["apps"]
    resources: [deployments, statefulsets, daemonsets, replicasets]
    verbs: [get, list, watch]
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: [roles, rolebindings, clusterroles, clusterrolebindings]
    verbs: [get, list, watch]
EOF
echo "    cluster-security-auditor (чтение всего incl. secrets + RBAC)"

# 2.3 cluster-viewer — read-only БЕЗ secrets (только просмотр кластера)
kubectl apply -f - >/dev/null <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-viewer
  labels: { app.kubernetes.io/part-of: propdevelopment-rbac }
rules:
  - apiGroups: [""]
    resources: [pods, pods/log, services, configmaps, persistentvolumeclaims, namespaces, events]
    verbs: [get, list, watch]
  - apiGroups: ["apps"]
    resources: [deployments, statefulsets, daemonsets, replicasets]
    verbs: [get, list, watch]
  - apiGroups: ["networking.k8s.io"]
    resources: [ingresses]
    verbs: [get, list, watch]
EOF
echo "    cluster-viewer (просмотр кластера, БЕЗ secrets)"
echo

# --- 3. Namespace-роли (Role в каждом namespace) ------------------------------
echo ">>> Создание Role ns-editor / ns-viewer в каждом namespace"
for entry in "${NAMESPACES[@]}"; do
  NS="${entry%%:*}"

  # ns-editor — настройка ресурсов в своём namespace, без secrets
  kubectl apply -f - >/dev/null <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ns-editor
  namespace: ${NS}
  labels: { app.kubernetes.io/part-of: propdevelopment-rbac }
rules:
  - apiGroups: [""]
    resources: [pods, pods/log, services, configmaps, persistentvolumeclaims]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: ["apps"]
    resources: [deployments, statefulsets, daemonsets, replicasets]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: ["networking.k8s.io"]
    resources: [ingresses]
    verbs: [get, list, watch, create, update, patch, delete]
EOF

  # ns-viewer — только просмотр своего namespace, без secrets
  kubectl apply -f - >/dev/null <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ns-viewer
  namespace: ${NS}
  labels: { app.kubernetes.io/part-of: propdevelopment-rbac }
rules:
  - apiGroups: [""]
    resources: [pods, pods/log, services, configmaps, persistentvolumeclaims, events]
    verbs: [get, list, watch]
  - apiGroups: ["apps"]
    resources: [deployments, statefulsets, daemonsets, replicasets]
    verbs: [get, list, watch]
  - apiGroups: ["networking.k8s.io"]
    resources: [ingresses]
    verbs: [get, list, watch]
EOF
  echo "    ${NS}: ns-editor, ns-viewer"
done
echo
echo ">>> Готово. Созданы namespace и роли."
