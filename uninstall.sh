#!/bin/sh
# zap uninstaller — removes zap / zc / zs / zd / zr / zb / zbd installed via install.sh.
#
# One-liner:
#   curl -LsSf https://raw.githubusercontent.com/zaporion/zap-cli/main/uninstall.sh | sh

set -eu

BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
MARK="# Added by the zap installer"

echo "==> Uninstalling zap-deploy (zap, zc, zs, zd, zr, zb, zbd)"

if command -v uv >/dev/null 2>&1; then
  uv tool uninstall zap-deploy 2>/dev/null \
    || echo "==> zap-deploy is not installed with uv — nothing to uninstall."
else
  echo "==> uv not found — skipping managed uninstall."
fi

rm -f "$BIN_DIR/zap" "$BIN_DIR/zc" "$BIN_DIR/zs" "$BIN_DIR/zd" "$BIN_DIR/zr" "$BIN_DIR/zb" "$BIN_DIR/zbd"

for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
  [ -f "$rc" ] || continue
  if grep -q "$MARK" "$rc" 2>/dev/null; then
    grep -v "$MARK" "$rc" > "$rc.tmp"
    mv "$rc.tmp" "$rc"
    echo "==> Removed the installer PATH line from $rc"
  fi
done

echo "==> zap-deploy uninstalled."
