import Foundation
import LorespireImport

/// `FieldGuideLorespire [OUT]`: downloads Paizo's Organized Play guides from Lorespire into OUT (default
/// `build/lorespire`), for GMs without a connection. See `Lorespire.documents` for what is downloaded.
///
/// The session keeps no cookies: with Tiki's session cookie but no `javascript_enabled` one, the site leaves out the
/// tab sets' tab bars, and the tabs' titles with them.
struct SessionFetcher: LorespireFetching {
    let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        return URLSession(configuration: configuration)
    }()

    func fetch(_ url: URL) async throws -> LorespireResponse {
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.setValue("FieldGuideLorespire (Field Guide build tool)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw LorespireError.httpStatus(url: url, status: status) }
        return LorespireResponse(data: data, contentType: response.mimeType ?? "",
                                 suggestedFileName: response.suggestedFilename)
    }
}

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build/lorespire")
do {
    let manifest = try await LorespireDownloader(fetcher: SessionFetcher()).download(to: output)
    print("Downloaded \(manifest.documents.count) Lorespire documents and \(manifest.files.count) files "
          + "into \(output.path).")
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
