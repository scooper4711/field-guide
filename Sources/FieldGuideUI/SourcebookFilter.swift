/// Which sourcebooks the Sourcebooks list shows: all of them, those Field Guide has or hasn't processed, or those
/// the user owns in Scrollkeeper but hasn't downloaded there yet.
public enum SourcebookFilter: String, CaseIterable, Identifiable, Sendable {
    case all, processed, notProcessed, notDownloaded

    public var id: Self { self }

    public var title: String {
        switch self {
        case .all: "All"
        case .processed: "Processed"
        case .notProcessed: "Not Processed"
        case .notDownloaded: "Not Downloaded"
        }
    }

    /// What the list says when the filter leaves no sourcebooks.
    public var emptyMessage: String {
        switch self {
        case .all: "No sourcebooks."
        case .processed: "No processed sourcebooks yet."
        case .notProcessed: "Every sourcebook has been processed."
        case .notDownloaded: "Every sourcebook you own in Scrollkeeper has been downloaded."
        }
    }

    /// The filters to offer: Not Downloaded only once Scrollkeeper's list of owned titles has arrived, since
    /// without it no book can be known to be owned.
    /// - Parameter owned: whether each owned title, by SKU, is downloaded (`ScrollkeeperLink.owned`).
    public static func choices(owned: [String: Bool]) -> [Self] {
        owned.isEmpty ? allCases.filter { $0 != .notDownloaded } : allCases
    }

    /// The filter to apply: this one when it's offered, else All (a remembered Not Downloaded on a device
    /// without Scrollkeeper's list).
    public func effective(owned: [String: Bool]) -> Self {
        Self.choices(owned: owned).contains(self) ? self : .all
    }

    /// The rows this filter keeps, in order. Not Downloaded keeps the unprocessed books the user owns in
    /// Scrollkeeper without a downloaded copy there.
    /// - Parameter owned: whether each owned title, by SKU, is downloaded (`ScrollkeeperLink.owned`).
    public func rows(_ rows: [SourcebookRow], owned: [String: Bool]) -> [SourcebookRow] {
        switch self {
        case .all: rows
        case .processed: rows.filter(\.isRead)
        case .notProcessed: rows.filter { !$0.isRead }
        case .notDownloaded: rows.filter { !$0.isRead && $0.book.sku.flatMap { owned[$0] } == false }
        }
    }
}
