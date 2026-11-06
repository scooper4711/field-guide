import Foundation

/// Finds faults in text read from a PDF by comparing it with Foundry's copy of the same text: words broken in two
/// ("shor ter"), hyphens left from a line break ("shorter- lived" where Foundry has "shorter-lived" or
/// "shorterlived"), words run together ("andthe"), and characters no prose should hold. Text the book has and
/// Foundry lacks is fine; only words Foundry would know when mended count.
struct TextQuality {
    /// Foundry's words, lowercased.
    let vocabulary: Set<String>
    /// The system's word list (`/usr/share/dict/words`): a word in it isn't two run together.
    static let dictionary: Set<String> = {
        let words = (try? String(contentsOfFile: "/usr/share/dict/words", encoding: .utf8)) ?? ""
        return Set(words.lowercased().split(separator: "\n").map(String.init))
    }()

    /// Foundry's neighboring words, lowercased and joined by a space.
    let pairs: Set<String>

    init(reference: String) {
        let words = Self.words(in: reference)
        vocabulary = Set(words)
        pairs = Set(zip(words, words.dropFirst()).map { "\($0) \($1)" })
    }

    /// Paragraphs split mid-sentence: one that doesn't end a sentence, followed by one starting in lowercase.
    /// `continuing` says which paragraphs may continue the one before (by default, all).
    static func splitParagraphs(_ paragraphs: [String], continuing: [Bool] = []) -> [String] {
        paragraphs.indices.dropFirst().compactMap { index in
            let (first, second) = (paragraphs[index - 1], paragraphs[index])
            guard continuing.isEmpty || continuing[index], let end = first.last, !".!?:”’\")".contains(end),
                  second.first?.isLowercase == true else { return nil }
            return "split: «\(first.suffix(30))» / «\(second.prefix(30))»"
        }
    }

    /// The faults, each with the text around it.
    func problems(in text: String) -> [String] {
        (brokenWords(in: text) + hyphenBreaks(in: text) + runTogether(in: text)).map { fault in
            fault + " «" + Self.context(of: fault, in: text) + "»"
        } + strayCharacters(in: text)
    }

    /// Up to 30 characters either side of the fault's first word in `text`.
    static func context(of fault: String, in text: String) -> String {
        let word = fault.split(separator: " ").dropFirst().first.map(String.init) ?? ""
        guard !word.isEmpty, let range = text.range(of: word, options: .caseInsensitive) else { return "" }
        let start = text.index(range.lowerBound, offsetBy: -30, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: 30, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[start..<end]).replacingOccurrences(of: "\n", with: " ")
    }

    /// Two neighbors parted by a space that are one of Foundry's words when joined, one of them not a word Foundry
    /// has. Words joined by a hyphen are a compound, which Foundry's copy sometimes runs together.
    func brokenWords(in text: String) -> [String] {
        let tokens = text.split(whereSeparator: \.isWhitespace).map { token in
            token.lowercased().trimmingCharacters(in: CharacterSet.letters.inverted)
        }
        return zip(tokens, tokens.dropFirst()).compactMap { first, second in
            guard !first.isEmpty, !second.isEmpty, first.allSatisfy(\.isLetter), second.allSatisfy(\.isLetter)
            else { return nil }
            let joined = first + second
            guard vocabulary.contains(joined), !vocabulary.contains(first) || !vocabulary.contains(second),
                  joined.count > 3 else { return nil }
            return "broken: \(first) \(second)"
        }
    }

    /// A hyphen and a space inside a word Foundry spells without the space.
    func hyphenBreaks(in text: String) -> [String] {
        matches(of: #"([A-Za-z]+)[-\u{2010}\u{00AD}]\s+([a-z]+)"#, in: text).compactMap { parts in
            let (first, second) = (parts[1].lowercased(), parts[2].lowercased())
            let isPair = vocabulary.contains(first) && vocabulary.contains(second)
                && !["and", "or", "to"].contains(second)
            let isWord = vocabulary.contains(first + second) || isPair
            return isWord ? "hyphen: \(parts[0])" : nil
        }
    }

    /// A word Foundry lacks that is two neighboring words of Foundry's run together.
    func runTogether(in text: String) -> [String] {
        Self.words(in: text).filter { $0.count >= 6 && !vocabulary.contains($0) && !Self.dictionary.contains($0) }
            .compactMap { word in
            let splits = (2..<(word.count - 1)).map { word.index(word.startIndex, offsetBy: $0) }
            let split = splits.first { index in pairs.contains("\(word[..<index]) \(word[index...])") }
            return split.map { "joined: \(word[..<$0]) + \(word[$0...])" }
        }
    }

    /// Object replacement characters, soft hyphens, private-use glyphs (action icons read as letters), ligatures
    /// and control characters.
    func strayCharacters(in text: String) -> [String] {
        let stray = text.unicodeScalars.filter { scalar in
            scalar == "\u{FFFC}" || scalar == "\u{00AD}" || (0xE000...0xF8FF).contains(scalar.value)
                || (0xFB00...0xFB06).contains(scalar.value)
                || CharacterSet.controlCharacters.contains(scalar) && scalar != "\n"
        }
        guard let first = stray.first, let index = text.unicodeScalars.firstIndex(of: first) else { return [] }
        let codes = stray.map { String(format: "U+%04X", $0.value) }.joined(separator: " ")
        let start = text.unicodeScalars.index(index, offsetBy: -30, limitedBy: text.unicodeScalars.startIndex)
            ?? text.unicodeScalars.startIndex
        let end = text.unicodeScalars.index(index, offsetBy: 30, limitedBy: text.unicodeScalars.endIndex)
            ?? text.unicodeScalars.endIndex
        return ["stray: \(codes) «\(String(text.unicodeScalars[start..<end]))»"]
    }

    static func words(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter }.map(String.init)
    }

    private func matches(of pattern: String, in text: String) -> [[String]] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        return expression.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (0..<match.numberOfRanges).map { index in
                Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
            }
        }
    }
}
