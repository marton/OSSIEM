#!/bin/bash
# Wraps the Graylog image entrypoint: derives the root password hash from the
# plaintext password CoPilot also uses, so the two can't drift apart.
set -euo pipefail

: "${GRAYLOG_ROOT_PASSWORD:?GRAYLOG_ROOT_PASSWORD must be set}"

GRAYLOG_ROOT_PASSWORD_SHA2=$(printf '%s' "$GRAYLOG_ROOT_PASSWORD" | sha256sum | cut -d' ' -f1)
export GRAYLOG_ROOT_PASSWORD_SHA2
unset GRAYLOG_ROOT_PASSWORD

exec /docker-entrypoint.sh "$@"
