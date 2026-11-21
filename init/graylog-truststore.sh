#!/bin/bash
# One-shot: build a Java truststore holding the JVM's default CAs plus the Wazuh
# root CA, so Graylog can talk TLS to the Wazuh indexer. Runs in graylog/graylog
# as root, writing to the graylog-truststore volume.
# Re-imports the CA on every deploy, so a regenerated CA is picked up.
set -euo pipefail

ks=/truststore/cacerts
pass=changeit

if [ ! -f "$ks" ]; then
  cp /opt/java/openjdk/lib/security/cacerts "$ks"
fi

keytool -delete -alias wazuh_root_ca -keystore "$ks" -storepass "$pass" >/dev/null 2>&1 || true
keytool -importcert -noprompt -alias wazuh_root_ca -file /certs/root-ca.pem -keystore "$ks" -storepass "$pass"

chown 1100:1100 "$ks"
chmod 644 "$ks"

echo "Truststore ready"
