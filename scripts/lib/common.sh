#!/usr/bin/env bash
# lib/common.sh — Shared shell functions. Source this; do not execute.

set -euo pipefail
if [[ -t 1 ]]; then
  _C_RED=$'\033[1;31m' _C_YEL=$'\033[1;33m' _C_CYN=$'\033[1;36m'
  _C_GRN=$'\033[1;32m' _C_RST=$'\033[0m'
else
  _C_RED="" _C_YEL="" _C_CYN="" _C_GRN="" _C_RST=""
fi

die()  { echo "${_C_RED}ERROR:${_C_RST} $*" >&2; exit 1; }
warn() { echo "${_C_YEL}WARN:${_C_RST} $*" >&2; }
info() { echo "${_C_CYN}==>  ${_C_RST}$*"; }
step() { echo "${_C_GRN}───  ${_C_RST}$*"; }

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${_LIB_DIR}/../.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/scripts"

repo_root()   { echo "$REPO_ROOT"; }
scripts_dir() { echo "$SCRIPTS_DIR"; }

# Parse shared build flags.
# shellcheck disable=SC2034
parse_pkg_args() {
  local self="$1"; shift
  PKG=""; PLATFORM=""; DISTRO=""; ARCH="amd64"; OUTPUT_DIR_OVERRIDE=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --platform)   PLATFORM="$2";            shift 2 ;;
      --distro)     PLATFORM="$2";            shift 2 ;; # Deprecated.
      --arch)       ARCH="$2";                shift 2 ;;
      --output-dir) OUTPUT_DIR_OVERRIDE="$2"; shift 2 ;;
      --help|-h)    sed -n '2,/^$/{ s/^# //; s/^#$//; p }' "$self"; exit 0 ;;
      -*)           die "unknown flag: $1" ;;
      *)            PKG="$1"; shift ;;
    esac
  done
  DISTRO="$PLATFORM" # Deprecated compatibility variable.
  [[ -n "$PKG" ]] || die "Usage: $(basename "$self") <package> [--platform <platform>] [--arch <arch>] [--output-dir <dir>]"
}

require_cmd() {
  local missing=()
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required commands: ${missing[*]}"
  fi
}
