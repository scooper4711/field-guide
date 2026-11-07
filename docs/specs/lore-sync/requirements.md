# Lore sync: requirements

Lore read from the user's own sourcebooks on one device reaches their other devices, so a phone or iPad without room
for the PDFs still shows it (issue #26).

## R1 What syncs
- R1.1 Each book's lore as `LoreStore` keeps it (`BookLore`): its deities' and creatures' lore and where it came
  from (the PDF's digest, the PDF's own date, the reader version and when it was read).
- R1.2 Never the PDFs, and never where a PDF is on a device (`location`): that is a bookmark only the device that
  made it can follow.
- R1.3 Not creature or item art, which is drawn from the PDFs when shown; syncing it is a separate piece of work.
- R1.4 Watched folders stay on each device.

## R2 Where it syncs
- R2.1 Through the user's private CloudKit database, between devices signed into the same Apple Account. The
  developer can't read it, and nothing goes anywhere else.
- R2.2 Without iCloud (signed out, iCloud Drive off for the app, or a build without the iCloud entitlement, such as
  an ad hoc or `swift run` build), the app works as before, with lore on the device alone, and doesn't crash.
- R2.3 The Sourcebooks screen says whether lore syncs: "Lore syncs through your iCloud" or "iCloud is off: lore
  stays on this device".

## R3 Merging
- R3.1 When two devices read the same PDF (same digest), the record from the newer reader wins; otherwise the
  device's own record stays. Either way a device keeps its own location of the PDF.
- R3.2 Otherwise the newer edition wins (the later PDF date; a dated record beats one without a date), then the
  newer reader, then the later read. Reading an older PDF again later doesn't replace a newer edition's lore.
- R3.3 An app whose reader is older than a record's doesn't read the book again over it.
- R3.4 Deleting a PDF on a device keeps its lore there and everywhere else.

## R4 Showing it
- R4.1 Lore that arrives from another device appears without restarting the app.
- R4.2 A book read on another device is listed as read, with "Read on another device" where its file would show.
