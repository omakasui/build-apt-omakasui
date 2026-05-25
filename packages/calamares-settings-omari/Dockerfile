# Builds calamares-settings-omari from the omakasui/calamares-settings-omari repo.

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

ARG VERSION

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    dpkg-dev \
    debhelper \
    fakeroot \
    git \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone --depth=1 https://codeberg.org/omakasui/calamares-settings-omari.git calamares-settings-omari

WORKDIR /build/calamares-settings-omari

RUN dpkg-buildpackage -b -uc -us

RUN mkdir -p /output && cp /build/*.deb /output/
