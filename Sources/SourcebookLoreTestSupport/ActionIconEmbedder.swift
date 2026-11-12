import CoreGraphics
import CoreText
import Foundation

/// Puts Paizo's Pathfinder-Icons font into a PDF whole. CoreGraphics embeds only the glyphs a page uses and has
/// them read back as the font's private code points; the font's license wants the file unaltered, and Pluck knows
/// the icons by the text Paizo's own PDFs give them ("[one-action]"). So the font CoreGraphics wrote is replaced
/// with the font file, byte for byte, and each icon is given that text.
struct ActionIconEmbedder {
    /// The font file.
    let font: Data

    /// `pdf`, as CoreGraphics wrote it, with the whole font; nil when the font or the PDF can't be read. A PDF that
    /// draws no icons comes back as it was.
    func embedding(in pdf: Data) -> Data? {
        guard var file = PDFFile(pdf) else { return nil }
        let fonts = file.objects.keys.sorted().filter { Self.isSubset(file.text(of: $0)) }
        let subsets = fonts.compactMap { subset(at: $0, in: file) }
        guard subsets.count == fonts.count else { return nil }
        for subset in subsets {
            guard let objects = objects(replacing: subset, in: file) else { return nil }
            file.objects.merge(objects) { $1 }
            file.size += 3
        }
        return subsets.isEmpty ? pdf : file.data
    }

    /// Whether the object is a font CoreGraphics wrote for its subset of the icons' font.
    private static func isSubset(_ object: String) -> Bool {
        object.contains("+\(ActionIcon.fontName)") && object.firstMatch(#"(/Subtype\s+/TrueType)"#) != nil
    }

    /// What CoreGraphics wrote for the subset whose font is at `number`; nil when it isn't written as expected.
    private func subset(at number: Int, in file: PDFFile) -> FontSubset? {
        let font = file.text(of: number)
        guard let first = font.firstMatch(#"/FirstChar\s+(\d+)"#).flatMap({ Int($0) }),
              let widths = font.firstMatch(#"/Widths\s*\[([^\]]*)\]"#)?.split(whereSeparator: \.isWhitespace),
              let descriptor = font.firstMatch(#"/FontDescriptor\s+(\d+)\s+0\s+R"#).flatMap({ Int($0) }),
              let toUnicode = font.firstMatch(#"/ToUnicode\s+(\d+)\s+0\s+R"#).flatMap({ Int($0) }),
              let fontFile = file.text(of: descriptor).firstMatch(#"/FontFile2\s+(\d+)\s+0\s+R"#).flatMap({ Int($0) }),
              let map = file.stream(of: toUnicode).flatMap({ String(bytes: $0, encoding: .isoLatin1) }) else {
            return nil
        }
        // CoreGraphics writes a line per run of glyphs: the run's first and last bytes, then the first's code point.
        let glyphs = map.matches(#"<([0-9a-f]{2})>\s*<([0-9a-f]{2})>\s*<([0-9a-f]{4})>"#).flatMap { match in
            let numbers = match.compactMap { Int($0, radix: 16) }
            guard numbers.count == 3, numbers[0] <= numbers[1] else { return [SubsetGlyph]() }
            return (numbers[0]...numbers[1]).compactMap { code in
                let scalar = numbers[2] + code - numbers[0]
                guard let icon = ActionIcon.allCases.first(where: { $0.character.value == scalar }),
                      widths.indices.contains(code - first) else { return nil }
                return SubsetGlyph(code: code, icon: icon, width: String(widths[code - first]))
            }
        }
        // Every glyph the font draws must be an icon that was found, or some would be left without their text.
        guard !glyphs.isEmpty, glyphs.count == widths.count else { return nil }
        return FontSubset(font: number, descriptor: descriptor, file: fontFile, toUnicode: toUnicode, glyphs: glyphs)
    }

    /// The objects that draw `subset`'s glyphs from the whole font: the font, in which each byte the pages use
    /// stands for its icon's text and, through `glyphMap`, names its glyph in the font file; the descriptor under
    /// the font's own name; and the file itself, uncompressed. A byte is its own character ID, since readers differ
    /// over which of the two the text is looked up by.
    private func objects(replacing subset: FontSubset, in file: PDFFile) -> [Int: Data]? {
        guard let glyphMap = glyphMap(for: subset.glyphs) else { return nil }
        let (descendant, encoding, glyphs) = (file.size, file.size + 1, file.size + 2)
        let name = ActionIcon.fontName
        let system = "/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >>"
        let widths = subset.glyphs.map { "\($0.code) [\($0.width)]" }
        let texts = subset.glyphs.map { glyph in
            String(format: "<%02X> <", glyph.code)
                + glyph.icon.token.utf16.map { String(format: "%04X", $0) }.joined() + ">"
        }
        // The subset's name is the font's behind a tag of six letters ("AAAAAE+Pathfinder-Icons").
        let descriptor = file.text(of: subset.descriptor).replacing(#/[A-Z]{6}\+/#, with: "")
        return [
            subset.descriptor: Data(descriptor.utf8),
            subset.font: PDFFile.object(subset.font, "/Type /Font /Subtype /Type0 /BaseFont /\(name) "
                + "/Encoding \(encoding) 0 R /DescendantFonts [\(descendant) 0 R] /ToUnicode \(subset.toUnicode) 0 R"),
            descendant: PDFFile.object(descendant, "/Type /Font /Subtype /CIDFontType2 /BaseFont /\(name) \(system) "
                + "/FontDescriptor \(subset.descriptor) 0 R /CIDToGIDMap \(glyphs) 0 R /DW 1000 "
                + "/W [\(widths.joined(separator: " "))]"),
            encoding: PDFFile.object(encoding, "/Type /CMap /CMapName /ActionIcons \(system)", stream: Self
                .characterMap(type: 1, kind: "cidrange", lines: ["<00> <FF> 0"])),
            glyphs: PDFFile.object(glyphs, "", stream: glyphMap),
            subset.toUnicode: PDFFile.object(subset.toUnicode, "",
                                             stream: Self.characterMap(type: 2, kind: "bfchar", lines: texts)),
            subset.file: PDFFile.object(subset.file, "/Length1 \(font.count)", stream: font)
        ]
    }

    /// The font file's glyph for each byte the pages use: two bytes a glyph, in the bytes' order.
    private func glyphMap(for glyphs: [SubsetGlyph]) -> Data? {
        guard let provider = CGDataProvider(data: font as CFData), let font = CGFont(provider) else { return nil }
        let characters = glyphs.map { UniChar($0.icon.character.value) }
        var found = [CGGlyph](repeating: 0, count: characters.count)
        guard CTFontGetGlyphsForCharacters(
            CTFontCreateWithGraphicsFont(font, 9, nil, nil), characters, &found, characters.count) else { return nil }
        var map = Data(count: ((glyphs.map(\.code).max() ?? 0) + 1) * 2)
        for (glyph, number) in zip(glyphs, found) {
            map[glyph.code * 2] = UInt8(number >> 8)
            map[glyph.code * 2 + 1] = UInt8(number & 0xFF)
        }
        return map
    }

    /// A character map from one-byte codes: to character IDs ("cidrange") or to text ("bfchar").
    private static func characterMap(type: Int, kind: String, lines: [String]) -> Data {
        Data("""
            /CIDInit /ProcSet findresource begin
            12 dict begin
            begincmap
            /CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> def
            /CMapName /ActionIcons def
            /CMapType \(type) def
            1 begincodespacerange
            <00> <FF>
            endcodespacerange
            \(lines.count) begin\(kind)
            \(lines.joined(separator: "\n"))
            end\(kind)
            endcmap
            CMapName currentdict /CMap defineresource pop
            end
            end
            """.utf8)
    }
}

/// What CoreGraphics wrote for the icons' font: its objects' numbers, and its glyphs.
private struct FontSubset {
    var font: Int
    var descriptor: Int
    var file: Int
    var toUnicode: Int
    var glyphs: [SubsetGlyph]
}

/// A glyph of the subset: the byte the pages show it with, its icon and its width, as the PDF writes a width.
private struct SubsetGlyph {
    var code: Int
    var icon: ActionIcon
    var width: String
}
