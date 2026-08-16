# Builds omakub-nvim / omadeb-nvim from the omakasui/omakasui-nvim repo.
# Upstream LazyVim starter: https://github.com/LazyVim/starter

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

SHELL ["/bin/bash", "-c"]

ARG VERSION
ARG TARGETARCH
ARG SUITE

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    dpkg-dev \
    debhelper \
    fakeroot \
    git \
    ca-certificates \
    curl \
    nodejs \
    npm \
    unzip \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g tree-sitter-cli

COPY deps/ /tmp/deps/
RUN set -e; \
    DEB=$(ls /tmp/deps/nvim_*_${TARGETARCH}.deb 2>/dev/null | head -1); \
    if [[ -z "$DEB" ]]; then \
      echo "ERROR: nvim dep not found in deps/"; exit 1; \
    fi; \
    apt-get install -y --no-install-recommends "$DEB"; \
    nvim --version

WORKDIR /build

RUN git clone --depth=1 --branch "v${VERSION}" \
      https://github.com/omakasui/omakasui-nvim.git omakasui-nvim

WORKDIR /build/omakasui-nvim

RUN dpkg-buildpackage -b -uc -us

RUN mkdir -p /output && \
    for f in /build/*.deb; do \
      name=$(dpkg-deb --field "$f" Package); \
      cp "$f" "/output/${name}_${VERSION}-1+${SUITE}_all.deb"; \
    done
