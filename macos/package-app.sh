#!/bin/bash
# Package LCTMac as a proper .app bundle.
# Running the bare SPM executable makes TCC attribute permission requests to the
# launching app (Terminal/Claude/etc.), which crashes with SIGABRT when that app
# lacks the usage descriptions. A real bundle owns its own TCC identity.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN_PATH=$(swift build -c release --show-bin-path)

APP=LCTMac.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/LCTMac" "$APP/Contents/MacOS/LCTMac"
cp LCTMac/Info.plist "$APP/Contents/Info.plist"
cp LCTMac/Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Stamp version from the manually maintained VERSION file (or RELEASE_VERSION
# env var) plus integer BUILD_NUMBER, so builds are distinguishable.
RELEASE_VERSION="${RELEASE_VERSION:-$(tr -d '[:space:]' < VERSION)}"
BUILD_NUMBER="${BUILD_NUMBER:-0}"
Scripts/version-stamp.sh "$APP/Contents/Info.plist"

# Sign with a stable local identity if one exists, so macOS TCC permissions
# (screen recording, microphone, speech) survive rebuilds instead of being
# invalidated every time — ad-hoc signatures change on each build, which forces
# re-authorization. Create the dev identity once with: ./scripts/dev-cert.sh
# Falls back to ad-hoc on CI / machines without the cert.
SIGN_IDENTITY="${LCT_SIGN_IDENTITY:-LCT Dev}"
if security find-identity -p codesigning 2>/dev/null | grep -q "$SIGN_IDENTITY"; then
    codesign --force --sign "$SIGN_IDENTITY" "$APP"
    echo "Packaged $APP $RELEASE_VERSION ($BUILD_NUMBER), signed as '$SIGN_IDENTITY' — launch with: open $APP"
else
    codesign --force --sign - "$APP"
    echo "Packaged $APP $RELEASE_VERSION ($BUILD_NUMBER), ad-hoc signed — launch with: open $APP"
fi
