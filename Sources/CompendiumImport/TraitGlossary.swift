import FieldGuideKit
import Foundation

/// Trait labels and descriptions from the system's language files. A description's localization key comes
/// from `traitDescriptions` in `src/scripts/config/traits.ts`, else `PF2E.TraitDescription<Slug>`; a trait
/// with a value, such as `reach-10` or `deadly-d10`, uses the description of `reach` or `deadly`.
public struct TraitGlossary: Sendable {
    /// Slug → localization key, from `traits.ts`.
    private let descriptionKeys: [String: String]
    private let localizers: [GameSystem: Localizer]

    public init(descriptionKeys: [String: String] = [:], localizers: [GameSystem: Localizer] = [:]) {
        self.descriptionKeys = descriptionKeys
        self.localizers = localizers
    }

    /// Reads `traits.ts` from the repository. Starfinder prefers `sf2e-overrides-en.json`.
    public init(repository: URL, localizer: Localizer) {
        let config = repository.appendingPathComponent("src/scripts/config/traits.ts")
        let source = (try? String(contentsOf: config, encoding: .utf8)) ?? ""
        let overrides = repository.appendingPathComponent("static/lang/sf2e-overrides-en.json")
        let starfinder = (try? JSONValue(contentsOf: overrides)).map { localizer.preferring([$0]) } ?? localizer
        self.init(descriptionKeys: Self.descriptionKeys(in: source),
                  localizers: [.pathfinder: localizer, .starfinder: starfinder])
    }

    /// "Deadly d10" for `deadly-d10`: the localized label, else the words capitalized.
    public func label(of slug: String, in system: GameSystem) -> String {
        localizers[system]?.text(for: "PF2E.Trait" + Self.pascalCase(slug)) ?? Words.title(slug)
    }

    /// The description HTML of a trait, or of the trait without its trailing values; nil when it has none.
    public func description(of slug: String, in system: GameSystem) -> String? {
        let words = slug.split(separator: "-").map(String.init)
        for count in (1...max(words.count, 1)).reversed() {
            if let text = description(ofExactly: words.prefix(count).joined(separator: "-"), in: system) {
                return text
            }
        }
        return nil
    }

    private func description(ofExactly slug: String, in system: GameSystem) -> String? {
        guard !slug.isEmpty else { return nil }
        let key = descriptionKeys[slug] ?? "PF2E.TraitDescription" + Self.pascalCase(slug)
        let text = localizers[system]?.text(for: key) ?? ""
        return text.isEmpty ? nil : text
    }

    static func pascalCase(_ slug: String) -> String {
        slug.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// The `slug: "PF2E.Key"` pairs of every `const …Descriptions = { … };` object.
    static func descriptionKeys(in source: String) -> [String: String] {
        let block = /const \w+Descriptions\b[^=]*= \{(?<body>[^}]*)\}/
        let pair = /^\s*"?(?<slug>[\w-]+)"?:\s*"(?<key>[\w.]+)",?\s*$/.anchorsMatchLineEndings()
        var keys: [String: String] = [:]
        for match in source.matches(of: block) {
            for entry in match.output.body.matches(of: pair) {
                keys[String(entry.output.slug)] = String(entry.output.key)
            }
        }
        return keys
    }
}
