import Foundation

/// A PDF as CoreGraphics writes one, taken apart into its numbered objects so some can be replaced: one table of
/// objects at the end, none of them packed inside another.
struct PDFFile {
    /// What comes before the first object.
    var header: Data
    /// Each object, by its number, from "1 0 obj" to "endobj".
    var objects: [Int: Data]
    /// The trailer dictionary's contents.
    var trailer: String
    /// One more than the highest object number.
    var size: Int

    /// Nil when `data` isn't laid out as CoreGraphics lays a PDF out.
    init?(_ data: Data) {
        guard let end = String(data: data.suffix(64), encoding: .isoLatin1),
              let table = end.firstMatch(#"startxref\s+(\d+)\s+%%EOF\s*$"#).flatMap({ Int($0) }), table < data.count,
              let tail = String(data: data.dropFirst(table), encoding: .isoLatin1),
              let count = tail.firstMatch(#"^xref\s+0 (\d+)\s"#).flatMap({ Int($0) }),
              let trailer = tail.firstMatch(#"(?s)trailer\s*<<(.*?)>>\s*startxref"#) else { return nil }
        let entries = tail.matches(#"(\d{10}) \d{5} ([nf])"#)
        guard entries.count == count else { return nil }
        // CoreGraphics lists a number it never used as an object at the file's start.
        let offsets = entries.enumerated().filter { $0.element[1] == "n" && $0.element[0] != "0000000000" }
            .compactMap { entry in Int(entry.element[0]).map { (number: entry.offset, offset: $0) } }
            .sorted { $0.offset < $1.offset }
        guard let first = offsets.first, offsets.allSatisfy({ $0.offset < table }) else { return nil }
        let ends = offsets.dropFirst().map(\.offset) + [table]
        header = data.prefix(first.offset)
        objects = Dictionary(uniqueKeysWithValues: zip(offsets, ends).map { entry, end in
            (entry.number, data.subdata(in: (data.startIndex + entry.offset)..<(data.startIndex + end)))
        })
        self.trailer = trailer
        size = count
    }

    /// The object as text, a byte to a character; empty when there is none.
    func text(of number: Int) -> String {
        objects[number].flatMap { String(data: $0, encoding: .isoLatin1) } ?? ""
    }

    /// The object's stream, uncompressed.
    func stream(of number: Int) -> Data? {
        let text = text(of: number)
        guard let object = objects[number], let start = object.range(of: Data("stream\n".utf8))?.upperBound,
              let length = text.firstMatch(#"/Length\s+(\d+)\s*[/>]"#).flatMap({ Int($0) }),
              start + length <= object.endIndex else { return nil }
        let stream = object.subdata(in: start..<(start + length))
        guard text.contains("/FlateDecode") else { return stream }
        // A PDF's compressed stream opens with zlib's two-byte header, which Foundation doesn't expect.
        return try? (stream.dropFirst(2) as NSData).decompressed(using: .zlib) as Data
    }

    /// The file, its table of objects written afresh.
    var data: Data {
        var data = header
        var offsets: [Int: Int] = [:]
        for number in objects.keys.sorted() {
            offsets[number] = data.count
            data.append(objects[number] ?? Data())
        }
        let table = data.count
        let entries = (0..<size).map { number in
            offsets[number].map { String(format: "%010d 00000 n \n", $0) }
                ?? "0000000000 \(number == 0 ? "65535" : "00000") f \n"
        }
        let trailer = trailer.replacing(#/\/Size\s+\d+/#, with: "/Size \(size)")
        data.append(Data(("xref\n0 \(size)\n" + entries.joined() + "trailer\n<<\(trailer)>>\nstartxref\n\(table)\n"
                          + "%%EOF\n").utf8))
        return data
    }

    /// An object: a dictionary with `entries`, and its stream when it has one.
    static func object(_ number: Int, _ entries: String, stream: Data? = nil) -> Data {
        guard let stream else { return Data("\(number) 0 obj\n<< \(entries) >>\nendobj\n".utf8) }
        return Data("\(number) 0 obj\n<< \(entries) /Length \(stream.count) >>\nstream\n".utf8) + stream
            + Data("\nendstream\nendobj\n".utf8)
    }
}

extension String {
    /// The first capture group of the pattern's first match.
    func firstMatch(_ pattern: String) -> String? {
        matches(pattern).first?.first
    }

    /// Every match's capture groups.
    func matches(_ pattern: String) -> [[String]] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        return expression.matches(in: self, range: NSRange(startIndex..., in: self)).map { match in
            (1..<match.numberOfRanges).map { Range(match.range(at: $0), in: self).map { String(self[$0]) } ?? "" }
        }
    }
}
