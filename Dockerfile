# =============================================================================
# Multi-stage Dockerfile
# =============================================================================

# ---- Build Stage ----
FROM fedora:44 AS builder

RUN dnf install -y --setopt=install_weak_deps=False dnf-plugins-core && \
    dnf copr enable -y @asahi/fedora-remix-branding && \
    dnf install -y --setopt=install_weak_deps=False \
        git nodejs npm python3 python3-pip python3-virtualenv \
        vulkan-headers tbb-devel gcc gcc-c++ make && \
    dnf clean all && rm -rf /var/cache/dnf /var/lib/dnf/*

WORKDIR /opt/modly
ARG MODLY_COMMIT="HEAD"

RUN set -euo pipefail && \
    git clone https://github.com/lightningpixel/modly.git . && \
    if [ "$MODLY_COMMIT" != "HEAD" ]; then \
        git checkout "$MODLY_COMMIT"; \
    fi && \
    rm -rf .git

RUN set -euo pipefail && \
    python3 -m venv .venv && \
    . .venv/bin/activate && \
    pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r api/requirements.txt

RUN set -euo pipefail && \
    npm install && \
    npm run build && \
    npm audit fix || true && \
    npm cache clean --force


# ---- Runtime Stage ----
FROM fedora:44

LABEL org.opencontainers.image.source="https://github.com/Biasio/Modly-LinuxAsahi" \
      org.opencontainers.image.description="Modly containerized for Asahi Linux"

RUN dnf install -y --setopt=install_weak_deps=False dnf-plugins-core && \
    dnf copr enable -y @asahi/fedora-remix-branding && \
    dnf install -y --setopt=install_weak_deps=False asahi-repos && \
    dnf install -y --setopt=install_weak_deps=False \
        nodejs npm python3 \
        alsa-lib gtk3 nss lsof libXScrnSaver libXtst libgbm libdrm xcb-util \
        mesa-dri-drivers mesa-libEGL mesa-libGL mesa-libgbm \
        libglvnd libglvnd-opengl libglvnd-egl libglvnd-glx libglvnd-gles \
        mesa-vulkan-drivers && \
    dnf clean all && rm -rf /var/cache/dnf /var/lib/dnf/*

RUN groupadd -g 1000 node && \
    useradd -m -u 1000 -g 1000 -s /bin/bash node && \
    usermod -aG video node

RUN mkdir -p /sys/class/drm
RUN mkdir -p /sys/devices/platform/soc


WORKDIR /opt/modly
COPY --from=builder --chown=node:node /opt/modly /opt/modly
COPY --chown=node:node entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER node
RUN mkdir -p /home/node/shared-volume

ENTRYPOINT ["/entrypoint.sh"]
