import Foundation

/// How two records of one book, read on different devices, are settled.
extension BookLore {
    /// Whether this record should replace `other`, a record of the same book. From the same PDF (the same digest), only
    /// a newer reader's record replaces it. From different PDFs, the newer edition wins (the later PDF date; a dated
    /// record beats one without a date), then the newer reader, then the later read, so reading an older PDF again
    /// doesn't replace a newer edition's lore.
    public func isPreferred(over other: BookLore) -> Bool {
        if sourceDigest == other.sourceDigest { return readerVersion > other.readerVersion }
        if sourceDate != other.sourceDate {
            return (sourceDate ?? .distantPast) > (other.sourceDate ?? .distantPast)
        }
        if readerVersion != other.readerVersion { return readerVersion > other.readerVersion }
        return importedAt > other.importedAt
    }

    /// The record as other devices get it: without where the PDF is on this one, which only this device can follow.
    public var shared: BookLore {
        var record = self
        record.location = nil
        return record
    }
}

extension LoreStore {
    /// Merges records of books read on other devices, keeping this device's location of a PDF it has too; returns the
    /// titles whose lore changed.
    public func merge(_ incoming: [BookLore]) throws -> [String] {
        let changed = incoming.compactMap(adopt)
        if !changed.isEmpty { try save() }
        return changed
    }

    /// The records of `titles` to send to other devices; titles not read are left out.
    public func sharedRecords(_ titles: [String]) -> [BookLore] {
        titles.compactMap { books[$0]?.shared }
    }
}
