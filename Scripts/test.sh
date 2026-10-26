#!/usr/bin/env bash
#
# Runs the suite.
#
# The macro plugin behind #expect ships with the toolchain, but SPM does not
# pass it through under explicit module builds, so the path is supplied here.
# It is derived from whichever toolchain xcrun resolves, which keeps this
# working on Command Line Tools and on a full Xcode alike.
set -euo pipefail

plugins="$(dirname "$(xcrun -f swiftc)")/../lib/swift/host/plugins/testing"

if [[ ! -d "$plugins" ]]; then
    echo "error: testing macro plugin not found at ${plugins}" >&2
    exit 1
fi

exec swift test -Xswiftc -plugin-path -Xswiftc "$plugins" "$@"
