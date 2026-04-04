# LunchClaw sandbox image — OpenClaw + Playwright system dependencies.
# Build: openshell sandbox create --name lunchclaw-prod --from . --policy policies/network.yaml
#
# This extends the OpenClaw community image with the system libraries
# Playwright needs for headless Chromium. The OpenShell sandbox security
# model prevents installing packages at runtime (no root), so they
# must be baked into the image.

FROM ghcr.io/nvidia/openshell-community/sandboxes/openclaw:latest

USER root

# Install Playwright's Chromium system dependencies
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

# Drop back to sandbox user
USER sandbox
