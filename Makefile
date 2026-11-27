.PHONY: build test lint coverage import lorespire update app dmg appstore run install ipad-install ipad-simulator ipad-archive icon ipad-uitests clean

build:
	swift build

test:
	swift test

lint:
	swiftlint --strict --quiet

# Runs the tests and fails when the coverage of FieldGuideKit, CompendiumImport and LorespireImport is below 80%.
coverage:
	scripts/coverage.sh

# Imports both systems from the pf2e release in pf2e.release into Generated/ (see scripts/import.sh for the
# sources).
import:
	scripts/import.sh

# Downloads the Organized Play guides from Lorespire into build/lorespire; `make import` does it too.
lorespire:
	scripts/fetch-lorespire.sh

# Switches to pf2e's newest release, imports and installs on the iPad.
update:
	scripts/update.sh

# Builds "build/Field Guide.app" with Generated/ inside, and its disk image build/Field-Guide-<VERSION>.dmg.
app:
	scripts/build-app.sh

dmg: app
	scripts/make-dmg.sh

# Builds the Mac App Store package, build/appstore/Field Guide.pkg (see scripts/build-app.sh for the variables).
appstore:
	swift package resolve
	CHANNEL=appstore scripts/build-app.sh

# Runs the Mac build against Generated/.
run:
	swift run FieldGuide

# Moves the built app into /Applications, replacing an earlier copy. The build copy is unregistered and
# removed so Finder and Spotlight launch the installed one.
LSREGISTER = /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
install: app
	rm -rf "/Applications/Field Guide.app"
	ditto "build/Field Guide.app" "/Applications/Field Guide.app"
	-$(LSREGISTER) -u "build/Field Guide.app" 2>/dev/null  # Fails when it was never registered, which is fine.
	rm -rf "build/Field Guide.app"

# Builds the iPad app and installs it on a connected iPad. IPAD names the iPad.
ipad-install:
	scripts/install-ipad.sh

ipad-simulator:
	scripts/run-ipad-simulator.sh

# Runs the iPad UI tests in a simulator, against Generated/. ONLY="GlobalSearchUITests ..." runs just those.
ipad-uitests:
	scripts/run-ipad-uitests.sh

# Redraws the app icon from scripts/make-icon.swift.
icon:
	swift scripts/make-icon.swift ios/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png

# Archives the app for the App Store and exports build/ipad/export/*.ipa, versioned from git. Upload it with
# `make testflight`.
.PHONY: ipad-archive testflight
ipad-archive:
	scripts/check-generated.sh "Archiving"
	.build/checkouts/tabletop-kit/scripts/archive-ios.sh ios/FieldGuide.xcodeproj FieldGuide-iPad build/ipad

# Uploads the newest build (the .ipa from ipad-archive or the .pkg from appstore) to TestFlight, with this release's
# notes from the tableside-store checkout next to this repository (TABLESIDE_STORE).
TABLESIDE_STORE ?= ../tableside-store
TESTFLIGHT_NOTES = $(TABLESIDE_STORE)/field-guide/testflight/what-to-test.txt
TESTFLIGHT_BUILD ?= $(shell ls -t build/ipad/export/*.ipa build/appstore/*.pkg 2>/dev/null | head -n 1)
testflight:
	@test -f "$(TESTFLIGHT_NOTES)" || { echo "testflight failed: $(TESTFLIGHT_NOTES) not found; set TABLESIDE_STORE"; exit 1; }
	@test -n "$(TESTFLIGHT_BUILD)" || { echo "testflight failed: no build; run make ipad-archive or make appstore"; exit 1; }
	.build/checkouts/tabletop-kit/scripts/testflight.sh io.github.scooper4711.FieldGuide "$(TESTFLIGHT_BUILD)" "$(TESTFLIGHT_NOTES)"

clean:
	rm -rf .build build coverage ios/build
