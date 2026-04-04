# LunchClaw sandbox image.
#
# Matches NemoClaw's pinned dependencies (Dockerfile.base from NVIDIA/NemoClaw)
# plus Playwright system libraries for browser automation.
#
# Build via: openshell sandbox create --name lunchclaw --from .

# Same base image NemoClaw uses
FROM node:22-slim

# Install OpenClaw CLI — pinned to the version NemoClaw is tested against
# See: https://github.com/NVIDIA/NemoClaw/blob/main/Dockerfile.base
RUN npm install -g openclaw@2026.3.11

# Install Playwright's Chromium system dependencies.
# The OpenShell sandbox security model prevents installing packages at
# runtime (no root access), so they must be baked into the image.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0t64 \
    libnspr4 \
    libnss3 \
    libatk1.0-0t64 \
    libatk-bridge2.0-0t64 \
    libdbus-1-3 \
    libcups2t64 \
    libxcb1 \
    libxkbcommon0 \
    libasound2t64 \
    libgbm1 \
    libx11-6 \
    libxext6 \
    libcairo2 \
    libpango-1.0-0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libatspi2.0-0t64 \
    && rm -rf /var/lib/apt/lists/*
