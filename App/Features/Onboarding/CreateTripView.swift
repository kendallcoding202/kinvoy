import SwiftUI

struct CreateTripView: View {
    @EnvironmentObject private var store: TripStore
    @EnvironmentObject private var familyStore: FamilyStore
    @Environment(\.dismiss) private var dismiss
    @State private var shareWithFamily = true

    @State private var kind: TripKind = .vacation
    @State private var name = ""
    @State private var destination = ""
    @State private var displayName = ""
    @State private var startDate = Calendar.current.startOfDay(for: .now)
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 6, to: Calendar.current.startOfDay(for: .now))!
    @State private var isWorking = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !destination.trimmingCharacters(in: .whitespaces).isEmpty
            && !displayName.trimmingCharacters(in: .whitespaces).isEmpty
            && endDate >= startDate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    Picker("Type", selection: $kind) {
                        ForEach(TripKind.allCases) { kind in
                            Text("\(kind.emoji)  \(kind.label)").tag(kind)
                        }
                    }
                    TextField("Name (e.g. Beach Week 2026)", text: $name)
                    DestinationField(destination: $destination)
                }
                Section("Dates") {
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                    DatePicker("Ends", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                if let family = familyStore.family {
                    Section {
                        Toggle(isOn: $shareWithFamily) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Share with \(family.name)")
                                Text(shareWithFamily
                                    ? "Everyone in \(family.name) is added automatically — no code needed."
                                    : "Private: only people you give the trip code to can see it.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Who's on it")
                    }
                }
                Section("You") {
                    TextField("Your name (what everyone sees)", text: $displayName)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .navigationTitle("Start a trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Create") { submit() }
                            .disabled(!canSubmit)
                    }
                }
            }
        }
    }

    private func submit() {
        guard AppConfig.isConfigured else {
            errorMessage = "The backend isn't set up yet — see SETUP.md, or use the demo trip."
            return
        }
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await store.createTrip(
                    name: name.trimmingCharacters(in: .whitespaces),
                    destination: destination.trimmingCharacters(in: .whitespaces),
                    startsOn: startDate,
                    endsOn: endDate,
                    displayName: displayName.trimmingCharacters(in: .whitespaces),
                    kind: kind,
                    familyId: familyStore.family?.id,
                    isPrivate: familyStore.family != nil && !shareWithFamily
                )
                dismiss()
            } catch {
                errorMessage = "Couldn't create the trip. Check your connection and try again."
                isWorking = false
            }
        }
    }
}
