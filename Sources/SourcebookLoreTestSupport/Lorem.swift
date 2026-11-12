/// Placeholder text.
enum Lorem {
    static let words = """
        lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore \
        magna aliqua ut enim ad minim veniam quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo \
        consequat duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur
        """.split(separator: " ").map(String.init)

    /// Three or four sentences, chosen by `seed`.
    static func paragraph(seed: Int) -> String {
        (0..<(3 + seed % 2)).map { sentence in
            let start = (seed * 7 + sentence * 11) % words.count
            let picked = (0..<(9 + sentence % 4)).map { words[(start + $0) % words.count] }.joined(separator: " ")
            return picked.prefix(1).uppercased() + picked.dropFirst() + "."
        }.joined(separator: " ")
    }

    /// The text broken into lines of at most `width` characters; the last is short, as a paragraph's last is.
    static func lines(of text: String, width: Int) -> [String] {
        var lines: [String] = []
        var line = ""
        for word in text.split(separator: " ") {
            if !line.isEmpty, line.count + word.count + 1 > width {
                lines.append(line)
                line = ""
            }
            line += (line.isEmpty ? "" : " ") + word
        }
        if !line.isEmpty { lines.append(line) }
        return lines
    }
}
