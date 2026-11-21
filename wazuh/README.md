# Wazuh

- `config/certs.yml`: node names for the certificate generator. The `wazuh-certs` init
  service (`init/wazuh-certs.sh`) creates the certificates in the `wazuh-certs` volume on
  first deploy.
- `config/wazuh_indexer/wazuh.indexer.yml`: indexer config. Internal users are generated
  from `INDEXER_PASSWORD`/`DASHBOARD_PASSWORD` by `init/indexer-security.sh`.
- `config/wazuh_dashboard/opensearch_dashboards.yml`: dashboard config. `wazuh.yml` is
  written by the dashboard image from `API_USERNAME`/`API_PASSWORD`.
- `config/wazuh_cluster/wazuh_manager.conf`: the manager's `ossec.conf`.
- `custom-wazuh-manager/`: source of the SOCFortress manager image (fluent-bit to Graylog).
- `wazuh-utils/`: container build of socfortress/WAZUH-UTILS.

The host needs `vm.max_map_count=262144` for the indexer.
