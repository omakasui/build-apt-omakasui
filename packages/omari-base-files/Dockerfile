# Builds omari-base-files from the omakasui/omari-base-files repo.

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

RUN git clone --depth=1 https://codeberg.org/omakasui/omari-base-files.git omari-base-files

WORKDIR /build/omari-base-files

RUN dpkg-buildpackage -b -uc -us

RUN mkdir -p /output && \
    for f in /build/*.deb; do \
      name=$(dpkg-deb --field "$f" Package); \
      cp "$f" "/output/${name}_${VERSION}-1+${SUITE}_all.deb"; \
    done
