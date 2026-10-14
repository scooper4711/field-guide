.PHONY: build test lint coverage import update app dmg run ipad-install ipad-simulator icon clean

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

# Switches to pf2e's newest release, imports and installs on the iPad. GitHub switches weekly too.
update:
	scripts/update.sh

# Builds "build/Field Guide.app" with Generated/ inside, and its disk image build/Field-Guide-<VERSION>.dmg.
app:
	scripts/build-app.sh

dmg: app
	scripts/make-dmg.sh

# Runs the Mac build against Generated/.
run:
	swift run FieldGuide

# Builds the iPad app and installs it on a connected iPad. IPAD names the iPad.
ipad-install:
	scripts/install-ipad.sh

ipad-simulator:
	scripts/run-ipad-simulator.sh

# Redraws the app icon from scripts/make-icon.swift.
icon:
	swift scripts/make-icon.swift ios/App/Assets.xcassets/AppIcon.appiconset/icon-1024.png

clean:
	rm -rf .build build coverage ios/build
