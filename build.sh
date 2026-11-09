#!/bin/bash
# Build "OpenToasters.saver" from sources + the original
# AfterDark sprite assets (personal-use copy from the installed AfterDark
# "Flying Toasters 1.2.saver").
set -euo pipefail
cd "$(dirname "$0")"

BUNDLE="OpenToasters.saver"
EXECUTABLE="OpenToasters"
BUNDLE_ID="com.opentoasters.saver"

# Args: optional asset directory; --no-assets builds an assetless bundle
# (used in CI, where the copyrighted sprite assets do not exist).
NO_ASSETS=0
ASSET_SRC=""
for arg in "$@"; do
    case "$arg" in
        --no-assets) NO_ASSETS=1 ;;
        *)           ASSET_SRC="$arg" ;;
    esac
done
if [ -z "$ASSET_SRC" ]; then
    ASSET_SRC="$HOME/Library/Screen Savers/Flying Toasters 1.2.saver/Contents/Resources"
fi

if [ "$NO_ASSETS" -ne 1 ] && [ ! -d "$ASSET_SRC" ]; then
    echo "error: asset directory not found: $ASSET_SRC" >&2
    exit 1
fi

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

echo "compiling..."
clang -O2 -fobjc-arc -mmacosx-version-min=11.0 -Wall -Wno-deprecated-declarations \
    -framework AppKit -framework ScreenSaver -framework CoreGraphics -framework QuartzCore \
    -bundle -undefined dynamic_lookup \
    Sources/OpenToastersView.m \
    -o "$BUNDLE/Contents/MacOS/$EXECUTABLE"

if [ "$NO_ASSETS" -eq 1 ]; then
    echo "building without sprite assets (--no-assets)"
    ASSET_COUNT=0
else
    echo "copying assets from: $ASSET_SRC"
    cp "$ASSET_SRC"/*.png "$BUNDLE/Contents/Resources/"
    ASSET_COUNT=$(ls "$BUNDLE/Contents/Resources"/*.png | wc -l | tr -d ' ')
    echo "assets copied: $ASSET_COUNT"
fi

cat > "$BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OpenToasters</string>
    <key>CFBundlePackageType</key>
    <string>BNDL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0</string>
    <key>CFBundleVersion</key>
    <string>2.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSPrincipalClass</key>
    <string>OpenToastersView</string>
    <key>NSHumanReadableCopyright</key>
    <string>Rebuilt for personal use. Sprite assets from AfterDark Flying Toasters (c) Infinisy / Stardock.</string>
</dict>
</plist>
EOF

# clean Finder detritus before signing
find "$BUNDLE" -name ".DS_Store" -delete
xattr -cr "$BUNDLE" 2>/dev/null || true

codesign --force --sign - "$BUNDLE"

echo "building preview harness..."
clang -O2 -fobjc-arc -mmacosx-version-min=11.0 -Wall -Wno-deprecated-declarations \
    -framework AppKit -framework ScreenSaver -lproc \
    Sources/preview.m -o preview

echo "done: $BUNDLE"
