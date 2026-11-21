# Deploying OSSIEM on Coolify

Handover notes for deploying this repo as one Coolify resource on a NAS-hosted VM.
`docker-compose.yml` is self-contained: certificates, indexer users, the Graylog
truststore and the Velociraptor API client are created by one-shot init services,
so there are no `docker exec` steps before first use.

## 1. Host (the Coolify VM)

| Requirement | Why |
| --- | --- |
| **x86_64 (amd64)** | Velociraptor, the SOCFortress Wazuh manager and the indexer images are amd64-only |
| **CPU exposes AVX** | MongoDB 5+ crashes without it. On Proxmox/most NAS hypervisors set the VM CPU type to `host` (not `kvm64`/`qemu64`). Check: `grep -m1 -o avx /proc/cpuinfo` |
| **RAM ≥ 16 GB** (12 GB minimum) | Indexer 1 GB heap by default plus Graylog, MySQL, MongoDB, CoPilot, Grafana, Velociraptor |
| **Disk ≥ 100 GB** for Docker volumes | Indexer and Graylog journal grow with log volume |
| `vm.max_map_count=262144` | Required by the Wazuh indexer (OpenSearch) |

```bash
# On the VM, as root, persistent across reboots
cat > /etc/sysctl.d/99-ossiem.conf <<'EOF'
vm.max_map_count=262144
net.core.rmem_max=1048576
EOF
sysctl --system

# File Analysis: inspector-runner can only start this image, not pull it
docker pull ghcr.io/socfortress/copilot-inspector:latest
```

## 2. Coolify resource

1. **+ New → Application → (Public or Private) Git repository** pointing at this repo, branch `main`.
2. **Build Pack: Docker Compose**, Base Directory `/`, Docker Compose Location `/docker-compose.yml`.
3. In the resource's advanced settings, enable **Preserve Repository During Deployment**.
   The stack bind-mounts files from the repo (`init/`, `wazuh/config/`, `graylog/`, `grafana/`);
   without this they turn into empty directories and the init services fail.
4. **Environment Variables:** set every variable in `.env.example` that has no default.
   Coolify writes them to `.env` next to the compose file; compose refuses to start and
   names the missing variable if one is unset. Mind the character rules at the top of
   `.env.example`, especially for `INDEXER_PASSWORD`, `WAZUH_API_PASSWORD` and the MySQL passwords.
   Set `STACK_HOST` to the VM's LAN IP or DNS name **before the first deploy**: it is
   baked into Velociraptor client configs and the CoPilot certificate on first start.
5. **Domains:** leave empty. Every UI is published directly on a host port (below) with
   its own TLS. Do not give `copilot-frontend` a Coolify domain on port 80: its port 80 only
   redirects to https, which loops behind Traefik. Grafana (3000) and Graylog (9000) are
   plain HTTP and can be put behind Coolify's proxy with a domain if wanted.
6. Deploy. The first deploy pulls about 10 GB of images, builds `wazuh-utils`, and takes
   several minutes. The indexer needs 1-2 minutes before its dependants start.

Expected state afterwards: `wazuh-certs`, `wazuh-indexer-security` and `graylog-truststore`
are **Exited (0)**, which is normal for one-shot services. Coolify may show the resource as
"degraded" because of them. Everything else is running, and `wazuh.indexer`, `mongodb`,
`graylog` and `copilot-mysql` report healthy. `velociraptor` restarts once on first boot
(deliberately, to load the CoPilot API user).

## 3. Ports

Coolify itself uses 80, 443, 8000, 8080, 6001 and 6002; the stack avoids them.

| Host port | Service | Who connects |
| --- | --- | --- |
| 8443/tcp | CoPilot (https, self-signed) | Analysts |
| 8444/tcp | CoPilot customer portal (https) | Customers (optional) |
| 5601/tcp | Wazuh dashboard (https) | Analysts |
| 9000/tcp | Graylog web/API | Analysts |
| 3000/tcp | Grafana | Analysts |
| 8889/tcp | Velociraptor GUI (https) | Analysts |
| 5000/tcp | CoPilot backend API/docs | Optional |
| 1514/tcp, 1515/tcp | Wazuh agent events / enrollment | Endpoints |
| 55000/tcp | Wazuh API | Optional (CoPilot uses the internal network) |
| 8100/tcp | Velociraptor client frontend | Endpoints |
| 514/udp, 2514/udp | Graylog syslog | Firewalls/network devices |
| 12201/tcp+udp | Graylog GELF | Log shippers |

Not published (stack network only): the Wazuh indexer (9200), MongoDB, MySQL, MinIO,
Velociraptor gRPC API (8001), CoPilot MCP, WAZUH-UTILS (5003), inspector-runner.
UI ports can be changed with the `*_PORT` variables in `.env.example`.

## 4. After the first deploy

Container names in Coolify are `<service>-<resource uuid>`, so find them with
`docker ps --filter name=<service>`.

1. **CoPilot admin password** (only printed on first start):
   ```bash
   docker logs $(docker ps -q --filter name=copilot-backend) 2>&1 | grep "Admin user password"
   ```
2. **Graylog ingestion of Wazuh alerts.** The SOCFortress manager image ships alerts with
   fluent-bit to `graylog:5555`. In Graylog create a *Raw/Plaintext TCP* input on port 5555
   plus the `wazuh-alerts` index set and stream, as in the SOCFortress videos
   (https://www.youtube.com/@taylorwalton_socfortress). Port 5555 stays internal.
3. **SOCFortress Wazuh rules** (interactive):
   ```bash
   docker exec -it $(docker ps -q --filter name=wazuh.manager) bash
   dnf install git -y
   curl -so ~/wazuh_socfortress_rules.sh https://raw.githubusercontent.com/socfortress/OSSIEM/main/wazuh_socfortress_rules.sh && bash ~/wazuh_socfortress_rules.sh
   ```
4. **CoPilot connectors** are seeded from the environment on first start (indexer,
   manager, Graylog, Grafana, Velociraptor). The Velociraptor connector's API key field
   is the path `/velociraptor-api/api.config.yaml`. The file is created automatically and
   shared read-only with `copilot-backend` and `copilot-mcp`.
5. **Grafana:** on CoPilot's Grafana datasource, add a request header `grafana` with the
   value of `GRAFANA_API_HEADER_VALUE`.
6. **Velociraptor clients:** repacked clients pointing at `https://STACK_HOST:8100/` are in
   the `velociraptor` volume under `clients/` (`docker cp` them out of the container).

## 5. Things to know

- **Passwords are applied on first deploy.** Changing `INDEXER_PASSWORD`/`DASHBOARD_PASSWORD`
  later does not change the indexer users. Either hash the new password with
  `plugins/opensearch-security/tools/hash.sh`, edit `config/opensearch-security/internal_users.yml`
  in the indexer, and run `securityadmin.sh`, or (empty lab only) delete the
  `wazuh-indexer-security` and `wazuh-indexer-data` volumes. `GRAYLOG_PASSWORD_SECRET`,
  `TOTP_ENCRYPTION_KEY` and `WAF_TOKEN_ENCRYPTION_KEY` must never change after first start.
- **Certificates** live in the `wazuh-certs` volume and are only generated when it is empty.
  The CA key (`root-ca.key`) is in there too, root-only. Back it up if you plan to add Wazuh
  workers.
- **Upgrades:** `WAZUH_VERSION` moves the manager, indexer and dashboard together; keep them
  equal. SOCFortress publishes manager tags up to 4.14.7. CoPilot images are `:latest`, so
  redeploy to update and read the CoPilot release notes first. WAZUH-UTILS is pinned by
  commit in `wazuh/wazuh-utils/Dockerfile`.
- **`wazuh-utils`** shares the manager's `/var/ossec/etc` volume and writes files as the
  manager's `wazuh` user (uid/gid build args in its Dockerfile). Its key lets CoPilot push
  scripts that run as SYSTEM on Windows agents. Treat it like a domain admin credential.
- **File Analysis** mounts `/var/run/docker.sock` into `docker-socket-proxy` (limited to
  container create/start/attach/remove). Remove `docker-socket-proxy` and `inspector-runner`
  if you don't want that on the Coolify host.

## 6. Related SOCFortress products (separate Coolify resources)

`copilot.env` has settings for products that ship their own stacks. Deploy each as its
own Coolify Docker Compose resource from its repo, then point CoPilot at it.

| Product | Repo | CoPilot variables |
| --- | --- | --- |
| UBA (User Behavior Analytics, ~4 GB RAM) | `socfortress/socfortress-uba-deploy` | `SOCFORTRESS_UBA_URL`, `SOCFORTRESS_UBA_API_KEY` |
| Talon | `taylorwalton/talon` | `TALON_URL`, `TALON_API_KEY` |
| OpenCTI (+ `socfortress/OPENCTI-MIDDLEWARE` for Graylog lookups) | OpenCTI docker | `OPENCTI_URL`, `OPENCTI_API_KEY` |
| SOCFortress MDR forwarding | hosted | `MDR_ENABLED`, `MDR_SERVER_URL`, `MDR_COLLECTOR_UUID` |

UBA publishes GELF on 12201, the same port as Graylog here. Set `UBA_GELF_PUBLISH`
to another port (e.g. 12202) and `UBA_API_PUBLISH` (default 8010) to a free one.
To set these CoPilot variables, add them to `copilot-backend`'s `environment:` in
`docker-compose.yml` (or edit `copilot.env`) and redeploy.
