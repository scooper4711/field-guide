.PHONY: build test lint coverage import update app dmg appstore run ipad-install ipad-simulator ipad-archive icon clean

build:
	swift build

test:
	swift test

lint:
	swiftlint --strict --quiet

# Runs the tests and fails when FieldGuideKit's and CompendiumImport's coverage is below 80%.
coverage:
	scripts/coverage.sh

# Imports both systems from the pf2e release in pf2e.release into Generated/ (see scripts/import.sh for the
# sources).
import:
	scripts/import.sh

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

# Builds the iPad app and installs it on a connected iPad. IPAD names the iPad.
ipad-install:
	scripts/install-ipad.sh

ipad-simulator:
	scripts/run-ipad-simulator.sh

# Archives the iPad app for the App Store into build/FieldGuide.xcarchive, versioned from git.
ipad-archive:
	scripts/archive-ipad.sh

# Redraws the app icon from scripts/make-icon.swift.
icon:
	swift scripts/make-icon.swift ios/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png

clean:
	rm -rf .build build coverage ios/build
