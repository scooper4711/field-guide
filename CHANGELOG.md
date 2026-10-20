# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
