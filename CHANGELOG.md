# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Custom creatures from the shared libraries appear in the Bestiary and Hazards with their stat blocks
- Art chosen in Turnkeeper or Pawn Shop shows on cards and thumbnails
- Art pictures whose PDF is on another device download from iCloud when shown, and Sourcebooks has the shared sync
  settings
- Entries from outside the catalog are listed with its own, and found by Search Everything
- Organized Play: the Pathfinder Society and Starfinder Society guides and the Venture-Officer Handbook from
  Lorespire, readable offline, one page per entry in guide order, with links between them that open at the
  heading they point at

### Changed
- Entries without an icon of their own show a fitting one instead of their category's symbol: an item takes the
  icon of items like it, by its traits too, so a potion shows a bottle, and each category has an icon for the rest
- The GM Screen list is grouped under its sections: Playing the Game, Running the Game and the others
- Links that open a web page or mail end in an arrow (↗); links to other pages of the Field Guide don't
- A link to another entry opens it in a popover beside the link. Open shows the entry in its category's list, and
  Back returns to where you were, as in a browser

### Fixed
- On a new install, an iPad in portrait shows the categories instead of hiding them

## [2.0.1] - 2026-11-21

### Fixed
- Read PDF lines without their pictures' text attachments
- Use tabletop-kit's shared application launcher
- Show the About screen from the iPad's menu bar

### Changed
- Require tabletop-kit 1.12.0
- Update tabletop-kit to 1.11.4
- Time out CI jobs instead of waiting 6 hours
- Require tabletop-kit 1.11.3
- Require tabletop-kit 1.11.2
- Pin the GitHub actions to commit hashes
- Run the tests on the self-hosted Mac mini
- Require tabletop-kit 1.11.1
- Require tabletop-kit 1.11.0
- Require tabletop-kit 1.10.0
- Require tabletop-kit 1.9.0
- Require tabletop-kit 1.8.1
- Require tabletop-kit 1.8.0
- Require tabletop-kit 1.7.0
- Run the tests on the macOS 26 runner again
- Require tabletop-kit 1.6.0
- Require tabletop-kit 1.5.0
- Require tabletop-kit 1.4.1
- Run the tests on GitHub's macOS 27 runner
- Check for picture characters in the test body, not a trait
- Run the picture test only where PDFKit reads pictures as characters
- Require tabletop-kit 1.4.0
- Drop the AI disclosure rule from CONTRIBUTING
- Specify About in the iPad's menu bar

[2.0.1]: https://github.com/scooper4711/field-guide/releases/tag/v2.0.1

## [2.0.0] - 2026-11-13

### Added
- Hide the sample sourcebooks once a book of your own is processed
- Know the user's Scrollkeeper titles from its shared library list
- Add a Starfinder sample sourcebook and mark the samples' lore
- Filter sourcebooks to those owned in Scrollkeeper but not downloaded
- Say processed for sourcebooks, and filter the list by it
- Read Scrollkeeper's App Group folder on iOS
- Move the Journals pages where they belong
- Remove the Remaster Changes section
- Illustrate the sample sourcebook's creatures
- Build Field Guide for the Mac App Store

### Fixed
- Hang stat block wrapped lines and embed action icons
- Drop the alpha channel from the iOS App Store icon
- Refuse to build with an out-of-date Generated/
- Show the entry count above the list on iOS
- Open Device Hub after starting the iPad simulator
- Show every column on the iPad while no entry is chosen
- Keep the battle card's text its size on a phone

### Changed
- Update the Artwork submodule
- Stop the weekly pf2e update
- Save the icon matches for pf2e 8.7.0 and sf2e 1.7.0
- Look for the skipped journal in the fake repository's folder
- Allow Community Use art and ORC rules text in the demo files
- Say what deleting the app leaves on a Mac
- Rewrap the review notes line
- Say where the review notes live

[2.0.0]: https://github.com/scooper4711/field-guide/releases/tag/v2.0.0

## [1.2.0] - 2026-10-20

### Added
- Run Field Guide on the iPhone

### Fixed
- Open the sidebar for Search Everything on the iPad
- Start the iPhone on the categories

[1.2.0]: https://github.com/scooper4711/field-guide/releases/tag/v1.2.0

## [1.1.2] - 2026-10-20

### Added
- Run the Mac app in the App Sandbox

### Fixed
- Keep the game picker's size steady under the pointer
- Restore missing PDFs by picking their folder again
- Bundle the universal binary from where SwiftPM built it

### Changed
- Run the weekly pf2e update off the hour
- Specify the Mac app in the App Sandbox
- Watch every pf2e file the import reads
- Gate releases on the coverage check, as CI does

[1.1.2]: https://github.com/scooper4711/field-guide/releases/tag/v1.1.2

## [1.1.1] - 2026-10-15

### Fixed
- Find cwebp on PATH before Homebrew's folders

[1.1.1]: https://github.com/scooper4711/field-guide/releases/tag/v1.1.1

## [1.1.0] - 2026-10-15

### Added
- Add the Mac's Go menu, Art from PDFs command and window size
- List the bundled licenses on the About screen
- Bundle the license texts the app's content requires

### Fixed
- Resolve SonarCloud medium and high findings
- Give the action glyphs a generic fallback font
- Work out damage formulas instead of showing them raw

### Changed
- Add CI, SonarCloud, release and platform badges
- Declare each variable on its own line
- Exclude asset catalogs from SonarCloud analysis
- Flatten closures nested more than two deep
- Grant write access per job in the pf2e update
- Add CI with SonarCloud analysis
- Update the import fingerprint
- Update Tabletop Kit to 0.14.2
- Specify working out and describing damage formulas
- Explain installing the Mac app and its menu shortcuts
- Specify the Mac app's menus, window and install steps
- Say the toolkit is Mac apps, two also on the iPad
- Credit the Roboto Condensed and Gelasio fonts
- Specify the license texts on Field Guide's About screen
- Rename the suite the Tableside Toolkit

[1.1.0]: https://github.com/scooper4711/field-guide/releases/tag/v1.1.0

## [1.0.0] - 2026-10-14

### Added
- Initial release

[1.0.0]: https://github.com/scooper4711/field-guide/releases/tag/v1.0.0
