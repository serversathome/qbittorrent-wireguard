FROM ghcr.io/linuxserver/qbittorrent:latest

# Install WireGuard and networking tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wireguard-tools \
    iptables \
    iproute2 \
    curl \
    procps && \
    rm -rf /var/lib/apt/lists/*

# Copy startup script
COPY root/ /

# Make scripts executable
RUN chmod +x /etc/cont-init.d/* /etc/services.d/*/run

# Expose qBittorrent ports
EXPOSE 8080 6881 6881/udp

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080 || exit 1
