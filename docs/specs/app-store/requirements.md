# Mac App Store build: requirements

Field Guide 2.0 is listed on the Mac App Store beside its notarized disk image and its iPad and iPhone app
(tabletop-kit#26). The packaging steps are tabletop-kit's `scripts/package-appstore.sh` (its `appstore-build` spec).

## R1 The build
- R1.1 `CHANNEL=appstore scripts/build-app.sh` (or `make appstore`) builds `build/appstore/Field Guide.pkg` from the
  same sources as the disk image, compiled with `-DAPP_STORE`. Field Guide has no updater or payment link to leave
  out.
- R1.2 `PROVISIONING_PROFILE` is the Mac App Store profile, which carries iCloud. The app is signed with the
  CloudKit container in the Production environment, so lore sync works as in the disk image build.
- R1.3 The build number (`BUILD_NUMBER`, the commit count) is apart from the version, and the bundle declares
  `ITSAppUsesNonExemptEncryption` as false, a copyright line and the reference category.

## R2 Privacy
- R2.1 The privacy manifest (`ios/App/PrivacyInfo.xcprivacy`) ships in the bundle: no tracking, no data collected.
- R2.2 `PRIVACY.md` is the privacy policy, linked from the Help menu.

## R3 Review
- R3.1 `APP-STORE-REVIEW.md` holds the checklist and the review notes, with a use named for every entitlement. The
  file is kept out of the repository (`.git/info/exclude`).
