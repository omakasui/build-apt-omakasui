# Upstream: https://github.com/omakasui/omakasui-archive-keyring


ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

ARG VERSION
ARG SUITE

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    dpkg-dev \
    debhelper \
    fakeroot \
    gpg \
    git \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone --depth=1 --branch "v${VERSION}" \
      https://github.com/omakasui/omakasui-archive-keyring.git keyrings

WORKDIR /build/keyrings

RUN dpkg-buildpackage -b -uc -us

RUN mkdir -p /output && \
    cp /build/omakasui-core-archive-keyring_*.deb \
       "/output/omakasui-core-archive-keyring_${VERSION}-1+${SUITE}_all.deb"
