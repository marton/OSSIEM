# SOCFortress WAZUH-UTILS sidecar (https://github.com/socfortress/WAZUH-UTILS) as a
# container. Upstream ships it as a systemd service on the Wazuh master; here it
# shares the manager's /var/ossec/etc volume instead.
FROM python:3.11-slim

# Upstream commit to build. Bump to upgrade.
ARG WAZUH_UTILS_REF=5c6f2752947b195c74d6ff5d005870445db75abf
# Must match the wazuh user/group inside the manager image, so written files
# are owned by the manager's wazuh account.
ARG WAZUH_UID=999
ARG WAZUH_GID=999

RUN apt-get update \
    && apt-get install -y --no-install-recommends openssl \
    && rm -rf /var/lib/apt/lists/*

ADD https://codeload.github.com/socfortress/WAZUH-UTILS/tar.gz/${WAZUH_UTILS_REF} /tmp/wazuh-utils.tar.gz
RUN mkdir /app \
    && tar -xzf /tmp/wazuh-utils.tar.gz -C /app --strip-components=1 \
    && rm /tmp/wazuh-utils.tar.gz \
    && pip install --no-cache-dir -r /app/requirements.in

RUN groupadd -g ${WAZUH_GID} wazuh \
    && useradd -u ${WAZUH_UID} -g wazuh -M -d /app -s /usr/sbin/nologin wazuh \
    && mkdir /tls && chown wazuh:wazuh /tls

COPY entrypoint.sh /entrypoint.sh

USER wazuh
WORKDIR /app
EXPOSE 5003
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
