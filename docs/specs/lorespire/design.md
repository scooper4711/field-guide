# Offline Lorespire: design

## Download (`LorespireImport`, `FieldGuideLorespire`)
`Lorespire.documents` lists the four wiki pages. `LorespireDownloader` fetches each page once, keeps its article
(`div#page-data`, as `LorespirePage`), cleaned of scripts, event handlers and site-only controls
(`LorespireCleaner`), then fetches every `tiki-download_file.php?fileId=N` it references.

`LorespireLinkRewriter` points links at the download: a compilation heading that links to a wiki page marks where
that page starts (`LorespireHeadings.anchors`), so `tiki-index.php?page=X#frag` becomes `<document>.html#<anchor>`;
other pages stay on Lorespire; files become `files/<id>-<name>`.

Everything is fetched before anything is written, so a failed download leaves the folder as it was. The folder
(`Generated/Lorespire`, written by `scripts/fetch-lorespire.sh`, which `scripts/import.sh` runs) holds `<id>.html`,
`files/` and `manifest.json` (each document's title, system, source URL and h1–h3 outline).
