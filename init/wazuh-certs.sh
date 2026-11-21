#!/bin/bash
# One-shot: generate the Wazuh indexer/manager/dashboard certificates into the
# shared wazuh-certs volume. Runs in wazuh/wazuh-certs-generator.
# Skips when certificates already exist so redeploys keep the same CA.
set -euo pipefail

required="root-ca.pem root-ca.key admin.pem admin-key.pem
  wazuh.indexer.pem wazuh.indexer-key.pem
  wazuh.manager.pem wazuh.manager-key.pem root-ca-manager.pem
  wazuh.dashboard.pem wazuh.dashboard-key.pem"

if [ -f /certificates/wazuh.indexer.pem ]; then
  echo "Certificates already present, skipping generation"
  exit 0
fi

/entrypoint.sh

for f in $required; do
  if [ ! -s "/certificates/$f" ]; then
    echo "ERROR: /certificates/$f was not generated" >&2
    # Leave nothing half-made behind, so the next deploy retries from scratch
    rm -rf /certificates/*
    exit 1
  fi
done

# The generator locks the directory to 0500 root. Services mount the whole
# directory, so it must be traversable; each file stays 0400 for its service uid.
chmod 755 /certificates

# The CA key is only needed to issue more certificates later. Keep it away from
# the indexer/dashboard user (uid 1000) and drop the manager's duplicate copy.
rm -f /certificates/root-ca-manager.key
chown 0:0 /certificates/root-ca.key

echo "Certificates generated"
