import Foundation

/// Repairs text read from a PDF: lines joined into paragraphs, and the case of headings set in Paizo's display
/// fonts, whose joined-letter glyphs read back as capitals ("MaMMon", "The ShADow War").
public enum TextRepair {
    /// The lines of one paragraph as one string. Paizo doesn't break words across lines, so a hyphen at a line's end
    /// belongs to a compound ("self-" + "importance") and joins without a space; soft hyphens are dropped.
    public static func join(_ lines: [String]) -> String {
        var result = ""
        for line in lines.map(trimmed) where !line.isEmpty {
            let joinsWhole = ["-", "—", "\u{00AD}"].contains { result.hasSuffix($0) }
            if result.isEmpty || joinsWhole {
                result += line
            } else {
                result += " " + line
            }
        }
        return result.replacingOccurrences(of: "\u{00AD}", with: "")
    }

    /// A heading's words with their case repaired: the first letter is kept and the rest lowercased; roman numerals
    /// are capitalized. A heading equal to one of `names` (ignoring case and accents) takes that spelling.
    public static func heading(_ text: String, names: [String] = []) -> String {
        let key = matchKey(text)
        if let name = names.first(where: { matchKey($0) == key }) { return name }
        return text.split(separator: " ", omittingEmptySubsequences: false).map { word(String($0)) }
            .joined(separator: " ")
    }

    /// A line set in capitals in title case: "MASTER OF THE FIRST VAULT" becomes "Master of the First Vault".
    public static func titleCase(_ text: String) -> String {
        return text.lowercased().split(separator: " ").enumerated().map { index, word in
            if index > 0, minorWords.contains(String(word)) { return String(word) }
            if isRomanNumeral(word.uppercased()) { return word.uppercased() }
            return word.split(separator: "-", omittingEmptySubsequences: false)
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: "-")
        }.joined(separator: " ")
    }

    /// The words a title leaves lowercase after its first word.
    private static let minorWords: Set<String> = [
        "a", "an", "and", "as", "at", "by", "for", "in", "of", "on", "or", "the", "to", "with"
    ]

    /// The form two names are compared in: lowercased, without accents, daggers, asterisks or punctuation.
    public static func matchKey(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en"))
        return String(folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }

    private static func word(_ word: String) -> String {
        guard let first = word.first else { return word }
        if isRomanNumeral(word.filter(\.isLetter).uppercased()) { return word.uppercased() }
        return String(first) + word.dropFirst().lowercased()
    }

    /// Two to four of I, V and X, such as "II" or "IV"; a lone "I" is the pronoun.
    private static func isRomanNumeral(_ letters: String) -> Bool {
        (2...4).contains(letters.count) && letters.allSatisfy { "IVX".contains($0) }
    }

    private static func trimmed(_ line: String) -> String { line.trimmingCharacters(in: .whitespacesAndNewlines) }
}
