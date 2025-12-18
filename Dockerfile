FROM ghcr.io/linuxserver/qbittorrent:latest

# Install WireGuard and networking tools (Alpine Linux)
RUN apk add --no-cache \
    wireguard-tools \
    wireguard-go \
    iptables \
    ip6tables \
    iproute2 \
    curl \
    bash

# Copy startup script
COPY root/ /

# Make scripts executable
RUN chmod +x /etc/cont-init.d/50-wireguard \
             /etc/cont-init.d/60-qbittorrent-config \
             /etc/cont-init.d/99-qbittorrent-wait \
             /etc/services.d/*/run 2>/dev/null || true

# Expose qBittorrent ports
EXPOSE 8080 6881 6881/udp

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080 || exit 1
