import FieldGuideKit
import Foundation
import PDFKit
import SourcebookLore
import SourcebookLoreTestSupport

// Reads deities' lore from sourcebook PDFs and works out which book supplies each deity.
//
// FieldGuideLoreSurvey table|writeups <pdf> [--catalog Generated/catalog.sqlite]
//     prints the stat lines a deity table gives, or the write-ups a book gives, as JSON
// FieldGuideLoreSurvey creatures --pf2e <repository> <title>=<pdf>...
//     checks the creature lore read from each book against Foundry's, as a table and the creatures missed
// FieldGuideLoreSurvey creatures-of <pdf> <name>...
//     prints the lore a book gives the named creatures, as JSON
// FieldGuideLoreSurvey details-of <pdf> <name>...
//     prints the Details a book gives the named ancestries or classes, as JSON
// FieldGuideLoreSurvey details --pf2e <repository> <title>=<pdf>...
//     checks the ancestries' and classes' Details read from each book against Foundry's prose
// FieldGuideLoreSurvey lore-books --pf2e <repository> --scrollkeeper <catalog.json> --list <sourcebooks.json>
//     adds the books Foundry credits creatures' and ancestries' and classes' lore to to the sourcebook list, with
//     Scrollkeeper's SKUs and names
// FieldGuideLoreSurvey sample <pdf>
//     writes the sample sourcebook (placeholder text under real names) for App Review and anyone without the books
// FieldGuideLoreSurvey survey --pf2e <repository> --library <folder> [--scrollkeeper <catalog.json>]
//         [--extra <title>=<pdf>]... --output <sourcebooks.json>
//     reads every book in the library folder (laid out as Scrollkeeper downloads them) and writes the sourcebook
//     list: each deity's stat-line and prose sources
let usage = """
    Usage: FieldGuideLoreSurvey table|writeups <pdf> [--catalog <catalog.sqlite>]
           FieldGuideLoreSurvey creatures --pf2e <repository> <title>=<pdf>...
           FieldGuideLoreSurvey creatures-of <pdf> <name>...
           FieldGuideLoreSurvey details-of <pdf> <name>...
           FieldGuideLoreSurvey details --pf2e <repository> <title>=<pdf>...
           FieldGuideLoreSurvey lore-books --pf2e <repository> --scrollkeeper <catalog.json> --list <json>
           FieldGuideLoreSurvey sample <pdf>
           FieldGuideLoreSurvey survey --pf2e <repository> --library <folder> [--scrollkeeper <catalog.json>]
               [--extra <title>=<pdf>]... --output <sourcebooks.json>

    """
let arguments = Array(CommandLine.arguments.dropFirst())

func value(of option: String) -> String? {
    arguments.firstIndex(of: option).flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
}

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data(message.utf8))
    exit(code)
}

switch arguments.first {
case "table", "writeups":
    guard arguments.count >= 2 else { fail(usage, code: 2) }
    try printLore(of: arguments[1], reading: arguments[0],
                  catalog: value(of: "--catalog") ?? "Generated/catalog.sqlite")
case "creatures":
    guard let pf2e = value(of: "--pf2e") else { fail(usage, code: 2) }
    try checkCreatures(pf2e: pf2e, books: arguments.dropFirst().filter { $0.contains("=") })
case "creatures-of":
    guard arguments.count >= 3, let document = PDFDocument(url: URL(filePath: arguments[1])) else {
        fail(usage, code: 2)
    }
    let all = CreatureWriteups().writeups(in: document)
    let named = Dictionary(arguments.dropFirst(2).compactMap { name in
        CreatureLore.keys(for: name).lazy.compactMap { all[$0] }.first.map { (name, $0) }
    }) { first, _ in first }
    FileHandle.standardOutput.write(try SurveyOutput.encoder.encode(named))
case "details-of":
    guard arguments.count >= 3, let document = PDFDocument(url: URL(filePath: arguments[1])) else {
        fail(usage, code: 2)
    }
    let writeups = DetailsWriteups(names: Array(arguments.dropFirst(2))).writeups(in: document)
    FileHandle.standardOutput.write(try SurveyOutput.encoder.encode(writeups))
case "details":
    guard let pf2e = value(of: "--pf2e") else { fail(usage, code: 2) }
    let check = DetailsCheck(pages: try FoundryDetailsPages.read(repository: URL(filePath: pf2e)))
    let header = ["| Book | Pages | Found | Matching |", "|---|---|---|---|"]
    print((header + arguments.dropFirst().filter { $0.contains("=") }
        .map { argument in
            let parts = argument.split(separator: "=", maxSplits: 1).map(String.init)
            return check.check(book: parts[0], pdf: URL(filePath: parts[1]))
        }).joined(separator: "\n"))
case "lore-books":
    guard let pf2e = value(of: "--pf2e"), let catalog = value(of: "--scrollkeeper"), let list = value(of: "--list")
    else { fail(usage, code: 2) }
    try addLoreBooks(pf2e: pf2e, catalog: catalog, list: list)
case "sample":
    guard arguments.count >= 2, SampleSourcebook.document()?.write(to: URL(filePath: arguments[1])) == true
    else { fail(usage, code: 2) }
case "survey":
    guard let pf2e = value(of: "--pf2e"), let library = value(of: "--library"), let output = value(of: "--output")
    else { fail(usage, code: 2) }
    try runSurvey(pf2e: pf2e, library: library, output: output)
default:
    fail(usage, code: 2)
}

func printLore(of path: String, reading kind: String, catalog catalogPath: String) throws {
    let catalog = try Catalog(url: URL(filePath: catalogPath))
    let names = try GameSystem.allCases.flatMap { try catalog.summaries(of: .deities, in: $0).map(\.name) }
    guard let document = PDFDocument(url: URL(filePath: path)) else { fail("Reading failed: \(path) is not a PDF\n") }
    let lore: [String: DeityLore] = kind == "table"
        ? DeityTable(names: names).rows(in: document).mapValues { DeityLore(statLines: $0) }
        : DeityWriteups(names: names).writeups(in: document)
    FileHandle.standardOutput.write(try SurveyOutput.encoder.encode(lore))
}

func runSurvey(pf2e: String, library: String, output: String) throws {
    let deities = try FoundryDeities.read(repository: URL(filePath: pf2e))
    var books = try LibraryBooks.find(in: URL(filePath: library),
                                      scrollkeeperCatalog: value(of: "--scrollkeeper").map { URL(filePath: $0) })
    for (index, argument) in arguments.enumerated() where argument == "--extra" && index + 1 < arguments.count {
        let parts = arguments[index + 1].split(separator: "=", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { fail(usage, code: 2) }
        books.append(LibraryBook(title: parts[0], folderName: parts[0], pdf: URL(filePath: parts[1]), keepsTitle: true))
    }
    let survey = Survey(deities: deities, books: books)
    let findings = survey.findings { FileHandle.standardError.write(Data("\($0)\n".utf8)) }
    let result = SurveyOutput(deities: deities, books: survey.titledBooks, findings: findings)
    var list = result.list
    if let catalog = value(of: "--scrollkeeper") {
        list = try LoreBooks.adding(to: list, repository: URL(filePath: pf2e), catalog: URL(filePath: catalog))
    }
    try SurveyOutput.encoder.encode(list).write(to: URL(filePath: output))
    FileHandle.standardOutput.write(Data(result.report.utf8))
}

func checkCreatures(pf2e: String, books: [String]) throws {
    let check = CreatureCheck(creatures: try FoundryCreatures.read(repository: URL(filePath: pf2e)))
    var lines = ["| Book | Creatures | Found | Matching | Families | Faults |", "|---|---|---|---|---|---|"]
    var details: [String] = []
    for argument in books {
        let parts = argument.split(separator: "=", maxSplits: 1).map(String.init)
        let result = check.check(book: parts[0], pdf: URL(filePath: parts[1]))
        lines.append(result.line)
        details += ["", "## \(result.book)", "Missed: \(result.misses.sorted().joined(separator: ", "))",
                    "Mismatched: \(result.mismatches.sorted().joined(separator: ", "))",
                    "Faults:"] + Array(Set(result.faults)).sorted().map { "- \($0)" }
    }
    print((lines + details).joined(separator: "\n"))
}

func addLoreBooks(pf2e: String, catalog: String, list path: String) throws {
    let file = URL(filePath: path)
    let list = try JSONDecoder().decode(SourcebookList.self, from: Data(contentsOf: file))
    let merged = try LoreBooks.adding(to: list, repository: URL(filePath: pf2e), catalog: URL(filePath: catalog))
    print("\(merged.creatures.count) adventure creatures share a bestiary creature's lore.")
    try SurveyOutput.encoder.encode(merged).write(to: file)
    let loreBooks = merged.books.filter { !Set($0.supplies).isDisjoint(with: [.creatureLore, .detailsLore]) }
    let withoutSKU = loreBooks.filter { $0.sku == nil }.map(\.title)
    print("\(loreBooks.count) books supply creature or Details lore; \(withoutSKU.count) without a Scrollkeeper SKU:")
    withoutSKU.forEach { print("  \($0)") }
}
