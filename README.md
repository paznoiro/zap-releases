# zap-releases

Public binary mirror for the [`zap` CLI](https://github.com/zaporion/zap-cli)
(`zap`, `zc`, `zs`, `zd`, `zr`, `zb`, `zbd`).

Updated automatically by the release workflow on every `vX.Y.Z` tag — **do
not edit by hand**. Only binaries live here (no source archives):

```
install.sh                            # installer one-liner entry point
uninstall.sh                          # uninstaller
zap_deploy-<ver>-py3-none-any.whl     # the versioned wheel (binary)
SHA256SUMS                            # checksums (installer verifies)
LATEST_VERSION                        # bare "X.Y.Z" for unpinned installs
```

Install the latest release:

```bash
curl -LsSf https://raw.githubusercontent.com/paznoiro/zap-releases/main/install.sh | sh
```
