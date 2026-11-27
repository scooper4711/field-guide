# Offline Lorespire: design

## Download (`LorespireImport`, `FieldGuideLorespire`)
`Lorespire.documents` lists the four wiki pages. `LorespireDownloader` fetches each page once, keeps its article
(`div#page-data`, as `LorespirePage`), cleaned of scripts, event handlers and site-only controls
(`LorespireCleaner`), then fetches every `tiki-download_file.php?fileId=N` it references. The session sends no
cookies: with Tiki's session cookie but no `javascript_enabled` one, the site leaves out the tab sets' tab bars.

Everything is fetched before anything is written, so a failed download leaves the folder as it was. The folder
(`build/lorespire`, written by `scripts/fetch-lorespire.sh`, which `scripts/import.sh` runs before the import) holds
`<id>.html` with the site's own links, `files/<id>-<name>` and `manifest.json`. It stays out of `Generated/`, which
the app bundles whole.

## Entries (`LorespireLibrary`)
`LorespireOutline` splits a document into `LorespireSection`s. A heading that links to a wiki page starts that page
(the first such heading wins); so does every heading at the level of the highest linked one, which catches the
Venture-Officer Handbook's unlinked sections, keyed `<document page>.<heading id>`. A page runs to the next heading of
its level or higher; the pages inside it are cut out and replaced by a link. The preamble (version and date) opens
the first page. A page with no text of its own is dropped, and its key and headings open the next page.

The part is the top-level page's title, or the document's `part` (Venture-Officer Handbook). A system's entries are
its own guide's pages, then the pages of the guides for both, numbered in that order; ids are
`lorespire.<system>.<key>`.

Per entry: headings move up so its first sub-headings are `h2`; `LorespireMarkup` turns tab sets into an
`h6.tab` per tab, mouseover footnotes into an inline `<small>(…)</small>`, cards into `<aside>`, drops every other
`div` and `span`, and keeps only `href`, `src`, `alt`, `id`, `rowspan`, `colspan`, `width` and `height`.
`LorespireLinkRewriter` then points `tiki-index.php?page=X#frag` at the entry holding heading `frag` (or page `X`),
as `entry:<id>`; pages outside the system's guides and attachments go to Lorespire; images to
`fieldguide:///images/lorespire/<file>`.

## Catalog (`CompendiumImport.OrganizedPlay`)
`FieldGuideImport --lorespire build/lorespire` adds a row per entry: category `organizedPlay`, facet `.section` =
the part, subtitle the part, sort key the zero-padded order, a footer linking the page on Lorespire. It copies
`files/` to `Generated/Images/lorespire/` and writes the licenses page as Markdown to
`Generated/Licenses/Lorespire Licenses and Trademarks.md` for the About screen. Without a download there are no
such rows. `scripts/fingerprint.sh` leaves `organizedPlay` rows out.
