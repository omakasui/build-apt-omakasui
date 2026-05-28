# Builds omari-settings from the omakasui/omari-settings repo.

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

RUN git clone --depth=1 https://codeberg.org/omakasui/omari-settings.git omari-settings

WORKDIR /build/omari-settings

RUN dpkg-buildpackage -b -uc -us

RUN mkdir -p /output && cp /build/*.deb /output/
