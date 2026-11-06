#!/bin/sh
# Builds "build/Field Guide.app" from the Swift package, with Generated/ (make import) inside.
#
# VERSION       version written to the bundle (default: scripts/version.sh marketing)
# BUILD_NUMBER  build number, which must grow with every App Store upload (default: scripts/version.sh build)
# UNIVERSAL  set to 1 to build for both Apple silicon and Intel
# TEAM_ID    team whose Tableside Toolkit App Group the app joins, to read Scrollkeeper's downloads (default: the
#            team of the Developer ID certificate in the keychain; none when signing ad hoc)
set -eu

cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(scripts/version.sh marketing)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(scripts/version.sh build)}"
APP="build/Field Guide.app"
EXECUTABLE="FieldGuide"

[ -f Generated/catalog.sqlite ] || { echo "Building the app failed: Generated/ is missing; run \"make import\" first." >&2; exit 1; }

if [ "${UNIVERSAL:-0}" = "1" ]; then
    swift build -c release --arch arm64 --arch x86_64 --product "$EXECUTABLE"
    # Asked rather than assumed: newer SwiftPM moved universal builds out of .build/apple, and a copy left
    # there by an older toolchain would otherwise be bundled instead.
    BINARY="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$EXECUTABLE"
else
    swift build -c release --product "$EXECUTABLE"
    BINARY="$(swift build -c release --show-bin-path)/$EXECUTABLE"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$EXECUTABLE"
# The SwiftPM resource bundles (the entry page's stylesheet and scripts) sit next to the executable.
for bundle in "$(dirname "$BINARY")"/*.bundle; do
    [ -d "$bundle" ] && ditto "$bundle" "$APP/Contents/Resources/$(basename "$bundle")"
done
# The iPad's icon, as a Mac icon.
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" ios/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png \
        --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" ios/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png \
        --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"
# The imported compendium (see "make import"), bundled as a folder like on the iPad.
ditto Generated "$APP/Contents/Resources/Generated"
# Moves the data an unsandboxed version kept into the sandbox on the first sandboxed launch.
cp Resources/container-migration.plist "$APP/Contents/Resources/"
# The privacy manifest the App Store requires, shared with the iPad app.
cp ios/App/PrivacyInfo.xcprivacy "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Field Guide</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>io.github.scooper4711.FieldGuide</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Field Guide</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <!-- A rules reference, so App Review judges it as one rather than as a game. -->
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.reference</string>
    <!-- Only the system's HTTPS, which is exempt, so uploads don't ask about export compliance. -->
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Stephen Cooper</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <!-- Scrollkeeper hands Field Guide the sourcebooks the user asks for, its list of titles, and how a request is going
         (fieldguide://). -->
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>PDF Document</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array><string>com.adobe.pdf</string></array>
        </dict>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Scrollkeeper Library List</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array><string>io.github.scooper4711.scrollkeeper.index</string></array>
        </dict>
    </array>
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>io.github.scooper4711.scrollkeeper.index</string>
            <key>UTTypeDescription</key>
            <string>Scrollkeeper Library List</string>
            <key>UTTypeConformsTo</key>
            <array><string>public.json</string></array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array><string>scrollkeeperindex</string></array>
            </dict>
        </dict>
    </array>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>io.github.scooper4711.FieldGuide.handoff</string>
            <key>CFBundleURLSchemes</key>
            <array><string>fieldguide</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# The entitlements turn on the App Sandbox. A build signed by the team also joins the Tableside Toolkit's App Group,
# whose folder holds Scrollkeeper's downloads; an ad hoc signature can't, so it leaves the group out.
[ "${SIGNING_IDENTITY:-}" = "-" ] && TEAM_ID="${TEAM_ID:-none}"
TEAM_ID="${TEAM_ID:-$(security find-identity -v -p codesigning \
    | sed -n 's/.*"Developer ID Application: .*(\([A-Z0-9]*\))"$/\1/p' | head -n 1)}"
ENTITLEMENTS="build/FieldGuide.entitlements"
cp Resources/FieldGuide.entitlements "$ENTITLEMENTS"
if [ -n "$TEAM_ID" ] && [ "$TEAM_ID" != "none" ]; then
    GROUP="$TEAM_ID.io.github.scooper4711.tableside"
    /usr/libexec/PlistBuddy -c "Add :com.apple.security.application-groups array" \
        -c "Add :com.apple.security.application-groups:0 string $GROUP" "$ENTITLEMENTS"
    plutil -insert TablesideAppGroup -string "$GROUP" "$APP/Contents/Info.plist"
fi
scripts/sign-app.sh "$APP" "$ENTITLEMENTS"
echo "Built $APP ($VERSION, build $BUILD_NUMBER)"
