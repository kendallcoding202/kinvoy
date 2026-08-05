import MapKit
import SwiftUI

/// Type-ahead destination picker backed by MapKit. Picking a real place
/// means the weather forecast and map always resolve — no guessing from a
/// hand-typed string like "Disneyland".
@MainActor
final class DestinationSearch: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = ""
    @Published var results: [MKLocalSearchCompletion] = []
    /// Set once the user picks a suggestion, so we stop showing the list.
    @Published var hasPicked = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQuery(_ text: String) {
        query = text
        hasPicked = false
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            return
        }
        completer.queryFragment = trimmed
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let updated = completer.results
        Task { @MainActor in
            self.results = Array(updated.prefix(6))
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.results = [] }
    }

    /// Resolves a suggestion to a place name the geocoder will understand.
    func resolve(_ completion: MKLocalSearchCompletion) async -> String {
        let request = MKLocalSearch.Request(completion: completion)
        guard let response = try? await MKLocalSearch(request: request).start(),
              let item = response.mapItems.first else {
            return completion.title
        }
        // Prefer "City, State" — that's what the weather geocoder matches best.
        let placemark = item.placemark
        if let city = placemark.locality {
            if let admin = placemark.administrativeArea {
                return "\(city), \(admin)"
            }
            return city
        }
        return item.name ?? completion.title
    }
}

struct DestinationField: View {
    @Binding var destination: String
    @StateObject private var search = DestinationSearch()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Where to? (e.g. Disneyland)", text: Binding(
                get: { destination },
                set: { newValue in
                    destination = newValue
                    search.updateQuery(newValue)
                }
            ))
            .focused($isFocused)
            .autocorrectionDisabled()

            if isFocused && !search.hasPicked && !search.results.isEmpty {
                ForEach(search.results, id: \.self) { result in
                    Divider()
                    Button {
                        pick(result)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(result.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func pick(_ result: MKLocalSearchCompletion) {
        search.hasPicked = true
        search.results = []
        isFocused = false
        // Show the tapped name immediately, then swap in the resolved
        // "City, State" once MapKit answers.
        destination = result.title
        Task {
            destination = await search.resolve(result)
        }
    }
}
