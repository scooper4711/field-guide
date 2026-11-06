import SwiftUI

/// What reading PDFs is doing, while it runs, wherever the user is: reading a sourcebook a large one takes a minute
/// or two, and Scrollkeeper hands books over without the Sourcebooks screen open.
struct ReadingStatus: View {
    @Environment(SourcebookModel.self) private var sourcebooks
    @Environment(ArtModel.self) private var pdfArt

    var body: some View {
        if let text = sourcebooks.progress ?? pdfArt.progress {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(text).font(.caption).lineLimit(1)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
