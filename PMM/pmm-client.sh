#!/usr/bin/env bash
set -euo pipefail

# =========================
# 基本設定
# =========================
PMM_CLIENT_DATA_DIR="${PMM_CLIENT_DATA_DIR:-/data/pmm-client/data}"
PMM_CLIENT_CONFIG_DIR="${PMM_CLIENT_CONFIG_DIR:-/data/pmm-client/config}"
CONTAINER_NAME="${CONTAINER_NAME:-pmm-client}"
IMAGE="${IMAGE:-percona/pmm-client:3}"

# 遠端 PMM Server
PMM_SERVER_ADDR="${PMM_SERVER_ADDR:-192.168.199.234:18443}"
PMM_USER="${PMM_USER:-admin}"
PMM_PASS="${PMM_PASS:-Aa123456}"
PMM_INSECURE_TLS="${PMM_INSECURE_TLS:-1}"

NODE_NAME="${NODE_NAME:-$(hostname -s)}"

echo "==> PMM Client bootstrap (container-only, host network)"
echo "==> Node name  : ${NODE_NAME}"
echo "==> PMM Server: ${PMM_SERVER_ADDR}"
echo "==> Data dir  : ${PMM_CLIENT_DATA_DIR}"
echo "==> Config dir: ${PMM_CLIENT_CONFIG_DIR}"
echo

# =========================
# SELinux（如有）: volume 加 :Z
# =========================
VOLUME_OPT=""
if command -v getenforce >/dev/null 2>&1; then
  if [[ "$(getenforce)" == "Enforcing" ]]; then
    VOLUME_OPT=":Z"
    echo "==> SELinux Enforcing detected, using :Z"
  fi
fi
echo

# =========================
# Pull image
# =========================
echo "==> Pull image: ${IMAGE}"
sudo docker pull "${IMAGE}"
echo

# =========================
# Remove old containers
# =========================
sudo docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
sudo docker rm -f "${CONTAINER_NAME}-setup" 2>/dev/null || true

# =========================
# Prepare host dirs
# =========================
sudo mkdir -p "${PMM_CLIENT_DATA_DIR}"
sudo mkdir -p "${PMM_CLIENT_CONFIG_DIR}"

# =========================
# Detect PMM runtime UID/GID
# =========================
read -r PMM_UID PMM_GID < <(
  sudo docker run --rm --entrypoint /bin/sh "${IMAGE}" \
  -c 'printf "%s %s\n" "$(id -u)" "$(id -g)"'
)
echo "==> PMM container user: ${PMM_UID}:${PMM_GID}"
echo

# =========================
# Init tmp + config dir perms
# =========================
echo "==> Init tmp & config dir perms ..."
sudo docker run --rm \
  --user 0:0 \
  --entrypoint /bin/sh \
  -v "${PMM_CLIENT_DATA_DIR}:/usr/local/percona/pmm/tmp${VOLUME_OPT}" \
  -v "${PMM_CLIENT_CONFIG_DIR}:/usr/local/percona/pmm/config${VOLUME_OPT}" \
  "${IMAGE}" \
  -c "
    mkdir -p /usr/local/percona/pmm/tmp /usr/local/percona/pmm/config &&
    chown -R ${PMM_UID}:${PMM_GID} /usr/local/percona/pmm/tmp /usr/local/percona/pmm/config &&
    chmod -R u+rwX /usr/local/percona/pmm/tmp /usr/local/percona/pmm/config
  "
echo

# =========================
# 1) Setup（一次性，寫出 pmm-agent.yaml）
# =========================
echo "==> [1/2] Setup via pmm-agent setup ..."
sudo docker run --rm \
  --name "${CONTAINER_NAME}-setup" \
  --network host \
  --entrypoint /bin/sh \
  -v "${PMM_CLIENT_CONFIG_DIR}:/usr/local/percona/pmm/config${VOLUME_OPT}" \
  -v "${PMM_CLIENT_DATA_DIR}:/usr/local/percona/pmm/tmp${VOLUME_OPT}" \
  "${IMAGE}" \
  -c "
    pmm-agent setup \
      --server-address='${PMM_SERVER_ADDR}' \
      --server-username='${PMM_USER}' \
      --server-password='${PMM_PASS}' \
      --server-insecure-tls \
      --config-file='/usr/local/percona/pmm/config/pmm-agent.yaml' \
      --force
  "

echo "==> Verify config file exists"
ls -l "${PMM_CLIENT_CONFIG_DIR}/pmm-agent.yaml"
echo

# =========================
# 2) Run（常駐）
# =========================
echo "==> [2/2] Start pmm-client daemon ..."
sudo docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  --network host \
  --entrypoint /bin/sh \
  -v "${PMM_CLIENT_DATA_DIR}:/usr/local/percona/pmm/tmp${VOLUME_OPT}" \
  -v "${PMM_CLIENT_CONFIG_DIR}:/usr/local/percona/pmm/config${VOLUME_OPT}" \
  "${IMAGE}" \
  -c "exec pmm-agent run --config-file='/usr/local/percona/pmm/config/pmm-agent.yaml'"
echo

# =========================
# Post-check
# =========================
echo "==> Container status:"
sudo docker ps --filter "name=${CONTAINER_NAME}"
echo

echo "==> pmm-admin status:"
sudo docker exec -it "${CONTAINER_NAME}" pmm-admin status || true
echo

echo "==> DONE."
echo "Next: add DB services, e.g."
echo "  sudo docker exec -it ${CONTAINER_NAME} pmm-admin add mysql --help"
