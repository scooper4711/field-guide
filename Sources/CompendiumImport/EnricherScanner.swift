import Foundation

/// One `@Name[argument]{label}` enricher found in text.
struct EnricherMatch {
    var name: String
    var argument: String
    var label: String?
}

/// Finds enrichers with nested brackets, such as `@Damage[(2d6+4)[fire]]`, and replaces them.
enum EnricherScanner {
    /// Replaces every enricher for which `transform` returns text, and leaves the others untouched.
    static func replace(in text: String, transform: (EnricherMatch) -> String?) -> String {
        var result = ""
        var index = text.startIndex
        while let at = text[index...].firstIndex(of: "@") {
            result += text[index..<at]
            guard let (match, end) = match(in: text, at: at), let replacement = transform(match) else {
                result.append("@")
                index = text.index(after: at)
                continue
            }
            result += replacement
            index = end
        }
        return result + text[index...]
    }

    /// Splits on `separator` where it is not inside brackets or parentheses.
    static func splitTopLevel(_ text: String, separator: Character) -> [String] {
        var parts: [String] = []
        var depth = 0
        var current = ""
        for character in text {
            if "[(".contains(character) { depth += 1 }
            if "])".contains(character) { depth -= 1 }
            if character == separator && depth == 0 {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        parts.append(current)
        return parts.filter { !$0.isEmpty }
    }

    private static func match(in text: String, at start: String.Index) -> (EnricherMatch, String.Index)? {
        let nameStart = text.index(after: start)
        guard let open = text[nameStart...].firstIndex(where: { !$0.isLetter }), text[open] == "[",
              open > nameStart else { return nil }
        let name = String(text[nameStart..<open])
        guard let close = matchingBracket(in: text, open: open) else { return unclosed(name, in: text, open: open) }
        let argument = String(text[text.index(after: open)..<close])
        var end = text.index(after: close)
        var label: String?
        if end < text.endIndex, text[end] == "{", let labelEnd = text[end...].firstIndex(of: "}") {
            label = String(text[text.index(after: end)..<labelEnd])
            end = text.index(after: labelEnd)
        }
        return (EnricherMatch(name: name, argument: argument, label: label), end)
    }

    /// An enricher whose `]` is missing, as in pf2e's `@Check[thievery|dc:28 (expert) to pick…`: its argument
    /// runs to the first space or tag.
    private static func unclosed(_ name: String, in text: String,
                                 open: String.Index) -> (EnricherMatch, String.Index)? {
        let start = text.index(after: open)
        let end = text[start...].firstIndex(where: { $0.isWhitespace || $0 == "<" }) ?? text.endIndex
        guard end > start else { return nil }
        return (EnricherMatch(name: name, argument: String(text[start..<end])), end)
    }

    private static func matchingBracket(in text: String, open: String.Index) -> String.Index? {
        var depth = 0
        var index = open
        while index < text.endIndex {
            if text[index] == "[" { depth += 1 }
            if text[index] == "]" {
                depth -= 1
                if depth == 0 { return index }
            }
            index = text.index(after: index)
        }
        return nil
    }
}
