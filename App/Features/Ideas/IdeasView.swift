import Supabase
import SwiftUI

@MainActor
final class IdeasViewModel: ObservableObject {
    @Published var suggestions: [ActivitySuggestion] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var client: SupabaseClient { SupabaseService.shared.client }

    struct SuggestionResponse: Decodable {
        let suggestions: [ActivitySuggestion]
    }

    func fetch(trip: Trip, focus: String?, notes: String, isDemo: Bool) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if isDemo {
            try? await Task.sleep(for: .seconds(1))
            suggestions = DemoData.suggestions
            return
        }

        struct Payload: Encodable {
            let destination: String
            let start_date: String
            let end_date: String
            let focus: String?
            let notes: String?
        }
        do {
            let response: SuggestionResponse = try await client.functions.invoke(
                "suggest-activities",
                options: FunctionInvokeOptions(body: Payload(
                    destination: trip.destination,
                    start_date: trip.startsOn,
                    end_date: trip.endsOn,
                    focus: focus,
                    notes: notes.isEmpty ? nil : notes
                ))
            )
            suggestions = response.suggestions
        } catch {
            errorMessage = "Couldn't get ideas right now. Check the connection and try again."
            print("Suggestions failed: \(error)")
        }
    }
}

struct IdeasView: View {
    @EnvironmentObject private var store: TripStore
    @StateObject private var viewModel = IdeasViewModel()
    @State private var focus: String?
    @State private var notes = ""

    private let focusOptions = ["Anything", "Outdoors", "Food", "Rainy day", "Free & cheap", "With little kids"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    focusChips
                    notesField
                    fetchButton
                    results
                }
                .padding()
            }
            .navigationTitle("Ideas")
        }
    }

    private var header: some View {
        Group {
            if let trip = store.trip {
                Text("Out of ideas? Get family-friendly suggestions for **\(trip.destination)**, matched to your trip dates.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var focusChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(focusOptions, id: \.self) { option in
                    let isSelected = (focus == option) || (option == "Anything" && focus == nil)
                    Button {
                        focus = option == "Anything" ? nil : option
                    } label: {
                        Text(option)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.accentColor : Color(.systemGray6), in: Capsule())
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var notesField: some View {
        TextField("Anything to consider? (ages, budget, interests…)", text: $notes, axis: .vertical)
            .lineLimit(1...3)
            .padding(12)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    private var fetchButton: some View {
        Button {
            guard let trip = store.trip else { return }
            Task { await viewModel.fetch(trip: trip, focus: focus, notes: notes, isDemo: store.isDemo) }
        } label: {
            HStack {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(viewModel.isLoading ? "Thinking…" : "Suggest things to do")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isLoading)

    }

    private var results: some View {
        Group {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
            ForEach(viewModel.suggestions) { suggestion in
                SuggestionCard(suggestion: suggestion)
            }
        }
    }
}

struct SuggestionCard: View {
    let suggestion: ActivitySuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(suggestion.emoji)
                    .font(.title2)
                Text(suggestion.title)
                    .font(.headline)
                Spacer()
                Text(suggestion.costLevel)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6), in: Capsule())
            }
            Text(suggestion.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(suggestion.category)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}
