#!/usr/bin/env bash
# Resolve CI build and publication matrices.
# Usage: detect-changes.sh --mode push|dispatch|all|product|platform
#        [--package <name>] [--product <name>] [--suite <suite>] [--platform <name>]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/metadata.sh"

require_cmd yq jq

MODE="" MANUAL_PKG="" FILTER_PRODUCT="" FILTER_SUITE="" FILTER_PLATFORM=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)     MODE="$2";            shift 2 ;;
    --package)  MANUAL_PKG="$2";      shift 2 ;;
    --product)  FILTER_PRODUCT="$2";  shift 2 ;;
    --suite)    FILTER_SUITE="$2";    shift 2 ;;
    --platform) FILTER_PLATFORM="$2"; shift 2 ;;
    --distro)   FILTER_PLATFORM="$2"; shift 2 ;; # Deprecated alias.
    *) die "unknown argument: $1" ;;
  esac
done
[[ -z "$MODE" ]] && die "--mode is required (push, dispatch, all, product, or platform)"
[[ "$MODE" == "distro" ]] && MODE="platform" # Deprecated mode alias.

cd "$(repo_root)" || die "cannot enter repo root"

_output() {
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then echo "${1}=${2}" >> "$GITHUB_OUTPUT"; else echo "${1}=${2}"; fi
}

all_internal_packages() {
  while IFS= read -r pkg; do
    [[ "$(is_external "$pkg")" == "true" ]] || echo "$pkg"
  done < <(pkg_all_keys)
}

case "$MODE" in
  all) PACKAGES=$(all_internal_packages | xargs) ;;
  product)
    [[ -n "$FILTER_PRODUCT" ]] || die "--product is required for product mode"
    yq e ".products.${FILTER_PRODUCT} // \"\"" build-matrix.yml | grep -qv '^$' || die "unknown product '${FILTER_PRODUCT}'"
    [[ -z "$FILTER_SUITE" ]] || matrix_target_platform "$FILTER_PRODUCT" "$FILTER_SUITE" >/dev/null
    PACKAGES=""
    while IFS= read -r pkg; do
      pkg_products "$pkg" | grep -qx "$FILTER_PRODUCT" && PACKAGES+=" $pkg"
    done < <(all_internal_packages)
    PACKAGES=$(echo "$PACKAGES" | xargs)
    ;;
  platform)
    [[ -n "$FILTER_PLATFORM" ]] || die "--platform is required for platform mode"
    matrix_base_image "$FILTER_PLATFORM" >/dev/null
    PACKAGES=$(all_internal_packages | xargs)
    ;;
  dispatch)
    [[ -n "$MANUAL_PKG" ]] || die "--package is required for dispatch mode"
    [[ "$(is_external "$MANUAL_PKG")" == "true" ]] && die "${MANUAL_PKG} is external"
    PACKAGES="$MANUAL_PKG"
    ;;
  push)
    OLD_VERSIONS=$(mktemp)
    trap 'rm -f "$OLD_VERSIONS"' EXIT
    git show HEAD~1:versions.yml > "$OLD_VERSIONS" 2>/dev/null || echo "---" > "$OLD_VERSIONS"
    PACKAGES=""
    if git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -qx 'build-matrix.yml'; then
      PACKAGES=$(all_internal_packages | xargs)
    else
      while IFS= read -r pkg; do
        OLD_VER=$(yq e ".${pkg}.version // \"\"" "$OLD_VERSIONS")
        NEW_VER=$(yq e ".${pkg}.version // \"\"" versions.yml)
        if [[ "$OLD_VER" != "$NEW_VER" ]] || git diff --name-only HEAD~1 HEAD 2>/dev/null | grep -qx "packages/${pkg}/package.yml"; then
          PACKAGES+=" $pkg"
        fi
      done < <(all_internal_packages)
      PACKAGES=$(echo "$PACKAGES" | xargs)
    fi
    ;;
  *) die "unknown mode: ${MODE}" ;;
esac

TRIGGERED=""
for PKG in $PACKAGES; do
  if yq e ".${PKG}.triggers" versions.yml | grep -qv 'null'; then
    while IFS= read -r triggered; do
      [[ -z "$triggered" || "$triggered" == "null" ]] && continue
      echo "$PACKAGES $TRIGGERED" | grep -qw "$triggered" || TRIGGERED+=" $triggered"
    done < <(yq e ".${PKG}.triggers[]" versions.yml 2>/dev/null)
  fi
done
PACKAGES=$(echo "$PACKAGES $TRIGGERED" | xargs)

if [[ -z "$PACKAGES" ]]; then
  info "No package changes detected."
  _output builds '[]'; _output build_matrix '{"include":[]}'
  exit 0
fi

BUILDS='[]' FLAT_MATRIX='[]'
for PKG in $PACKAGES; do
  VERSION=$(yq e ".${PKG}.version // \"\"" versions.yml)
  [[ -z "$VERSION" || "$VERSION" == "null" ]] && { warn "${PKG} not found, skipping"; continue; }
  DEPENDS=$(pkg_depends_on "$PKG")
  FROZEN_TARGETS=$(yq e ".${PKG}.frozen_targets // [] | join(\" \")" versions.yml)
  TARGETS='[]' PLATFORM_SET='[]'

  while IFS= read -r product; do
    [[ -n "$FILTER_PRODUCT" && "$product" != "$FILTER_PRODUCT" ]] && continue
    PRODUCES=$(yq -o=json -I=0 e ".publications.${product}.produces" "packages/${PKG}/package.yml")
    while IFS= read -r suite; do
      [[ -n "$FILTER_SUITE" && "$suite" != "$FILTER_SUITE" ]] && continue
      [[ "$(matrix_target_status "$product" "$suite")" != "active" ]] && continue
      platform=$(matrix_target_platform "$product" "$suite")
      [[ -n "$FILTER_PLATFORM" && "$platform" != "$FILTER_PLATFORM" ]] && continue
      target="${product}/${suite}"
      if [[ -n "$FROZEN_TARGETS" ]] && grep -qw "$target" <<< "$FROZEN_TARGETS"; then
        info "Skip: ${PKG}/${target} is frozen"; continue
      fi
      TARGETS=$(jq -c --arg product "$product" --arg suite "$suite" --argjson produces "$PRODUCES" \
        '. += [{product: $product, suite: $suite, produces: $produces}]' <<< "$TARGETS")
      PLATFORM_SET=$(jq -c --arg platform "$platform" '. + [$platform] | unique' <<< "$PLATFORM_SET")
    done < <(matrix_product_suites "$product")
  done < <(pkg_products "$PKG")

  [[ "$(jq length <<< "$TARGETS")" -eq 0 ]] && { info "Skip: ${PKG} has no matching active targets"; continue; }
  MATRIX_INCLUDES='[]'
  while IFS= read -r platform; do
    BASE=$(matrix_base_image "$platform"); SUITE=$(matrix_suite "$platform")
    while IFS= read -r arch; do
      MATRIX_INCLUDES=$(jq -c --arg p "$platform" --arg b "$BASE" --arg s "$SUITE" --arg a "$arch" \
        '. += [{platform: $p, base: $b, suite: $s, arch: $a}]' <<< "$MATRIX_INCLUDES")
      FLAT_MATRIX=$(jq -c --arg pkg "$PKG" --arg p "$platform" --arg b "$BASE" --arg s "$SUITE" --arg a "$arch" \
        '. += [{package: $pkg, platform: $p, base: $b, suite: $s, arch: $a}]' <<< "$FLAT_MATRIX")
    done < <(matrix_arches "$platform")
  done < <(jq -r '.[]' <<< "$PLATFORM_SET")

  STABLE_RELEASE=$(yq e ".${PKG}.stable_release // false" versions.yml)
  PKG_CHANNEL=dev; [[ "$STABLE_RELEASE" == true ]] && PKG_CHANNEL=stable
  ENTRY=$(jq -cn --arg package "$PKG" --arg version "$VERSION" --arg depends_on "$DEPENDS" \
    --arg channel "$PKG_CHANNEL" --argjson targets "$TARGETS" --argjson matrix "{\"include\":$MATRIX_INCLUDES}" \
    '{package:$package,version:$version,depends_on:$depends_on,channel:$channel,targets:$targets,matrix:$matrix}')
  BUILDS=$(jq -c --argjson entry "$ENTRY" '. += [$entry]' <<< "$BUILDS")
  info "Queued: ${PKG} ${VERSION} ($(jq -r '[.[] | "\(.product)/\(.suite)"] | join(", ")' <<< "$TARGETS"))"
done

_output builds "$(jq -c . <<< "$BUILDS")"
_output build_matrix "$(jq -cn --argjson include "$FLAT_MATRIX" '{include:$include}')"
