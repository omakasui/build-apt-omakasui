# Builds omakasui-zellij / omakub-zellij / omadeb-zellij from the
# omakasui/omakasui-zellij repo.
# Upstream: https://github.com/zellij-org/zellij

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

ARG VERSION
ARG SUITE

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    dpkg-dev \
    debhelper \
    fakeroot \
    git \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone --depth=1 --branch "v${VERSION}" \
      https://github.com/omakasui/omakasui-zellij.git omakasui-zellij

WORKDIR /build/omakasui-zellij

RUN dpkg-buildpackage -b -uc -us

RUN mkdir -p /output && \
    for f in /build/*.deb; do \
      name=$(dpkg-deb --field "$f" Package); \
      cp "$f" "/output/${name}_${VERSION}-1+${SUITE}_all.deb"; \
    done
