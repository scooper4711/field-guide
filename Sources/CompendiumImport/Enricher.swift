import Foundation

/// Replaces Foundry text enrichers in description HTML with readable HTML: `@UUID` links become `entry:`
/// links (or plain text), `@Check`, `@Damage` and `@Template` become prose, `@Localize` its text, and inline
/// rolls their label.
public final class Enricher {
    private let localizer: Localizer
    private let links: LinkIndex
    /// Enricher names that could not be converted, and links that led nowhere, for the import report.
    public private(set) var unconverted: [String: Int] = [:]
    public private(set) var unresolvedLinks: [String: Int] = [:]

    public init(localizer: Localizer, links: LinkIndex) {
        self.localizer = localizer
        self.links = links
    }

    public func enrich(_ html: String) -> String {
        replaceEnrichers(in: replaceInlineRolls(in: expandLocalizations(html, depth: 0)))
    }

    private func expandLocalizations(_ html: String, depth: Int) -> String {
        guard depth < 4, html.contains("@Localize[") else { return html }
        let expanded = EnricherScanner.replace(in: html) { match in
            match.name == "Localize" ? localizer.text(for: match.argument) ?? "" : nil
        }
        return expandLocalizations(expanded, depth: depth + 1)
    }

    private func replaceEnrichers(in html: String) -> String {
        EnricherScanner.replace(in: html) { match in
            if let converted = convert(match) { return converted }
            unconverted[match.name, default: 0] += 1
            return match.label.map(HTML.escape) ?? ""
        }
    }

    private func convert(_ match: EnricherMatch) -> String? {
        switch match.name {
        case "UUID": link(match)
        case "Check": HTML.span("check", match.label ?? CheckText.text(match.argument))
        case "Damage": HTML.span("damage", match.label ?? DamageText.text(match.argument))
        case "Template": match.label ?? TemplateText.text(match.argument)
        case "Embed", "Compendium", "Trait": match.label ?? ""
        default: nil
        }
    }

    /// A link to an imported entry becomes an `entry:` link; any other becomes its label.
    private func link(_ match: EnricherMatch) -> String {
        let name = Self.linkedName(match.argument)
        let label = match.label ?? name
        let macroAction = Self.macroAction(match.argument)
        guard let target = links.entryID(forLink: match.argument) ?? links.entryID(forLink: macroAction) else {
            if !match.argument.contains("-effects.") { unresolvedLinks[match.argument, default: 0] += 1 }
            return HTML.escape(label)
        }
        return HTML.link(match.label ?? links.name(of: target) ?? name, to: "entry:\(target)")
    }

    /// The action a skill-action macro runs: `….action-macros.Macro.Demoralize: Intimidation` → the Demoralize
    /// action of the system's actions pack.
    static func macroAction(_ argument: String) -> String {
        let parts = argument.split(separator: ".", maxSplits: 4).map(String.init)
        guard parts.count == 5, parts[2] == "action-macros" else { return "" }
        let action = parts[4].split(separator: ":").first.map(String.init) ?? parts[4]
        let pack = parts[1] == "pf2e" ? "actionspf2e" : "actions"
        return "Compendium.\(parts[1]).\(pack).Item.\(action)"
    }

    /// The last part of a link, without the "Effect: " Foundry gives effect items.
    static func linkedName(_ argument: String) -> String {
        let name = argument.split(separator: ".").last.map(String.init) ?? ""
        return name.hasPrefix("Effect: ") ? String(name.dropFirst("Effect: ".count)) : name
    }

    /// `[[/r 1d4 #Recharge]]{1d4 rounds}` becomes "1d4 rounds", and `[[/act demoralize]]` "Demoralize".
    private func replaceInlineRolls(in text: String) -> String {
        let pattern = /\[\[\/(?<command>\w+) (?<body>[^\]]*)\]\](?:\{(?<label>[^}]*)\})?/
        return text.replacing(pattern) { match in
            if let label = match.output.label { return String(label) }
            let body = String(match.output.body)
            if match.output.command == "act" {
                let action = body.split(separator: " ").first.map(String.init) ?? body
                return action.split(separator: "-").map(\.capitalized).joined(separator: " ")
            }
            return body.split(separator: "#").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? body
        }
    }
}

/// Prose for `@Check[…]`: "DC 20 basic Reflex save", "DC 18 Athletics check", "DC 5 flat check".
enum CheckText {
    private static let saves: Set<String> = ["fortitude", "reflex", "will"]

    static func text(_ argument: String) -> String {
        let fields = EnricherParameters.parse(argument)
        let statistic = fields["type"] ?? fields[""] ?? ""
        let isSave = saves.contains(statistic)
        var words: [String] = []
        if let dc = fields["dc"], Int(dc) != nil { words.append("DC \(dc)") }
        if fields["basic"] != nil { words.append("basic") }
        words.append(Words.title(statistic))
        words.append(isSave ? "save" : "check")
        if let defense = fields["defense"] ?? fields["against"] {
            words.append("against \(defense == "class" ? "class" : Words.title(defense)) DC")
        }
        return words.joined(separator: " ")
    }
}

/// Prose for `@Template[…]`: "20-foot burst".
enum TemplateText {
    static func text(_ argument: String) -> String {
        let fields = EnricherParameters.parse(argument)
        let shape = fields["type"] ?? fields[""] ?? "area"
        return fields["distance"].map { "\($0)-foot \(shape)" } ?? shape
    }
}

/// Prose for `@Damage[…]`: "2d6+4 fire plus 1d6 persistent bleed".
enum DamageText {
    static func text(_ argument: String) -> String {
        let formula = EnricherScanner.splitTopLevel(argument, separator: "|").first ?? ""
        return EnricherScanner.splitTopLevel(formula, separator: ",")
            .map(part)
            .filter { !$0.isEmpty }
            .joined(separator: " plus ")
    }

    /// One part such as `(2d6+4)[persistent,fire]` or `1d6[bleed]`.
    static func part(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix("]"), let open = typeBracketStart(trimmed) else { return clean(trimmed) }
        let tags = trimmed[trimmed.index(after: open)..<trimmed.index(before: trimmed.endIndex)]
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return ([clean(String(trimmed[..<open]))] + tags.map(Words.label)).joined(separator: " ")
    }

    /// The `[` that opens the trailing type list, skipping brackets nested inside the formula.
    private static func typeBracketStart(_ text: String) -> String.Index? {
        var depth = 0
        var index = text.index(before: text.endIndex)
        while index > text.startIndex {
            if text[index] == "]" { depth += 1 }
            if text[index] == "[" {
                depth -= 1
                if depth == 0 { return index }
            }
            index = text.index(before: index)
        }
        return nil
    }

    /// Removes the wrapping parentheses Foundry adds, so `(3d8+6)` reads `3d8+6`.
    private static func clean(_ formula: String) -> String {
        var result = formula.replacingOccurrences(of: " ", with: "")
        if result.hasPrefix("("), result.hasSuffix(")"), !result.dropFirst().contains("(") {
            result = String(result.dropFirst().dropLast())
        }
        return result
    }
}

/// Parses `reflex|dc:20|basic` into `["": "reflex", "dc": "20", "basic": ""]`.
enum EnricherParameters {
    static func parse(_ argument: String) -> [String: String] {
        var result: [String: String] = [:]
        for (index, field) in argument.split(separator: "|").enumerated() {
            let pair = field.split(separator: ":", maxSplits: 1).map(String.init)
            if pair.count == 2 {
                result[pair[0]] = pair[1]
            } else if index == 0 {
                result[""] = pair[0]
            } else {
                result[pair[0]] = ""
            }
        }
        return result
    }
}
