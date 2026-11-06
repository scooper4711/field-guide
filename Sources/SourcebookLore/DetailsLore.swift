import Foundation

/// A part of an ancestry's or class's Details: an introduction (no heading) or a section such as "Society" or
/// "During combat encounters...", its paragraphs as printed. A paragraph that starts with a bold label ("Popular
/// Edicts") keeps it apart, and bulleted items are kept as such.
public struct DetailsSection: Codable, Equatable, Sendable {
    /// A paragraph, a bulleted item, or a paragraph opening with a bold label.
    public struct Paragraph: Codable, Equatable, Sendable {
        public var label: String
        public var text: String
        public var isBullet: Bool

        public init(_ text: String, label: String = "", isBullet: Bool = false) {
            self.text = text
            self.label = label
            self.isBullet = isBullet
        }
    }

    public var heading: String
    public var paragraphs: [Paragraph]

    public init(heading: String = "", paragraphs: [Paragraph] = []) {
        self.heading = heading
        self.paragraphs = paragraphs
    }
}

/// What an ancestry's or class's Details tab shows, read from the user's book: the setting's prose about it, without
/// the rules its overview already shows.
public struct DetailsLore: Codable, Equatable, Sendable {
    public var sections: [DetailsSection]

    public init(sections: [DetailsSection] = []) {
        self.sections = sections
    }

    public var isEmpty: Bool { sections.allSatisfy(\.paragraphs.isEmpty) }

    /// The Details as HTML, for the place in the Details page the import left for them (`DetailsPage`): each
    /// section's heading, its paragraphs, and its bulleted items as a list.
    public var html: String {
        sections.map(Self.html(of:)).joined()
    }

    private static func html(of section: DetailsSection) -> String {
        guard !section.paragraphs.isEmpty else { return "" }
        var html = section.heading.isEmpty ? "" : "<h2>\(HTMLText.escape(section.heading))</h2>"
        var inList = false
        for paragraph in section.paragraphs {
            if paragraph.isBullet != inList {
                html += paragraph.isBullet ? "<ul>" : "</ul>"
                inList = paragraph.isBullet
            }
            let label = paragraph.label.isEmpty ? "" : "<strong>\(HTMLText.escape(paragraph.label))</strong> "
            html += paragraph.isBullet ? "<li>\(HTMLText.escape(paragraph.text))</li>"
                : "<p>\(label)\(HTMLText.escape(paragraph.text))</p>"
        }
        return html + (inList ? "</ul>" : "")
    }
}
