import SwiftUI

struct AddLogisticsView: View {
    let trip: Trip
    let memberId: UUID
    let onSave: (LogisticsItem) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: LogisticsKind = .flight
    @State private var title = ""
    @State private var details = ""
    @State private var hasDate = false
    @State private var happensOn: Date = .now
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(LogisticsKind.allCases) { kind in
                            Label(kind.label, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                    TextField(titlePlaceholder, text: $title)
                    TextField("Details (confirmation #, times, codes…)", text: $details, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section {
                    Toggle("Tie to a date", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Date", selection: $happensOn, displayedComponents: .date)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .navigationTitle("Add travel info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Add") { submit() }
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private var titlePlaceholder: String {
        switch kind {
        case .flight: "Flight (e.g. Delta 1432 → PNS)"
        case .hotel: "Lodging (e.g. Beachfront condo)"
        case .car: "Rental car (e.g. Enterprise minivan)"
        case .ticket: "Tickets (e.g. Aquarium, 6 people)"
        case .other: "Title"
        }
    }

    private func submit() {
        isWorking = true
        errorMessage = nil
        let item = LogisticsItem(
            id: UUID(),
            tripId: trip.id,
            memberId: memberId,
            kind: kind,
            title: title.trimmingCharacters(in: .whitespaces),
            details: details.isEmpty ? nil : details,
            happensOn: hasDate ? Trip.dayFormatter.string(from: happensOn) : nil
        )
        Task {
            do {
                try await onSave(item)
                dismiss()
            } catch {
                errorMessage = "Couldn't save. Try again."
                isWorking = false
            }
        }
    }
}
