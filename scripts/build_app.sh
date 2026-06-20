#!/bin/bash

# Configuration
APP_NAME="DiscoverPlatform"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Building $APP_NAME..."

# 1. Create directory structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 2. Compile Swift file
echo "Compiling Discover.swift..."
swiftc -O -parse-as-library native-app/Discover.swift -o "$MACOS_DIR/Discover"

# Check if compile succeeded
if [ $? -ne 0 ]; then
    echo "Compilation failed!"
    exit 1
fi

# 3. Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Discover</string>
    <key>CFBundleIdentifier</key>
    <string>com.newsproject.discoverplatform</string>
    <key>CFBundleName</key>
    <string>DiscoverPlatform</string>
    <key>CFBundleDisplayName</key>
    <string>Discover</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key>
        <true/>
    </dict>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
EOF

# 4. Generate AppIcon.icns
echo "Generating AppIcon.icns..."
ICON_PNG="discover_app_icon.png"
if [ -f "$ICON_PNG" ]; then
    mkdir -p AppIcon.iconset
    sips -s format png -z 16 16     "$ICON_PNG" --out AppIcon.iconset/icon_16x16.png >/dev/null 2>&1
    sips -s format png -z 32 32     "$ICON_PNG" --out AppIcon.iconset/icon_16x16@2x.png >/dev/null 2>&1
    sips -s format png -z 32 32     "$ICON_PNG" --out AppIcon.iconset/icon_32x32.png >/dev/null 2>&1
    sips -s format png -z 64 64     "$ICON_PNG" --out AppIcon.iconset/icon_32x32@2x.png >/dev/null 2>&1
    sips -s format png -z 128 128   "$ICON_PNG" --out AppIcon.iconset/icon_128x128.png >/dev/null 2>&1
    sips -s format png -z 256 256   "$ICON_PNG" --out AppIcon.iconset/icon_128x128@2x.png >/dev/null 2>&1
    sips -s format png -z 256 256   "$ICON_PNG" --out AppIcon.iconset/icon_256x256.png >/dev/null 2>&1
    sips -s format png -z 512 512   "$ICON_PNG" --out AppIcon.iconset/icon_256x256@2x.png >/dev/null 2>&1
    sips -s format png -z 512 512   "$ICON_PNG" --out AppIcon.iconset/icon_512x512.png >/dev/null 2>&1
    iconutil -c icns AppIcon.iconset -o "$RESOURCES_DIR/AppIcon.icns"
    rm -rf AppIcon.iconset
    echo "App Icon compiled into Resources."
else
    echo "discover_app_icon.png not found. Skipping icon generation."
fi

echo "App bundle created successfully at $APP_DIR"
