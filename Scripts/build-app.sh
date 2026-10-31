#!/usr/bin/env bash
#
# Assembles dist/Pod.app from a build.
#
# Pod has no Xcode project, so the bundle is laid out by hand. The result is
# ad-hoc signed only: it runs locally, and real signing and notarisation are
# left to whoever ships it.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

configuration="${1:-release}"
app="dist/Pod.app"

swift build -c "$configuration"

binary="$(swift build -c "$configuration" --show-bin-path)/Pod"
if [[ ! -x "$binary" ]]; then
    echo "error: no executable at ${binary}" >&2
    exit 1
fi

rm -rf "$app"
mkdir -p "${app}/Contents/MacOS" "${app}/Contents/Resources"

cp "$binary" "${app}/Contents/MacOS/Pod"
cp Resources/Info.plist "${app}/Contents/Info.plist"
printf 'APPL????' > "${app}/Contents/PkgInfo"

# Ad-hoc signature, so the panel can take key focus without Gatekeeper
# prompting again on every rebuild.
if ! codesign --force --sign - "$app" 2>/dev/null; then
    echo "warning: ad-hoc signing failed; the app will still run" >&2
fi

echo "built ${app}"
