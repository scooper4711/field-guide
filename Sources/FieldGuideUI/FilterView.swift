import FieldGuideKit
import SwiftUI

/// The level range and each facet's values, for narrowing the list.
struct FilterView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                if let range = store.levelRange {
                    LevelRangeSection(range: range, minimum: $store.query.minimumLevel,
                                      maximum: $store.query.maximumLevel)
                }
                ForEach(store.facets.filter { !store.options.values(of: $0).isEmpty }) { facet in
                    FacetSection(facet: facet)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { store.query = EntryQuery(text: store.query.text,
                                                               searchesText: store.query.searchesText) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 520)
        #endif
    }
}

struct LevelRangeSection: View {
    let range: ClosedRange<Int>
    @Binding var minimum: Int?
    @Binding var maximum: Int?

    var body: some View {
        Section("Level") {
            Stepper("From \(minimum ?? range.lowerBound)", value: bound($minimum, default: range.lowerBound), in: range)
            Stepper("To \(maximum ?? range.upperBound)", value: bound($maximum, default: range.upperBound), in: range)
        }
    }

    /// A binding that reads the default when no bound is set and clears the bound when set back to it.
    private func bound(_ value: Binding<Int?>, default fallback: Int) -> Binding<Int> {
        Binding(get: { value.wrappedValue ?? fallback },
                set: { value.wrappedValue = $0 == fallback ? nil : $0 })
    }
}

/// A facet's values as toggles; long lists (traits, sources) get their own searchable page.
struct FacetSection: View {
    @Environment(CatalogStore.self) private var store
    let facet: Facet

    private static let inlineLimit = 12

    var body: some View {
        let values = store.options.values(of: facet)
        Section(facet.title) {
            if values.count > Self.inlineLimit {
                NavigationLink {
                    FacetValuesList(facet: facet, values: values)
                } label: {
                    LabeledContent(facet.matchesAll ? "Must Have All" : "Any Of", value: chosenSummary)
                }
            } else {
                ForEach(values, id: \.self) { FacetToggle(facet: facet, value: $0) }
            }
        }
    }

    private var chosenSummary: String {
        let chosen = store.query.chosen[facet] ?? []
        return chosen.isEmpty ? "All" : chosen.sorted().joined(separator: ", ")
    }
}

struct FacetValuesList: View {
    let facet: Facet
    let values: [String]
    @State private var search = ""

    var body: some View {
        List(values.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \.self) {
            FacetToggle(facet: facet, value: $0)
        }
        .searchable(text: $search)
        .navigationTitle(facet.title)
    }
}

struct FacetToggle: View {
    @Environment(CatalogStore.self) private var store
    let facet: Facet
    let value: String

    var body: some View {
        @Bindable var store = store
        Toggle(isOn: Binding(
            get: { store.query.chosen[facet]?.contains(value) ?? false },
            set: { isOn in
                var chosen = store.query.chosen[facet] ?? []
                if isOn { chosen.insert(value) } else { chosen.remove(value) }
                store.query.chosen[facet] = chosen
            }
        )) {
            LabeledContent(value, value: store.options.count(of: value, in: facet).formatted())
        }
    }
}
