#!/usr/bin/env bash
#
# Task 4 — пункт 5: связывание пользователей (через группы) с ролями.
#
# Создаёт:
#   - 3 ClusterRoleBinding (cluster-wide роли -> группы platform / security / viewers);
#   - в каждом namespace 2 RoleBinding (ns-editor -> <ns>-dev, ns-viewer -> <ns>-watch).
#
# Субъекты привязок — kind: Group (группа задаётся через O= в сертификате пользователя),
# что соответствует рекомендации "использовать группы" из rbac_context.
# Идемпотентно: kubectl apply.

set -euo pipefail
command -v kubectl >/dev/null || { echo "ОШИБКА: kubectl не найден"; exit 1; }

GROUP_KIND="rbac.authorization.k8s.io"

NAMESPACES=(
  "sales-storefront" "sales-mart" "sales-estate" "sales-tour" "sales-crm" "sales-auth"
  "jku-tenant" "jku-crm" "jku-smarthome"
  "finance-accounting"
  "data-analytics"
  "platform-system"
)

# --- 1. ClusterRoleBinding (кластерные роли -> группы) ------------------------
echo ">>> Создание ClusterRoleBinding"

# platform -> cluster-privileged
kubectl apply -f - >/dev/null <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: platform-cluster-privileged
  labels: { app.kubernetes.io/part-of: propdevelopment-rbac }
subjects:
  - kind: Group
    name: platform
    apiGroup: ${GROUP_KIND}
roleRef:
  kind: ClusterRole
  name: cluster-privileged
  apiGroup: ${GROUP_KIND}
EOF
echo "    group:platform -> cluster-privileged"

# security -> cluster-security-auditor
kubectl apply -f - >/dev/null <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: security-cluster-auditor
  labels: { app.kubernetes.io/part-of: propdevelopment-rbac }
subjects:
  - kind: Group
    name: security
    apiGroup: ${GROUP_KIND}
roleRef:
  kind: ClusterRole
  name: cluster-security-auditor
  apiGroup: ${GROUP_KIND}
EOF
echo "    group:security -> cluster-security-auditor"

# viewers -> cluster-viewer
kubectl apply -f - >/dev/null <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewers-cluster-viewer
  labels: { app.kubernetes.io/part-of: propdevelopment-rbac }
subjects:
  - kind: Group
    name: viewers
    apiGroup: ${GROUP_KIND}
roleRef:
  kind: ClusterRole
  name: cluster-viewer
  apiGroup: ${GROUP_KIND}
EOF
echo "    group:viewers -> cluster-viewer"
echo

# --- 2. RoleBinding в каждом namespace ----------------------------------------
# Соглашение об именах групп: <namespace>-dev (editor), <namespace>-watch (viewer).
echo ">>> Создание RoleBinding по namespace"
for NS in "${NAMESPACES[@]}"; do

  # <ns>-dev -> ns-editor
  kubectl apply -f - >/dev/null <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${NS}-dev-editor
  namespace: ${NS}
  labels: { app.kubernetes.io/part-of: propdevelopment-rbac }
subjects:
  - kind: Group
    name: ${NS}-dev
    apiGroup: ${GROUP_KIND}
roleRef:
  kind: Role
  name: ns-editor
  apiGroup: ${GROUP_KIND}
EOF

  # <ns>-watch -> ns-viewer
  kubectl apply -f - >/dev/null <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${NS}-watch-viewer
  namespace: ${NS}
  labels: { app.kubernetes.io/part-of: propdevelopment-rbac }
subjects:
  - kind: Group
    name: ${NS}-watch
    apiGroup: ${GROUP_KIND}
roleRef:
  kind: Role
  name: ns-viewer
  apiGroup: ${GROUP_KIND}
EOF
  echo "    ${NS}: group:${NS}-dev -> ns-editor, group:${NS}-watch -> ns-viewer"
done
echo
echo ">>> Готово. Привязки ролей созданы."
echo "Аудит: kubectl get clusterrolebindings,rolebindings -A -l app.kubernetes.io/part-of=propdevelopment-rbac"
