FROM linuxserver/qbittorrent:latest

# Install WireGuard + utilities
RUN apk add --no-cache wireguard-tools iptables ip6tables iproute2 bash curl

# Remove openresolv completely and create a dummy resolvconf that does nothing
RUN apk del openresolv 2>/dev/null || true && \
    rm -f /sbin/resolvconf /usr/sbin/resolvconf && \
    echo '#!/bin/sh' > /sbin/resolvconf && \
    echo 'exit 0' >> /sbin/resolvconf && \
    chmod +x /sbin/resolvconf

# Create a dummy sysctl that does nothing (to prevent wg-quick from failing)
RUN mv /sbin/sysctl /sbin/sysctl.real && \
    echo '#!/bin/sh' > /sbin/sysctl && \
    echo '/sbin/sysctl.real "$@" 2>/dev/null || exit 0' >> /sbin/sysctl && \
    chmod +x /sbin/sysctl

# Copy s6-overlay service files and configuration
COPY --chmod=755 root/ /

# Expose WebUI port
EXPOSE 8080

# Healthcheck - verify VPN connectivity
HEALTHCHECK --interval=60s --timeout=5s --start-period=30s --retries=3 \
  CMD ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 || exit 1

# Keep linuxserver's /init entrypoint (s6-overlay)
# Our WireGuard setup runs as an s6 init service
