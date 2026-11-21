# Open Source SIEM Stack

💗 Shoutout to <a href="https://github.com/dLoProdz/OSSIEM">dLoProdz</a> for helping put this together 🧡
<br>
<br>
<br>
The idea behind this project is to facilitate testing of <a href="https://github.com/socfortress">SOCFortress' Open Source SIEM Stack</a>. This is by no means production safe security-wise, 
and only intended to get people started in a lab environment. This project is licensed under GPLv3 which means you can use and modify in it any way you like, so long as you keep it under the same 
licensing scheme. If you don't feel confortable making necessary changes for moving into production you can get in touch with us and we will help you get there.

<div align="center">
    <h3>Watch the Video Walkthrough</h3>
    <a href="https://youtu.be/MRGgywuAUE8">
        <img src="https://img.youtube.com/vi/MRGgywuAUE8/0.jpg" alt="Open Source SIEM Stack" style="width:60%; height:auto;">
    </a>
</div>

## Deployment

The stack deploys with a single `docker compose up -d`, on its own or as a Coolify
"Docker Compose" resource. One-shot init services generate the Wazuh certificates,
the indexer users, Graylog's truststore and the Velociraptor API client for CoPilot,
so the old manual cert/keytool/`api_client` steps are gone.

**Coolify:** follow [DEPLOY.md](DEPLOY.md).

**Plain Docker (lab):**
```
sudo sysctl -w vm.max_map_count=262144
cp .env.example .env        # fill in every empty value
docker compose up -d
```

What is in the stack:

| Service | Notes |
| --- | --- |
| Wazuh manager / indexer / dashboard | SOCFortress manager image (fluent-bit to Graylog) |
| WAZUH-UTILS | SOCFortress sidecar for CoPilot's Sysmon publishing, built from `wazuh/wazuh-utils` |
| Graylog + MongoDB | Stores into the Wazuh indexer |
| Grafana | |
| Velociraptor | Clients connect to `https://STACK_HOST:8100/` |
| CoPilot backend / frontend / customer portal / MySQL / MinIO / MCP / Nuclei | |
| CoPilot File Analysis (inspector-runner + docker-socket-proxy) | Needs `ghcr.io/socfortress/copilot-inspector:latest` pre-pulled |

Configuration lives in:
- `.env.example`: secrets and site-specific values (copy to `.env`, or set in Coolify)
- `copilot.env`: CoPilot backend defaults (upstream's former `.env`)
- `wazuh/config/`, `graylog/`, `grafana/`: service config files

## Post-Deployment

See DEPLOY.md section 4: retrieve the CoPilot admin password, create the Graylog input for
Wazuh alerts, install the SOCFortress Wazuh rules, and set the Grafana datasource header.
Most services still need some tweaking before you can integrate them; follow
<a href="https://www.youtube.com/@taylorwalton_socfortress/videos">Taylor's Videos</a>.

## Credits

Huge shoutout to <a href="https://github.com/socfortress">SOCFortress</a> and <a href="https://www.youtube.com/@taylorwalton_socfortress/featured">Taylor Walton</a> for their hard work and 
contributions to the open source community. And of course all credits to the <a href="https://github.com/wazuh">Wazuh Team</a> for their amazing product.
