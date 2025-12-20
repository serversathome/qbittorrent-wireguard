FROM linuxserver/qbittorrent:latest
USER root

# Install WireGuard + utilities
RUN apk add --no-cache wireguard-tools iptables ip6tables iproute2 bash curl

# Remove openresolv completely and create a dummy resolvconf that does nothing
RUN apk del openresolv 2>/dev/null || true && \
    rm -f /sbin/resolvconf /usr/sbin/resolvconf && \
    echo '#!/bin/sh' > /sbin/resolvconf && \
    echo 'exit 0' >> /sbin/resolvconf && \
    chmod +x /sbin/resolvconf

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose WebUI port
EXPOSE 8080

# Healthcheck
HEALTHCHECK --interval=60s --timeout=5s --start-period=30s --retries=3 \
  CMD ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/entrypoint.sh"]
