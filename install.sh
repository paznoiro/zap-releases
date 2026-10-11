#!/bin/sh
# zap installer — bootstraps uv (if needed) and installs zap / zc / zs / zd / zr / zb / zbd.
#
# Default one-liner (installs the latest release from the public mirror):
#   curl -LsSf https://raw.githubusercontent.com/paznoiro/zap-releases/main/install.sh | sh
#
# Pin a release version:
#   ZAP_VERSION=0.1.0 curl -LsSf https://raw.githubusercontent.com/paznoiro/zap-releases/main/install.sh | sh
#
# Install from the private repo's GitHub Releases instead (needs `gh` auth:
# run `gh auth login` first):
#   ZAP_SOURCE=github ZAP_REPO=zaporion/zap-cli curl -LsSf .../install.sh | sh
#
# Install from git instead of a release:
#   ZAP_SOURCE=git curl -LsSf .../install.sh | sh
#
# Install from PyPI instead of a release:
#   ZAP_SOURCE=zap-deploy curl -LsSf .../install.sh | sh
#
# Environment:
#   ZAP_SOURCE    s3 (default: public file mirror) | github | git | <pypi-package-name>
#   ZAP_S3_URL    public base URL of the file mirror (LATEST_VERSION,
#                 wheel + SHA256SUMS live there; any static HTTPS host works)
#   ZAP_VERSION   X.Y.Z release to install (default: latest from LATEST_VERSION)
#   ZAP_REPO      owner/repo for github/git-source installs

set -eu

ZAP_SOURCE="${ZAP_SOURCE:-s3}"

# Public base URL of the binary mirror (paznoiro/zap-releases served over
# raw.githubusercontent.com; pushed by .github/workflows/release.yml).
ZAP_S3_URL="${ZAP_S3_URL:-https://raw.githubusercontent.com/paznoiro/zap-releases/main}"
ZAP_REPO="${ZAP_REPO:-zaporion/zap-cli}"
ZAP_VERSION="${ZAP_VERSION:-}"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
TMP_DIR="${TMPDIR:-/tmp}"

err() { echo "ERROR: $*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || err "curl is required to install zap"

# 1. ensure uv is available
if ! command -v uv >/dev/null 2>&1; then
  echo "==> Installing uv (Python package runner)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$BIN_DIR:$PATH"
command -v uv >/dev/null 2>&1 || err "uv was installed but is not on PATH; reopen your shell and re-run this script."

# 2. resolve the install target
verify_checksums() {
  if command -v sha256sum >/dev/null 2>&1; then
    ( cd "$TMP_DIR" && sha256sum -c "$(basename "$sha_file")" 2>/dev/null | grep -q "zap_deploy-$ZAP_VERSION-py3-none-any.whl: OK" )
  elif command -v shasum >/dev/null 2>&1; then
    ( cd "$TMP_DIR" && shasum -a 256 -c "$(basename "$sha_file")" 2>/dev/null | grep -q "zap_deploy-$ZAP_VERSION-py3-none-any.whl: OK" )
  else
    err "sha256sum (Linux) or shasum (macOS) is required to verify the download"
  fi
}

case "$ZAP_SOURCE" in
  github)
    base="https://github.com/$ZAP_REPO/releases"
    if [ -z "$ZAP_VERSION" ]; then
      if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        echo "==> Resolving latest release for $ZAP_REPO via gh"
        ZAP_VERSION="$(gh release view --repo "$ZAP_REPO" --json tagName -q .tagName 2>/dev/null || true)"
        ZAP_VERSION="${ZAP_VERSION#v}"
      else
        echo "==> Resolving latest release from $base/latest"
        ZAP_VERSION="$(curl -fsSL -o /dev/null -w '%{url_effective}' "$base/latest" \
          | sed -n 's|.*/releases/tag/v\{0,1\}\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)$|\1|p' || true)"
      fi
      [ -n "$ZAP_VERSION" ] || err "could not resolve the latest release for $ZAP_REPO"
      echo "==> Latest release: v$ZAP_VERSION"
    fi
    case "$ZAP_VERSION" in
      [0-9]*.[0-9]*.[0-9]*) ;;
      *) err "ZAP_VERSION must be X.Y.Z (got '$ZAP_VERSION')" ;;
    esac
    wheel="$TMP_DIR/zap_deploy-$ZAP_VERSION-py3-none-any.whl"
    sha_file="$TMP_DIR/SHA256SUMS"
    trap 'rm -f "$wheel" "$sha_file"' EXIT
    echo "==> Downloading zap $ZAP_VERSION from $base/download/v$ZAP_VERSION"
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
      gh release download "v$ZAP_VERSION" --repo "$ZAP_REPO" \
        --pattern "zap_deploy-$ZAP_VERSION-py3-none-any.whl" --dir "$TMP_DIR" --clobber
      gh release download "v$ZAP_VERSION" --repo "$ZAP_REPO" \
        --pattern "SHA256SUMS" --dir "$TMP_DIR" --clobber
    else
      curl -fsSL -o "$wheel" "$base/download/v$ZAP_VERSION/zap_deploy-$ZAP_VERSION-py3-none-any.whl"
      curl -fsSL -o "$sha_file" "$base/download/v$ZAP_VERSION/SHA256SUMS"
    fi
    verify_checksums \
      || err "SHA256 checksum mismatch for $wheel — download may be corrupted"
    echo "==> Installing zap: $wheel (checksum verified)"
    uv tool install --force "$wheel"
    ;;
  s3)
    case "$ZAP_S3_URL" in
      *YOUR-S3-PUBLIC-URL*|"") err "ZAP_S3_URL is not set — edit the default in install.sh or export it, e.g.:
  export ZAP_S3_URL=https://s3.us-east-1.amazonaws.com/zap-releases/zap-deploy
(any S3-compatible public URL works; or use ZAP_SOURCE=git to install from git)" ;;
    esac
    if [ -z "$ZAP_VERSION" ]; then
      echo "==> Resolving latest version from $ZAP_S3_URL/LATEST_VERSION"
      ZAP_VERSION="$(curl -fsSL "$ZAP_S3_URL/LATEST_VERSION" | tr -d '[:space:]' || true)"
      [ -n "$ZAP_VERSION" ] || err "could not read LATEST_VERSION from $ZAP_S3_URL"
    fi
    case "$ZAP_VERSION" in
      [0-9]*.[0-9]*.[0-9]*) ;;
      *) err "ZAP_VERSION must be X.Y.Z (got '$ZAP_VERSION')" ;;
    esac
    wheel="$TMP_DIR/zap_deploy-$ZAP_VERSION-py3-none-any.whl"
    sha_file="$TMP_DIR/zap_deploy-$ZAP_VERSION.SHA256SUMS"
    trap 'rm -f "$wheel" "$sha_file"' EXIT
    echo "==> Downloading zap $ZAP_VERSION from $ZAP_S3_URL"
    curl -fsSL -o "$wheel" "$ZAP_S3_URL/zap_deploy-$ZAP_VERSION-py3-none-any.whl"
    curl -fsSL -o "$sha_file" "$ZAP_S3_URL/SHA256SUMS"
    verify_checksums \
      || err "SHA256 checksum mismatch for $wheel — download may be corrupted"
    echo "==> Installing zap: $wheel (checksum verified)"
    uv tool install --force "$wheel"
    ;;
  git)
    ref="git+https://github.com/${ZAP_REPO}.git"
    [ -n "$ZAP_VERSION" ] && ref="${ref}@v${ZAP_VERSION#v}"
    echo "==> Installing zap: $ref"
    uv tool install --force "$ref"
    ;;
  *)
    ref="$ZAP_SOURCE"
    [ -n "$ZAP_VERSION" ] && ref="${ZAP_SOURCE}==${ZAP_VERSION#v}"
    echo "==> Installing zap: $ref"
    uv tool install --force "$ref"
    ;;
esac

# 3. make sure $BIN_DIR is on PATH for future shells (idempotent)
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    export PATH="$BIN_DIR:$PATH"
    for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
      [ -f "$rc" ] || continue
      grep -q '\.local/bin\|XDG_BIN_HOME' "$rc" 2>/dev/null || \
        printf '\n# Added by the zap installer\nexport PATH="%s:$PATH"\n' "$BIN_DIR" >>"$rc"
    done
    ;;
esac

echo
echo "==> Installed: zap, zc, zs, zd, zr, zb, zbd"
"$BIN_DIR/zap" version 2>/dev/null || true
echo
echo "If 'zap' is not found in this shell, run:"
echo "  export PATH=\"$BIN_DIR:\$PATH\""
echo "or open a new terminal."
echo
echo "Runtime dependencies (install separately, per command you use):"
echo "  zd (deploy)  -> ssh, scp, docker  (+ doppler if configured)"
echo "  zr (release) -> git, gh (GitHub CLI)"
echo "  zb (build)   -> docker (+ the project's toolchain: gradle/mvn wrapper, go, npm)"
echo "  zbd (build+deploy) -> same as zb + zd combined"
echo "  zc (clean)   -> nothing extra (psycopg is bundled; pg_dump optional for multi-schema backups)"
echo "  zs (seed)    -> java (native Liquibase port; CLI auto-downloaded on first run)"
