import Foundation
import Observation
#if os(macOS)
import AppKit
#endif

/// What the link needs from the system to work with Scrollkeeper. The app uses `NSWorkspace`; tests use a fake.
@MainActor
public protocol ApplicationLauncher {
    func isInstalled(_ bundleIdentifier: String) -> Bool
    /// Opens the URL without bringing its app to the front.
    func openInBackground(_ url: URL)
}

/// Scrollkeeper as Field Guide sees it, following its app-handoff contract: Field Guide asks for the list of titles
/// the user owns, which Scrollkeeper hands over as a file, and asks it to open a title, whose PDFs Scrollkeeper
/// downloads when needed and opens in Field Guide. Only Scrollkeeper for the Mac answers these requests.
@MainActor
@Observable
public final class ScrollkeeperLink {
    public static let bundleIdentifier = "io.github.scooper4711.Scrollkeeper"
    /// The extension of the list Scrollkeeper hands over.
    public static let indexExtension = "scrollkeeperindex"

    /// Whether each title the user owns, by SKU, has an up-to-date copy on disk; empty until the list arrives.
    public private(set) var owned: [String: Bool] = [:]
    /// The SKU of the title Field Guide asked Scrollkeeper for, and how that is going.
    public private(set) var requested: (sku: String, status: String)?
    @ObservationIgnored private let launcher: ApplicationLauncher?

    public init(launcher: ApplicationLauncher?) {
        self.launcher = launcher
    }

    /// The link over the system's apps: on the Mac, `NSWorkspace`; on the iPad, none.
    public static func standard() -> ScrollkeeperLink {
        #if os(macOS)
        ScrollkeeperLink(launcher: WorkspaceLauncher())
        #else
        ScrollkeeperLink(launcher: nil)
        #endif
    }

    public var isInstalled: Bool { launcher?.isInstalled(Self.bundleIdentifier) ?? false }

    /// True when the user owns the title, so Scrollkeeper can download it.
    public func owns(sku: String?) -> Bool {
        sku.map { owned[$0] != nil } ?? false
    }

    /// Asks Scrollkeeper, staying in the background, to hand over the list of titles.
    public func requestIndex() {
        guard isInstalled else { return }
        launcher?.openInBackground(Self.requestURL(host: "index", sku: nil))
    }

    /// Asks Scrollkeeper to download the title when needed and open its PDFs in Field Guide.
    public func open(sku: String) {
        requested = (sku, "Asking Scrollkeeper…")
        launcher?.openInBackground(Self.requestURL(host: "open", sku: sku))
    }

    /// Reads the list Scrollkeeper handed over: `{ "formatVersion": 1, "titles": [{ "sku", "downloaded" }] }`.
    public func receiveIndex(_ file: URL) {
        guard let data = try? Data(contentsOf: file),
              let index = try? JSONDecoder().decode(ScrollkeeperIndex.self, from: data),
              index.formatVersion == 1 else { return }
        owned = Dictionary(index.titles.map { ($0.sku, $0.downloaded) }) { first, _ in first }
    }

    /// Takes a status link: `fieldguide://handoff?sku=…&state=downloading|done|failed[&fraction=…][&reason=…]`.
    public func receiveStatus(_ url: URL) {
        guard url.scheme == "fieldguide", url.host == "handoff" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let value = { (name: String) in items.first { $0.name == name }?.value ?? "" }
        guard let sku = requested?.sku, value("sku") == sku else { return }
        switch value("state") {
        case "downloading":
            let percent = Int((Double(value("fraction")) ?? 0) * 100)
            requested = (sku, "Scrollkeeper is downloading… \(percent)%")
        case "done": requested = nil
        case "failed": requested = (sku, "Scrollkeeper couldn't open it: \(value("reason"))")
        default: break
        }
    }

    static func requestURL(host: String, sku: String?) -> URL {
        var components = URLComponents()
        components.scheme = "scrollkeeper"
        components.host = host
        components.queryItems = (sku.map { [URLQueryItem(name: "sku", value: $0)] } ?? [])
            + [URLQueryItem(name: "app", value: "fieldguide")]
        // The components are all set above, so they make a URL.
        return components.url! // swiftlint:disable:this force_unwrapping
    }
}

/// The part of Scrollkeeper's title index Field Guide reads (its app-handoff design defines the rest).
private struct ScrollkeeperIndex: Decodable {
    struct Title: Decodable {
        let sku: String
        let downloaded: Bool
    }

    let formatVersion: Int
    let titles: [Title]
}

#if os(macOS)
/// The Mac's apps, through `NSWorkspace`.
struct WorkspaceLauncher: ApplicationLauncher {
    func isInstalled(_ bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    func openInBackground(_ url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open(url, configuration: configuration)
    }
}
#endif
