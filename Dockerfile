# LunchClaw sandbox image.
#
# Extends NemoClaw's sandbox base with Playwright system dependencies.
# NemoClaw onboard will layer its own entrypoint + plugin on top.
#
# Usage: Set NEMOCLAW_BASE_IMAGE before onboard, or use directly with openshell.

FROM ghcr.io/nvidia/nemoclaw/sandbox-base:latest

# Install Playwright's Chromium system dependencies.
# Do NOT switch USER — NemoClaw's Dockerfile layers on top and expects root.
USER root

# Debian Bookworm package names for Playwright Chromium deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libnspr4 \
    libnss3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libdbus-1-3 \
    libcups2 \
    libxcb1 \
    libxkbcommon0 \
    libasound2 \
    libgbm1 \
    libx11-6 \
    libxext6 \
    libcairo2 \
    libpango-1.0-0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libatspi2.0-0 \
    && rm -rf /var/lib/apt/lists/*
