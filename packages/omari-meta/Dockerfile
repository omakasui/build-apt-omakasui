# Builds the omari metapackages from the omakasui/omari-meta repo.
# Produces: omari-base, omari-desktop-niri, omari-drivers, omari-live

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

# Clone omari-meta at the tag matching the package version.
# Tag convention: v<version> (e.g. v1.0.0).
# Falls back to main if the tag does not exist yet.
RUN git clone --depth=1 \
      $(git ls-remote --tags https://codeberg.org/omakasui/omari-meta "refs/tags/v${VERSION}" | grep -q . \
        && echo "--branch v${VERSION}" || echo "--branch main") \
      https://codeberg.org/omakasui/omari-meta.git omari-meta 2>/dev/null || \
    git clone --depth=1 https://codeberg.org/omakasui/omari-meta.git omari-meta

WORKDIR /build/omari-meta

RUN dpkg-buildpackage -b -uc -us

RUN mkdir -p /output && \
    for f in /build/*.deb; do \
      name=$(dpkg-deb --field "$f" Package); \
      cp "$f" "/output/${name}_${VERSION}-1+${SUITE}_all.deb"; \
    done
