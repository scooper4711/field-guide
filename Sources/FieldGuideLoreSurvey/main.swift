import FieldGuideKit
import Foundation
import PDFKit
import SourcebookLore

// Reads deities' lore from sourcebook PDFs and works out which book supplies each deity.
//
// FieldGuideLoreSurvey table|writeups <pdf> [--catalog Generated/catalog.sqlite]
//     prints the stat lines a deity table gives, or the write-ups a book gives, as JSON
// FieldGuideLoreSurvey survey --pf2e <repository> --library <folder> [--scrollkeeper <catalog.json>]
//         [--extra <title>=<pdf>]... --output <sourcebooks.json>
//     reads every book in the library folder (laid out as Scrollkeeper downloads them) and writes the sourcebook
//     list: each deity's stat-line and prose sources
let usage = """
    Usage: FieldGuideLoreSurvey table|writeups <pdf> [--catalog <catalog.sqlite>]
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
    try SurveyOutput.encoder.encode(result.list).write(to: URL(filePath: output))
    FileHandle.standardOutput.write(Data(result.report.utf8))
}
