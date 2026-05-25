# Builds omakasui-archive-keyring from the omakasui/omakasui-archive-keyring repo.
# Requires fetch-key.sh to download the GPG keys before dpkg-buildpackage.

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

ARG VERSION

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
    build-essential \
    dpkg-dev \
    debhelper \
    fakeroot \
    curl \
    gpg \
    git \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone --depth=1 https://codeberg.org/omakasui/omakasui-archive-keyring.git omakasui-archive-keyring

WORKDIR /build/omakasui-archive-keyring

# Fetch GPG keys from upstream (required before dpkg-buildpackage).
RUN ./fetch-key.sh

RUN dpkg-buildpackage -b -uc -us

RUN mkdir -p /output && cp /build/*.deb /output/
