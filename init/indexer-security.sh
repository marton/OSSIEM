#!/bin/bash
# One-shot: build the indexer's opensearch-security config with internal users
# whose passwords come from the environment instead of the public demo hashes.
# Runs in wazuh/wazuh-indexer as root, writing to the wazuh-indexer-security volume.
#
# The indexer only loads these files when it creates its security index on
# first boot. Changing a password afterwards needs securityadmin.sh (see DEPLOY.md).
set -euo pipefail

dest=/security
src=/usr/share/wazuh-indexer/config/opensearch-security

if [ -f "$dest/.initialised" ]; then
  echo "Security config already initialised, skipping"
  exit 0
fi

: "${INDEXER_PASSWORD:?INDEXER_PASSWORD must be set}"
: "${DASHBOARD_PASSWORD:?DASHBOARD_PASSWORD must be set}"

export JAVA_HOME=/usr/share/wazuh-indexer/jdk
hash_password() {
  bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -p "$1" | tail -n1
}

admin_hash=$(hash_password "$INDEXER_PASSWORD")
kibanaserver_hash=$(hash_password "$DASHBOARD_PASSWORD")

cp -a "$src/." "$dest/"

# Only the two users the stack needs; the other demo users have public passwords.
cat > "$dest/internal_users.yml" <<EOF
---
_meta:
  type: "internalusers"
  config_version: 2

admin:
  hash: "${admin_hash}"
  reserved: true
  backend_roles:
  - "admin"
  description: "Admin user (Graylog, CoPilot, Wazuh manager)"

kibanaserver:
  hash: "${kibanaserver_hash}"
  reserved: true
  description: "Wazuh dashboard server user"
EOF

chown -R 1000:1000 "$dest"
chmod 750 "$dest"
find "$dest" -type f -exec chmod 640 {} +
touch "$dest/.initialised"

echo "Security config initialised"
