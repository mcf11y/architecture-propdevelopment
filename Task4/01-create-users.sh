#!/usr/bin/env bash
#
# Task 4 — пункт 3: создание пользователей кластера Kubernetes.
#
# Пользователи аутентифицируются по x509 client-сертификатам:
#   CN = имя пользователя, O = группа (используется в RBAC как kind: Group).
# Сертификаты подписываются центром сертификации (CA) Minikube.
# Для каждого пользователя создаётся запись в kubeconfig (credentials + context).
#
# Идемпотентно: повторный запуск пересоздаёт сертификаты и записи kubeconfig.

set -euo pipefail

# --- Параметры ----------------------------------------------------------------
CLUSTER_NAME="minikube"
CA_DIR="${HOME}/.minikube"
CA_CRT="${CA_DIR}/ca.crt"
CA_KEY="${CA_DIR}/ca.key"
CERTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/users-certs"
CERT_DAYS=365

# Пользователи в формате "CN:O" (имя:группа).
USERS=(
  "alice-devops:platform"
  "ivan-security:security"
  "bob-manager:viewers"
  "carol-dev:jku-smarthome-dev"
  "dana-analyst:data-analytics-watch"
)

# --- Проверки -----------------------------------------------------------------
command -v kubectl >/dev/null || { echo "ОШИБКА: kubectl не найден"; exit 1; }
command -v openssl >/dev/null || { echo "ОШИБКА: openssl не найден"; exit 1; }
[[ -f "${CA_CRT}" && -f "${CA_KEY}" ]] || {
  echo "ОШИБКА: не найден CA Minikube (${CA_CRT} / ${CA_KEY})."
  echo "Сначала выполните: colima start && minikube start"
  exit 1
}

mkdir -p "${CERTS_DIR}"
echo ">>> CA: ${CA_CRT}"
echo ">>> Сертификаты пользователей: ${CERTS_DIR}"
echo

# --- Создание пользователей ---------------------------------------------------
for entry in "${USERS[@]}"; do
  CN="${entry%%:*}"   # имя пользователя
  GROUP="${entry##*:}" # группа

  echo "=== Пользователь: ${CN} (группа O=${GROUP}) ==="

  KEY="${CERTS_DIR}/${CN}.key"
  CSR="${CERTS_DIR}/${CN}.csr"
  CRT="${CERTS_DIR}/${CN}.crt"

  # 1. Приватный ключ
  openssl genrsa -out "${KEY}" 2048 2>/dev/null

  # 2. CSR с CN=имя, O=группа
  openssl req -new -key "${KEY}" -out "${CSR}" -subj "/CN=${CN}/O=${GROUP}"

  # 3. Подпись сертификата центром сертификации Minikube
  openssl x509 -req -in "${CSR}" \
    -CA "${CA_CRT}" -CAkey "${CA_KEY}" -CAcreateserial \
    -out "${CRT}" -days "${CERT_DAYS}" -sha256 2>/dev/null

  # 4. Запись пользователя и контекста в kubeconfig
  kubectl config set-credentials "${CN}" \
    --client-certificate="${CRT}" \
    --client-key="${KEY}" \
    --embed-certs=true >/dev/null

  kubectl config set-context "${CN}" \
    --cluster="${CLUSTER_NAME}" \
    --user="${CN}" >/dev/null

  echo "    сертификат подписан, контекст '${CN}' добавлен в kubeconfig"
  echo
done

echo ">>> Готово. Созданы пользователи:"
for entry in "${USERS[@]}"; do
  echo "    - ${entry%%:*}  (группа: ${entry##*:})"
done
echo
echo "Переключение на пользователя:   kubectl config use-context <имя>"
echo "Возврат к админу кластера:       kubectl config use-context ${CLUSTER_NAME}"
