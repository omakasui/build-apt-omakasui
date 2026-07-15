#!/usr/bin/env bash
# lint.sh — Validate package definitions and optionally run lintian.
# Usage: lint.sh [<package>] [--lintian]
# Note: entries with external: true in versions.yml are skipped.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_cmd yq

PKG_FILTER=""
RUN_LINTIAN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lintian) RUN_LINTIAN=true; shift ;;
    --help|-h)
      sed -n '2,/^$/{ s/^# //; s/^#$//; p }' "$0"
      exit 0
      ;;
    -*) die "unknown flag: $1" ;;
    *)  PKG_FILTER="$1"; shift ;;
  esac
done

cd "${REPO_ROOT}"

ERRORS=0
CHECKED=0

lint_one() {
  local key="$1"
  local pkg_dir="packages/${key}"
  local pkg_yaml="${pkg_dir}/package.yml"
  local debian_dir="${pkg_dir}/debian"

  CHECKED=$((CHECKED + 1))

  local ver
  ver=$(yq e ".${key}.version // \"\"" versions.yml)
  if [[ -z "$ver" || "$ver" == "null" ]]; then
    warn "${key}: missing from versions.yml"
    ERRORS=$((ERRORS + 1)); return
  fi

  if [[ ! -f "$pkg_yaml" ]]; then
    warn "${key}: missing package.yml"
    ERRORS=$((ERRORS + 1)); return
  fi

  local pkg_type
  pkg_type=$(yq e '.type // "build"' "$pkg_yaml")

  if [[ ! -f "${pkg_dir}/Dockerfile" ]]; then
    warn "${key}: missing Dockerfile"
    ERRORS=$((ERRORS + 1))
  fi

  # Packages with debian/ directory: validate control template fields.
  if [[ -d "$debian_dir" && -f "${debian_dir}/control" ]]; then
    for field in Package Architecture Maintainer Description; do
      if ! grep -q "^${field}:" "${debian_dir}/control"; then
        warn "${key}: debian/control missing required field '${field}'"
        ERRORS=$((ERRORS + 1))
      fi
    done
    if ! grep -q '@VERSION@' "${debian_dir}/control"; then
      warn "${key}: debian/control has no @VERSION@ placeholder"
      ERRORS=$((ERRORS + 1))
    fi
    [[ ! -f "${debian_dir}/changelog" ]] && \
      warn "${key}: debian/changelog missing (required for Debian Policy §12.7)"
    [[ ! -f "${debian_dir}/copyright" ]] && \
      warn "${key}: debian/copyright missing (required for Debian Policy §12.7)"
  else
    # No debian/ dir: only valid for type:repackage (Docker-assembled) packages.
    if [[ "$pkg_type" == "build" ]]; then
      warn "${key}: type=build requires a debian/ directory"
      ERRORS=$((ERRORS + 1))
    fi
  fi

  local distro_count valid_distros
  distro_count=$(yq e '.distros | length' "$pkg_yaml" 2>/dev/null || echo 0)
  if [[ "$distro_count" == "0" || "$distro_count" == "null" ]]; then
    warn "${key}: no distros declared in package.yml"
    ERRORS=$((ERRORS + 1))
  fi

  valid_distros=$(yq e '.distros | keys | .[]' build-matrix.yml | tr '\n' ' ')
  while IFS= read -r distro; do
    [[ -z "$distro" ]] && continue
    if ! grep -qw "$distro" <<< "$valid_distros"; then
      warn "${key}: distro '${distro}' not in build-matrix.yml"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(yq e '.distros // [] | .[]' "$pkg_yaml")

  local deps_csv
  deps_csv=$(yq e ".${key}.depends_on | join(\",\")" versions.yml)
  if [[ -n "$deps_csv" && "$deps_csv" != "null" ]]; then
    IFS=',' read -ra deps <<< "$deps_csv"
    for dep in "${deps[@]}"; do
      [[ -z "$dep" ]] && continue
      # Skip directory check for external deps (they live in build-apt-packages).
      local dep_external
      dep_external=$(yq e ".${dep}.external // false" versions.yml 2>/dev/null || echo false)
      [[ "$dep_external" == "true" ]] && continue
      if [[ ! -d "packages/${dep}" ]]; then
        warn "${key}: depends_on '${dep}' has no packages/${dep}/ directory"
        ERRORS=$((ERRORS + 1))
      fi
    done
  fi
}

if [[ -n "$PKG_FILTER" ]]; then
  lint_one "$PKG_FILTER"
else
  while IFS= read -r key; do
    # Skip external deps — they are version-tracked only, not built here.
    local_external=$(yq e ".${key}.external // false" versions.yml 2>/dev/null || echo false)
    [[ "$local_external" == "true" ]] && continue
    lint_one "$key"
  done < <(yq e 'keys | .[]' versions.yml)
fi

echo ""
if [[ $ERRORS -gt 0 ]]; then
  die "Lint finished: ${ERRORS} error(s) in ${CHECKED} package(s)."
else
  info "Lint OK: ${CHECKED} package(s) checked, no errors."
fi

# Optional: run lintian on built output.
if [[ "$RUN_LINTIAN" == true ]]; then
  if ! command -v lintian >/dev/null 2>&1; then
    warn "lintian not installed — skipping"
    exit 0
  fi
  TARGET="${PKG_FILTER:-*}"
  shopt -s nullglob
  debs=("${REPO_ROOT}/output/${TARGET}/"*.deb)
  if [[ ${#debs[@]} -eq 0 ]]; then
    warn "No .deb files found in output/${TARGET}/ — run 'make build' first"
    exit 0
  fi
  step "Running lintian on ${#debs[@]} package(s)..."
  lintian --info --display-info "${debs[@]}" || true
fi
