#!/bin/sh
# Creates the sidecar's self-signed TLS certificate once (kept in the /tls volume),
# then serves the API the way upstream's systemd unit does.
set -eu

if [ -z "${WAZUH_UTILS_API_KEY:-}" ]; then
  echo "WAZUH_UTILS_API_KEY must be set" >&2
  exit 1
fi

shared="${WAZUH_UTILS_SHARED_DIR:-/var/ossec/etc/shared}"
if [ -d "$shared" ] && [ "$(stat -c %u "$shared")" != "$(id -u)" ]; then
  echo "WARNING: $shared is owned by uid $(stat -c %u "$shared"), this sidecar runs as" \
    "uid $(id -u). Rebuild with WAZUH_UID/WAZUH_GID matching the manager's wazuh user." >&2
fi

if [ ! -s /tls/wazuh-utils.crt ]; then
  openssl req -x509 -newkey rsa:3072 -sha256 -days 1825 -nodes \
    -subj "/CN=wazuh-utils" -addext "subjectAltName=DNS:wazuh-utils" \
    -keyout /tls/wazuh-utils-tls.key -out /tls/wazuh-utils.crt
  chmod 600 /tls/wazuh-utils-tls.key
fi

exec uvicorn app:app --host 0.0.0.0 --port 5003 --workers 2 \
  --timeout-keep-alive 60 --limit-concurrency 32 \
  --ssl-certfile /tls/wazuh-utils.crt --ssl-keyfile /tls/wazuh-utils-tls.key
