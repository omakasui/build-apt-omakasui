# Packages the zellij configuration for omakasui variants.
# Upstream: https://github.com/zellij-org/zellij

ARG BASE_IMAGE
FROM ${BASE_IMAGE:-debian:trixie-slim}

ARG VERSION
ARG SUITE

WORKDIR /build

COPY config.kdl            config.kdl
COPY setup-zellij.template setup-zellij.template

RUN set -e; \
    mkdir -p /output/staged; \
    for PROJECT in omakub omadeb; do \
      PKG_NAME="${PROJECT}-zellij"; \
      SHARE_DIR="/usr/share/${PKG_NAME}"; \
      STAGED="/output/staged/${PKG_NAME}"; \
      \
      # Stage config. \
      mkdir -p "${STAGED}${SHARE_DIR}/config"; \
      cp config.kdl "${STAGED}${SHARE_DIR}/config/config.kdl"; \
      chmod -R 755 "${STAGED}${SHARE_DIR}"; \
      find "${STAGED}${SHARE_DIR}" -type f -exec chmod 644 {} \;; \
      \
      # Instantiate setup script from template. \
      mkdir -p "${STAGED}/usr/bin"; \
      SETUP="${STAGED}/usr/bin/${PROJECT}-setup-zellij"; \
      sed \
        -e "s|{{PROJECT}}|${PROJECT}|g" \
        -e "s|{{PKG_NAME}}|${PKG_NAME}|g" \
        /build/setup-zellij.template > "$SETUP"; \
      chmod 755 "$SETUP"; \
    done
