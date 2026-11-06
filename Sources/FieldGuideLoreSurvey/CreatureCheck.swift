import Foundation
import PDFKit
import SourcebookLore

/// How well a book's creature lore, as `CreatureWriteups` reads it, matches what Foundry holds for the book's
/// creatures: a creature is found when the book gives it lore, and matches when its paragraphs share most of
/// Foundry's words.
struct CreatureCheck {
    struct Result {
        var book: String
        var creatures = 0
        var found = 0
        var matching = 0
        var familiesExpected = 0
        var familiesMatching = 0
        var misses: [String] = []
        var mismatches: [String] = []
        /// Faults in the text read (`TextQuality`), each with its creature's name.
        var faults: [String] = []

        var line: String {
            "| \(book) | \(creatures) | \(found) | \(matching) | \(familiesMatching)/\(familiesExpected) | "
                + "\(faults.count) |"
        }
    }

    /// The share of words two texts must have in common for their lore to match.
    static let matchThreshold = 0.6

    let creatures: [FoundryCreature]

    func check(book title: String, pdf: URL) -> Result {
        var result = Result(book: title)
        let credited = creatures.filter { $0.credited == title }
        guard let document = PDFDocument(url: pdf), !credited.isEmpty else { return result }
        let found = CreatureWriteups().writeups(in: document)
        let quality = TextQuality(reference: credited.map { $0.prose + " " + $0.familyProse }.joined(separator: " "))
        for creature in credited {
            result.creatures += 1
            if !creature.familyProse.isEmpty { result.familiesExpected += 1 }
            guard let lore = CreatureLore.keys(for: creature.name).lazy.compactMap({ found[$0] }).first else {
                result.misses.append(creature.name)
                continue
            }
            result.found += 1
            let text = (lore.paragraphs + lore.familyParagraphs).joined(separator: "\n")
            result.faults += (quality.problems(in: text) + TextQuality.splitParagraphs(lore.paragraphs)
                + TextQuality.splitParagraphs(lore.familyParagraphs)).map { "\(creature.name): \($0)" }
            let own = Self.similarity(lore.paragraphs.joined(separator: " "), creature.prose)
            if own >= Self.matchThreshold {
                result.matching += 1
            } else {
                result.mismatches.append(String(format: "%@ (%.2f)", creature.name, own))
                Self.log(creature, lore)
            }
            if !creature.familyProse.isEmpty,
               Self.similarity(lore.familyParagraphs.joined(separator: " "), creature.familyProse)
                >= Self.matchThreshold {
                result.familiesMatching += 1
            }
        }
        return result
    }

    /// Writes a mismatch's two texts to standard error, for working out why they differ.
    private static func log(_ creature: FoundryCreature, _ lore: CreatureLore) {
        let text = "### \(creature.name)\nBOOK: \(lore.paragraphs.joined(separator: " / "))\n"
            + "FOUNDRY: \(creature.prose)\n"
            + "BOOK FAMILY [\(lore.family)]: \(lore.familyParagraphs.joined(separator: " / ").prefix(300))\n"
            + "FOUNDRY FAMILY: \(creature.familyProse.prefix(300))\n\n"
        FileHandle.standardError.write(Data(text.utf8))
    }

    /// The share of the two texts' words they have in common, from 0 to 1.
    static func similarity(_ first: String, _ second: String) -> Double {
        LoreSourceChooser.similarity(first, second)
    }
}
