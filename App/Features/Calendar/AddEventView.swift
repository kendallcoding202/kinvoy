import SwiftUI

struct AddEventView: View {
    let trip: Trip
    let memberId: UUID
    let defaultDay: Date?
    let onSave: (TripEvent) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var locationName = ""
    @State private var notes = ""
    @State private var startsAt: Date = .now
    @State private var hasEndTime = false
    @State private var endsAt: Date = .now.addingTimeInterval(3600)
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("What") {
                    TextField("Title (e.g. Dolphin cruise)", text: $title)
                    TextField("Location (optional)", text: $locationName)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("When") {
                    DatePicker("Starts", selection: $startsAt, in: dateRange)
                    Toggle("Add end time", isOn: $hasEndTime)
                    if hasEndTime {
                        DatePicker("Ends", selection: $endsAt, in: startsAt...)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .navigationTitle("New plan")
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
            .onAppear {
                var base = defaultDay ?? Calendar.current.startOfDay(for: .now)
                // Clamp the default into the trip window.
                if base < trip.startDate { base = trip.startDate }
                if base > trip.endDate { base = trip.endDate }
                startsAt = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: base) ?? base
                endsAt = startsAt.addingTimeInterval(3600)
            }
        }
    }

    private var dateRange: ClosedRange<Date> {
        let end = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: trip.endDate) ?? trip.endDate
        return trip.startDate...max(trip.startDate, end)
    }

    private func submit() {
        isWorking = true
        errorMessage = nil
        let event = TripEvent(
            id: UUID(),
            tripId: trip.id,
            memberId: memberId,
            title: title.trimmingCharacters(in: .whitespaces),
            notes: notes.isEmpty ? nil : notes,
            locationName: locationName.isEmpty ? nil : locationName,
            startsAt: startsAt,
            endsAt: hasEndTime ? endsAt : nil
        )
        Task {
            do {
                try await onSave(event)
                dismiss()
            } catch {
                errorMessage = "Couldn't save the plan. Try again."
                isWorking = false
            }
        }
    }
}
