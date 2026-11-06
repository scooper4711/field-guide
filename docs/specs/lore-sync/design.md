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

- iPad and iPhone: `ios/App/FieldGuide.entitlements` (CloudKit container, `aps-environment`), with
  `INFOPLIST_KEY_LoreSyncContainer` in the target.
- Mac: `scripts/build-app.sh` adds the iCloud and push entitlements, `com.apple.application-identifier` and
  `com.apple.developer.team-identifier`, and embeds the Developer ID provisioning profile, only when it signs for the
  team and has the profile (`PROVISIONING_PROFILE`).

## Privacy
The privacy policy says lore syncs through the user's private iCloud database. The App Privacy answer stays "Data Not
Collected": data kept only in the user's own iCloud isn't collected.
