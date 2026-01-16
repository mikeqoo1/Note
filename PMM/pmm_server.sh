#!/usr/bin/env bash
set -euo pipefail

PMM_DATA_DIR="/data/pmm/data"     # host path (bind mount)
CONTAINER_NAME="pmm-server"
IMAGE="percona/pmm-server:3"
HOST_HTTPS_PORT="18443"

# PMM Server container runs as pmm user (commonly UID 1000). We'll align host dir perms.
PMM_UID="1000"
PMM_GID="0"   # percona docs常見建議 gid 0

echo "==> Ensure data dir exists: ${PMM_DATA_DIR}"
sudo mkdir -p "${PMM_DATA_DIR}"

# 只在目錄看起來是空的（或沒有初始化 marker）時才做遞迴權限
MARKER="${PMM_DATA_DIR}/.pmm-perms-initialized"
if [[ ! -f "${MARKER}" ]]; then
  echo "==> First-time init perms for ${PMM_DATA_DIR}"
  sudo chown -R "${PMM_UID}:${PMM_GID}" "${PMM_DATA_DIR}"
  sudo chmod -R g+rwX,o-rwx "${PMM_DATA_DIR}"
  sudo find "${PMM_DATA_DIR}" -type d -exec chmod g+s {} \;
  sudo touch "${MARKER}"
else
  echo "==> Perms already initialized, skip recursive chown/chmod"
fi

# SELinux label（Enforcing 才需要）
VOLUME_OPT=""
if command -v getenforce >/dev/null 2>&1; then
  if [[ "$(getenforce)" == "Enforcing" ]]; then
    VOLUME_OPT=":Z"
  fi
fi

echo "==> Remove old container if exists"
sudo docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

echo "==> Start PMM Server (HTTPS only) on host port ${HOST_HTTPS_PORT} -> container 8443"
sudo docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${HOST_HTTPS_PORT}:8443" \
  -v "${PMM_DATA_DIR}:/srv${VOLUME_OPT}" \
  --restart unless-stopped \
  "${IMAGE}"

echo "==> PMM Server started"
echo "Open: https://<your-ip>:${HOST_HTTPS_PORT}"
echo "Default login: admin / admin"
echo
echo "==> Quick check:"
echo "curl -kI https://127.0.0.1:${HOST_HTTPS_PORT}"
echo
echo "==> If something looks wrong:"
echo "sudo docker logs --tail=200 ${CONTAINER_NAME}"
