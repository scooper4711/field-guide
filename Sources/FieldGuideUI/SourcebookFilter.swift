/// Which sourcebooks the Sourcebooks list shows: all of them, or only those Field Guide has or hasn't processed.
public enum SourcebookFilter: String, CaseIterable, Identifiable, Sendable {
    case all, processed, notProcessed

    public var id: Self { self }

    public var title: String {
        switch self {
        case .all: "All"
        case .processed: "Processed"
        case .notProcessed: "Not Processed"
        }
    }

    /// What the list says when the filter leaves no sourcebooks.
    public var emptyMessage: String {
        switch self {
        case .all: "No sourcebooks."
        case .processed: "No processed sourcebooks yet."
        case .notProcessed: "Every sourcebook has been processed."
        }
    }

    public func rows(_ rows: [SourcebookRow]) -> [SourcebookRow] {
        switch self {
        case .all: rows
        case .processed: rows.filter(\.isRead)
        case .notProcessed: rows.filter { !$0.isRead }
        }
    }
}
