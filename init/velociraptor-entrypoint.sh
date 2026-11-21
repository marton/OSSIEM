#!/bin/bash
# Wraps the Velociraptor image entrypoint. Once the server config exists, creates
# an API client config for CoPilot and the MCP server in the velociraptor-api
# volume (replaces the manual `config api_client` step). Needs a restart policy:
# the first boot ends with one deliberate restart.

api_config=/velociraptor-api/api.config.yaml

(
  # client.config.yaml is written after the server config and the GUI user
  until [ -f /velociraptor/client.config.yaml ]; do sleep 5; done
  sleep 10
  if [ ! -s "$api_config" ]; then
    cd /velociraptor || exit 1
    ./velociraptor --config server.config.yaml config api_client \
      --name "${VELOX_API_USER:-copilot}" --role administrator,api /tmp/api.config.yaml
    # The generated connection string points at localhost; other containers
    # reach the API through the service name.
    sed -i "s#^api_connection_string:.*#api_connection_string: velociraptor:8001#" /tmp/api.config.yaml
    install -m 644 /tmp/api.config.yaml "$api_config"
    rm -f /tmp/api.config.yaml
    echo "Wrote $api_config"
    # The running server only sees the new API user after a restart. Stopping
    # the frontend ends the container; the restart policy brings it back.
    echo "Restarting Velociraptor so it loads the API user"
    pkill -f "velociraptor --config server.config.yaml frontend"
  fi
) &

exec /entrypoint
