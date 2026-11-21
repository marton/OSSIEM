# Graylog

Config files and lookup data mounted read-only into the Graylog container.

- `graylog.conf`: `password_secret`, `root_password_sha2` and `elasticsearch_hosts` come
  from the environment (`GRAYLOG_PASSWORD_SECRET`, `GRAYLOG_ROOT_PASSWORD`, `INDEXER_PASSWORD`);
  see `docker-compose.yml`.
- The Wazuh root CA is added to Graylog's Java truststore by the `graylog-truststore`
  init service (`init/graylog-truststore.sh`), so no manual `keytool` step is needed.
- Files only need to be readable. Anything Graylog writes lives in the `graylog_data` volume.
