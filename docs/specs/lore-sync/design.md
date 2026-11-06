# Lore sync: design

## Merge rule (`SourcebookLore`)
`BookLore.isPreferred(over:)` decides between two records of one book: with the same digest, only a higher
`readerVersion` wins; otherwise compare `sourceDate` (nil is oldest), then `readerVersion`, then `importedAt`. `LoreStore.merge(_:)` applies
it to records from another device, keeps the local `location` when the digests match, saves, and returns the titles
that changed. `readIfNew` skips a book whose stored record has a `readerVersion` above `BookReader.version`.

`LoreStore`'s reads (`addFiles`, `importFolder`, `addNewFiles`) already return the titles they read; those are the
records to upload.

## Records (`LoreSync`)
`LoreRecordCoder` maps a `BookLore` to a `CKRecord` of type `BookLore` in the zone `Lore` and back:

| Field | Type | Holds |
|---|---|---|
| record name | | `book-` + SHA-256 of the title, so any title makes a valid name |
| `title` | String | the book's title |
| `sourceDigest` | String | the PDF's SHA-256 |
| `sourceDate` | Date | the PDF's date, when it has one |
| `readerVersion` | Int64 | `BookReader.version` that read it |
| `importedAt` | Date | when it was read |
| `lore` | CKAsset | the record as JSON, without `location` |

The lore is an asset because a bestiary's creature lore can pass a record's 1 MB limit. The plain fields repeat the
provenance so a record can be judged without downloading the asset.

## Engine (`LoreSync`)
`LoreSyncEngine` wraps `CKSyncEngine` over the private database of `iCloud.io.github.scooper4711.FieldGuide`:

- Its state serialization is saved to `lore-sync-state.plist` next to `lore.json` after each state update.
- The first start saves the `Lore` zone.
- Titles a read changes become `.saveRecord` pending changes; `nextRecordZoneChangeBatch` builds their records from
  the store.
- Fetched records are decoded and merged into the store; the model refreshes.
- A `serverRecordChanged` failure is settled with the merge rule (`LoreConflict.resolve`): when the local record wins,
  it is saved again over the server's record (keeping its change tag); otherwise the server's is merged.
- `zoneNotFound` saves the zone and the record again. A deleted zone (the user reset iCloud data) re-uploads every
  book.

The decisions are pure functions over records (`LoreConflict`, `LoreRecordCoder`), so tests cover them without
CloudKit; the engine only moves records.

## Turning it on
`CKContainer(identifier:)` stops the app when the entitlement is missing, so the engine starts only when the
Info.plist has `LoreSyncContainer` and `CKContainer.accountStatus()` is `.available`. Builds write that key only with
the entitlements:

- iPad and iPhone: `ios/FieldGuide.entitlements` (CloudKit container, `aps-environment`), and `ios/Info.plist`,
  which Xcode merges into the Info.plist it generates, for `LoreSyncContainer` and the `remote-notification`
  background mode (custom keys can't be `INFOPLIST_KEY_` settings). `make ipad-simulator` builds unsigned, so it
  leaves `ios/Info.plist` out.
- Mac: `scripts/build-app.sh` calls `scripts/add-icloud-entitlements.sh` when it signs for the team and has a
  Developer ID provisioning profile with iCloud (`PROVISIONING_PROFILE`; the release workflow decodes it from the
  `DEVELOPER_ID_PROVISIONING_PROFILE` secret). That adds the iCloud and push entitlements,
  `com.apple.application-identifier` and `com.apple.developer.team-identifier`, embeds the profile and writes
  `LoreSyncContainer`.

### Environments
CloudKit keeps a Development and a Production database per container, and they don't see each other. iPad builds
installed from Xcode use Development; TestFlight and App Store builds use Production. The Mac build uses Production
unless `ICLOUD_ENVIRONMENT=Development`, which is how to sync it with an iPad installed from Xcode. Before a release,
deploy the schema to Production in the CloudKit Console.

## Privacy
The privacy policy says lore syncs through the user's private iCloud database. The App Privacy answer stays "Data Not
Collected": data kept only in the user's own iCloud isn't collected.
